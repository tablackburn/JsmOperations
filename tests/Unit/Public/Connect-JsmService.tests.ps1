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
        Set-BuildEnvironment -Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))) -Force
        $buildFilePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\build.psake.ps1'
        $invokePsakeParameters = @{
            TaskList  = 'Build'
            BuildFile = $buildFilePath
        }
        Invoke-psake @invokePsakeParameters
    }

    $projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $sourceManifest = Join-Path $projectRoot "$Env:BHProjectName/$Env:BHProjectName.psd1"
    $moduleVersion = (Import-PowerShellDataFile -Path $sourceManifest).ModuleVersion
    $Env:BHBuildOutput = Join-Path $projectRoot "Output/$Env:BHProjectName/$moduleVersion"
}

BeforeAll {
    $moduleManifestPath = Join-Path -Path $Env:BHBuildOutput -ChildPath "$Env:BHProjectName.psd1"
    Get-Module $Env:BHProjectName | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Force -ErrorAction 'Stop'
    . (Join-Path $PSScriptRoot '..\..\TestHelpers.ps1')
}

Describe 'Connect-JsmService' {

    BeforeEach {
        # Snapshot env vars so tests don't leak state into the host
        $script:savedEmail = $env:JSM_EMAIL
        $script:savedToken = $env:JSM_API_TOKEN
        $script:savedCloud = $env:JSM_CLOUD_ID
        Remove-Item Env:JSM_EMAIL -ErrorAction SilentlyContinue
        Remove-Item Env:JSM_API_TOKEN -ErrorAction SilentlyContinue
        Remove-Item Env:JSM_CLOUD_ID -ErrorAction SilentlyContinue
        InModuleScope $Env:BHProjectName { $script:JsmConnection = $null }
    }

    AfterEach {
        if ($null -ne $script:savedEmail) { $env:JSM_EMAIL = $script:savedEmail }
        if ($null -ne $script:savedToken) { $env:JSM_API_TOKEN = $script:savedToken }
        if ($null -ne $script:savedCloud) { $env:JSM_CLOUD_ID = $script:savedCloud }
        InModuleScope $Env:BHProjectName { $script:JsmConnection = $null }
    }

    Context 'Email parameter set' {

        It 'Sets script-scoped connection from -Email + -ApiToken + -CloudId' {
            InModuleScope $Env:BHProjectName { Mock Invoke-JsmApi { @{ values = @() } } }

            $token = New-TestSecureString 'tok-1'
            Connect-JsmService -Email 'me@example.com' -ApiToken $token -CloudId 'c1'

            InModuleScope $Env:BHProjectName {
                $script:JsmConnection.Email | Should -Be 'me@example.com'
                $script:JsmConnection.CloudId | Should -Be 'c1'
                $script:JsmConnection.BaseUri | Should -Be 'https://api.atlassian.com/jsm/ops/api/c1/v1'
            }
        }
    }

    Context 'Credential parameter set' {

        It 'Sets connection from a PSCredential' {
            InModuleScope $Env:BHProjectName { Mock Invoke-JsmApi { @{ values = @() } } }

            $token = New-TestSecureString 'tok-2'
            $cred = [pscredential]::new('cred@example.com', $token)
            Connect-JsmService -Credential $cred -CloudId 'c2'

            InModuleScope $Env:BHProjectName {
                $script:JsmConnection.Email | Should -Be 'cred@example.com'
                $script:JsmConnection.CloudId | Should -Be 'c2'
            }
        }
    }

    Context 'Environment variable fallback' {

        It 'Reads JSM_EMAIL / JSM_API_TOKEN / JSM_CLOUD_ID when params are omitted' {
            InModuleScope $Env:BHProjectName { Mock Invoke-JsmApi { @{ values = @() } } }
            $env:JSM_EMAIL = 'env@example.com'
            $env:JSM_API_TOKEN = 'env-token'
            $env:JSM_CLOUD_ID = 'env-cloud'

            Connect-JsmService

            InModuleScope $Env:BHProjectName {
                $script:JsmConnection.Email | Should -Be 'env@example.com'
                $script:JsmConnection.CloudId | Should -Be 'env-cloud'
            }
        }
    }

    Context 'Validation' {

        It 'Throws when email is missing entirely' {
            $token = New-TestSecureString 'tok'
            { Connect-JsmService -ApiToken $token -CloudId 'c1' } |
                Should -Throw -ExpectedMessage '*Email is required*'
        }

        It 'Throws when API token is missing entirely' {
            { Connect-JsmService -Email 'me@example.com' -CloudId 'c1' } |
                Should -Throw -ExpectedMessage '*API token is required*'
        }

        It 'Throws when CloudId is missing entirely' {
            $token = New-TestSecureString 'tok'
            { Connect-JsmService -Email 'me@example.com' -ApiToken $token } |
                Should -Throw -ExpectedMessage '*CloudId is required*'
        }
    }

    Context 'Smoke test' {

        It 'Clears connection and rethrows when smoke test fails' {
            InModuleScope $Env:BHProjectName {
                Mock Invoke-JsmApi { throw 'HTTP 401' }
            }
            $token = New-TestSecureString 'bad'

            { Connect-JsmService -Email 'me@example.com' -ApiToken $token -CloudId 'c1' } |
                Should -Throw '*HTTP 401*'

            InModuleScope $Env:BHProjectName {
                $script:JsmConnection | Should -BeNullOrEmpty
            }
        }
    }

    Context 'PassThru' {

        It 'Emits the connection object (without ApiToken) when -PassThru is set' {
            InModuleScope $Env:BHProjectName { Mock Invoke-JsmApi { @{ values = @() } } }
            $token = New-TestSecureString 'tok'

            $result = Connect-JsmService -Email 'me@example.com' -ApiToken $token -CloudId 'c1' -PassThru

            $result | Should -Not -BeNullOrEmpty
            $result.Email | Should -Be 'me@example.com'
            $result.PSObject.Properties.Name | Should -Not -Contain 'ApiToken'
        }
    }
}
