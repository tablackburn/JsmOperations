[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Pester BeforeAll/It scope'
)]
param()

BeforeDiscovery {
    if ($null -eq $Env:BHBuildOutput) {
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

Describe 'Get-JsmConnection' {

    AfterEach {
        InModuleScope $Env:BHProjectName { $script:JsmConnection = $null }
    }

    It 'Returns $null when no connection is active' {
        InModuleScope $Env:BHProjectName { $script:JsmConnection = $null }
        Get-JsmConnection | Should -BeNullOrEmpty
    }

    It 'Returns a view of the connection without ApiToken' {
        $tok = New-TestSecureString 'tok'
        InModuleScope $Env:BHProjectName -Parameters @{ Tok = $tok } {
            param($Tok)
            $script:JsmConnection = [pscustomobject]@{
                Email       = 'me@example.com'
                ApiToken    = $Tok
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
