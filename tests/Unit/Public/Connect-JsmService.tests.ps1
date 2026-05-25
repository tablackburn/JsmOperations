[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Pester BeforeAll/It scope'
)]
param()

BeforeDiscovery {
    if ($null -eq $Env:BHBuildOutput) {
        # Populate BuildHelpers env vars so build.psake.ps1's properties block has
        # the values it needs (BHPSModuleManifest, BHProjectName) — when running
        # via ./build.ps1 this happens before psake; running tests in isolation
        # bypasses that, so we do it here.
        $repoRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
        Set-BuildEnvironment -Path $repoRoot -Force
        $buildFilePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\build.psake.ps1'
        $invokePsakeParameters = @{
            TaskList  = 'Build'
            BuildFile = $buildFilePath
        }
        Invoke-psake @invokePsakeParameters
    }

    $projectRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    $sourceManifest = Join-Path -Path $projectRoot -ChildPath "$Env:BHProjectName/$Env:BHProjectName.psd1"
    $moduleVersion = (Import-PowerShellDataFile -Path $sourceManifest).ModuleVersion
    $Env:BHBuildOutput = Join-Path -Path $projectRoot -ChildPath "Output/$Env:BHProjectName/$moduleVersion"
}

BeforeAll {
    $moduleManifestPath = Join-Path -Path $Env:BHBuildOutput -ChildPath "$Env:BHProjectName.psd1"
    Get-Module -Name $Env:BHProjectName | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Force -ErrorAction 'Stop'
    . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\TestHelpers.ps1')
}

Describe 'Connect-JsmService' {

    BeforeEach {
        # Snapshot env vars so tests don't leak state into the host
        $script:savedEmail = $env:JSM_EMAIL
        $script:savedToken = $env:JSM_API_TOKEN
        $script:savedCloud = $env:JSM_CLOUD_ID
        Remove-Item -Path 'Env:JSM_EMAIL' -ErrorAction 'SilentlyContinue'
        Remove-Item -Path 'Env:JSM_API_TOKEN' -ErrorAction 'SilentlyContinue'
        Remove-Item -Path 'Env:JSM_CLOUD_ID' -ErrorAction 'SilentlyContinue'
        InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock { $script:JsmConnection = $null }
    }

    AfterEach {
        if ($null -ne $script:savedEmail) { $env:JSM_EMAIL = $script:savedEmail }
        if ($null -ne $script:savedToken) { $env:JSM_API_TOKEN = $script:savedToken }
        if ($null -ne $script:savedCloud) { $env:JSM_CLOUD_ID = $script:savedCloud }
        InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock { $script:JsmConnection = $null }
    }

    Context 'Email parameter set' {

        It 'Sets script-scoped connection from -Email + -ApiToken + -CloudId' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi' -MockWith { @{ values = @() } }
            }

            $token = New-TestSecureString
            Connect-JsmService -Email 'me@example.com' -ApiToken $token -CloudId 'c1'

            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                $script:JsmConnection.Email | Should -Be 'me@example.com'
                $script:JsmConnection.CloudId | Should -Be 'c1'
                $script:JsmConnection.BaseUri | Should -Be 'https://api.atlassian.com/jsm/ops/api/c1/v1'
            }
        }
    }

    Context 'Credential parameter set' {

        It 'Sets connection from a PSCredential' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi' -MockWith { @{ values = @() } }
            }

            $token = New-TestSecureString
            $credential = [pscredential]::new('credential@example.com', $token)
            Connect-JsmService -Credential $credential -CloudId 'c2'

            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                $script:JsmConnection.Email | Should -Be 'credential@example.com'
                $script:JsmConnection.CloudId | Should -Be 'c2'
            }
        }
    }

    Context 'Environment variable fallback' {

        It 'Reads JSM_EMAIL / JSM_API_TOKEN / JSM_CLOUD_ID when parameters are omitted' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi' -MockWith { @{ values = @() } }
            }
            $env:JSM_EMAIL = 'environment@example.com'
            $env:JSM_API_TOKEN = New-TestToken
            $env:JSM_CLOUD_ID = 'environment-cloud'

            Connect-JsmService

            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                $script:JsmConnection.Email | Should -Be 'environment@example.com'
                $script:JsmConnection.CloudId | Should -Be 'environment-cloud'
            }
        }
    }

    Context 'Validation' {

        It 'Throws when email is missing entirely' {
            $token = New-TestSecureString
            { Connect-JsmService -ApiToken $token -CloudId 'c1' } |
                Should -Throw -ExpectedMessage '*Email is required*'
        }

        It 'Throws when API token is missing entirely' {
            { Connect-JsmService -Email 'me@example.com' -CloudId 'c1' } |
                Should -Throw -ExpectedMessage '*API token is required*'
        }

        It 'Throws when CloudId is missing entirely' {
            $token = New-TestSecureString
            { Connect-JsmService -Email 'me@example.com' -ApiToken $token } |
                Should -Throw -ExpectedMessage '*CloudId is required*'
        }

        It 'Fails parameter binding when -Email is explicitly empty' {
            $token = New-TestSecureString
            { Connect-JsmService -Email '' -ApiToken $token -CloudId 'c1' } | Should -Throw
        }

        It 'Fails parameter binding when -CloudId is explicitly empty' {
            $token = New-TestSecureString
            { Connect-JsmService -Email 'me@example.com' -ApiToken $token -CloudId '' } | Should -Throw
        }
    }

    Context 'Smoke test' {

        It 'Clears connection and rethrows when smoke test fails' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi' -MockWith { throw 'HTTP 401' }
            }
            $token = New-TestSecureString

            { Connect-JsmService -Email 'me@example.com' -ApiToken $token -CloudId 'c1' } |
                Should -Throw '*HTTP 401*'

            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                $script:JsmConnection | Should -BeNullOrEmpty
            }
        }
    }

    Context 'PassThru' {

        It 'Emits the connection object (without ApiToken) when -PassThru is set' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi' -MockWith { @{ values = @() } }
            }
            $token = New-TestSecureString

            $result = Connect-JsmService -Email 'me@example.com' -ApiToken $token -CloudId 'c1' -PassThru

            $result | Should -Not -BeNullOrEmpty
            $result.Email | Should -Be 'me@example.com'
            $result.PSObject.Properties.Name | Should -Not -Contain 'ApiToken'
        }
    }
}
