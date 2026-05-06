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

Describe 'Get-JsmConnection' {

    AfterEach {
        InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock { $script:JsmConnection = $null }
    }

    It 'Returns $null when no connection is active' {
        InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock { $script:JsmConnection = $null }
        Get-JsmConnection | Should -BeNullOrEmpty
    }

    It 'Returns a view of the connection without ApiToken' {
        $apiToken = New-TestSecureString -Value 'tok'
        InModuleScope -ModuleName $Env:BHProjectName -Parameters @{ ApiToken = $apiToken } -ScriptBlock {
            param($ApiToken)
            $script:JsmConnection = [pscustomobject]@{
                Email       = 'me@example.com'
                ApiToken    = $ApiToken
                CloudId     = 'c1'
                BaseUri     = 'https://api.atlassian.com/jsm/ops/api/c1/v1'
                ConnectedAt = [datetime]::UtcNow
            }
        }

        $result = Get-JsmConnection

        $result | Should -Not -BeNullOrEmpty
        $result.Email | Should -Be 'me@example.com'
        $result.CloudId | Should -Be 'c1'
        $result.BaseUri | Should -Be 'https://api.atlassian.com/jsm/ops/api/c1/v1'
        $result.PSObject.Properties.Name | Should -Not -Contain 'ApiToken'
    }
}
