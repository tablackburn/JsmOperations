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
}

Describe 'Close-JsmAlert' {

    It 'POSTs to /alerts/{id}/close with empty body when no note is given' {
        InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
            Mock -CommandName 'Invoke-JsmApi' -MockWith { @{ requestId = 'r1' } }
            Close-JsmAlert -Id 'abc-123' | Out-Null
            Should -Invoke -CommandName 'Invoke-JsmApi' -Times 1 -ParameterFilter {
                $Method -eq 'Post' -and
                $Path -eq '/alerts/abc-123/close' -and
                $Body.Count -eq 0
            }
        }
    }

    It 'Includes the note in the body when -Note is supplied' {
        InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
            Mock -CommandName 'Invoke-JsmApi' -MockWith { @{ requestId = 'r2' } }
            Close-JsmAlert -Id 'abc-123' -Note 'resolved' | Out-Null
            Should -Invoke -CommandName 'Invoke-JsmApi' -Times 1 -ParameterFilter {
                $Body.note -eq 'resolved'
            }
        }
    }

    It 'Accepts pipeline input by value' {
        InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
            Mock -CommandName 'Invoke-JsmApi' -MockWith { @{ requestId = 'r3' } }
            'piped-id' | Close-JsmAlert | Out-Null
            Should -Invoke -CommandName 'Invoke-JsmApi' -Times 1 -ParameterFilter {
                $Path -eq '/alerts/piped-id/close'
            }
        }
    }

    It 'Rejects an empty -Note value' {
        { Close-JsmAlert -Id 'abc-123' -Note '' } | Should -Throw
    }
}
