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
}

Describe 'Confirm-JsmAlert' {

    It 'POSTs to /alerts/{id}/acknowledge with empty body when no note is given' {
        InModuleScope $Env:BHProjectName {
            Mock Invoke-JsmApi { @{ requestId = 'r1' } }
            Confirm-JsmAlert -Id 'abc-123' | Out-Null
            Should -Invoke Invoke-JsmApi -Times 1 -ParameterFilter {
                $Method -eq 'Post' -and
                $Path -eq '/alerts/abc-123/acknowledge' -and
                $Body.Count -eq 0
            }
        }
    }

    It 'Includes the note in the body when -Note is supplied' {
        InModuleScope $Env:BHProjectName {
            Mock Invoke-JsmApi { @{ requestId = 'r2' } }
            Confirm-JsmAlert -Id 'abc-123' -Note 'investigating' | Out-Null
            Should -Invoke Invoke-JsmApi -Times 1 -ParameterFilter {
                $Body.note -eq 'investigating'
            }
        }
    }

    It 'Accepts pipeline input by value' {
        InModuleScope $Env:BHProjectName {
            Mock Invoke-JsmApi { @{ requestId = 'r3' } }
            'piped-id' | Confirm-JsmAlert | Out-Null
            Should -Invoke Invoke-JsmApi -Times 1 -ParameterFilter {
                $Path -eq '/alerts/piped-id/acknowledge'
            }
        }
    }

    It 'Accepts pipeline input by property name' {
        InModuleScope $Env:BHProjectName {
            Mock Invoke-JsmApi { @{ requestId = 'r4' } }
            [pscustomobject]@{ Id = 'prop-id' } | Confirm-JsmAlert | Out-Null
            Should -Invoke Invoke-JsmApi -Times 1 -ParameterFilter {
                $Path -eq '/alerts/prop-id/acknowledge'
            }
        }
    }
}
