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

Describe 'Confirm-JsmAlert' {

    It 'POSTs to /alerts/{id}/acknowledge with empty body when no note is given' {
        InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
            Mock -CommandName 'Invoke-JsmApi' -MockWith { @{ requestId = 'r1' } }
            Confirm-JsmAlert -Id 'abc-123' | Out-Null
            Should -Invoke -CommandName 'Invoke-JsmApi' -Times 1 -ParameterFilter {
                $Method -eq 'Post' -and
                $Path -eq '/alerts/abc-123/acknowledge' -and
                $Body.Count -eq 0
            }
        }
    }

    It 'Includes the note in the body when -Note is supplied' {
        InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
            Mock -CommandName 'Invoke-JsmApi' -MockWith { @{ requestId = 'r2' } }
            Confirm-JsmAlert -Id 'abc-123' -Note 'investigating' | Out-Null
            Should -Invoke -CommandName 'Invoke-JsmApi' -Times 1 -ParameterFilter {
                $Body.note -eq 'investigating'
            }
        }
    }

    It 'Accepts pipeline input by value' {
        InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
            Mock -CommandName 'Invoke-JsmApi' -MockWith { @{ requestId = 'r3' } }
            'piped-id' | Confirm-JsmAlert | Out-Null
            Should -Invoke -CommandName 'Invoke-JsmApi' -Times 1 -ParameterFilter {
                $Path -eq '/alerts/piped-id/acknowledge'
            }
        }
    }

    It 'Accepts pipeline input by property name' {
        InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
            Mock -CommandName 'Invoke-JsmApi' -MockWith { @{ requestId = 'r4' } }
            [pscustomobject]@{ Id = 'prop-id' } | Confirm-JsmAlert | Out-Null
            Should -Invoke -CommandName 'Invoke-JsmApi' -Times 1 -ParameterFilter {
                $Path -eq '/alerts/prop-id/acknowledge'
            }
        }
    }

    It 'Rejects an empty -Note value' {
        { Confirm-JsmAlert -Id 'abc-123' -Note '' } | Should -Throw
    }

    Context 'Identifier type' {

        It 'Resolves the id as a UUID by default' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi' -MockWith { @{ requestId = 'r5' } }
                Confirm-JsmAlert -Id 'abc-123' | Out-Null
                Should -Invoke -CommandName 'Invoke-JsmApi' -Times 1 -ParameterFilter {
                    $Path -eq '/alerts/abc-123/acknowledge'
                }
            }
        }

        It 'Resolves a tinyId to the alert UUID before acknowledging' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Resolve-JsmAlertId' -MockWith { 'resolved-uuid' }
                Mock -CommandName 'Invoke-JsmApi' -MockWith { @{ requestId = 'r6' } }
                Confirm-JsmAlert -Id '623551' -IdentifierType 'tiny' -Note 'investigating' | Out-Null
                Should -Invoke -CommandName 'Resolve-JsmAlertId' -Times 1 -ParameterFilter {
                    $Id -eq '623551' -and $IdentifierType -eq 'tiny'
                }
                Should -Invoke -CommandName 'Invoke-JsmApi' -Times 1 -ParameterFilter {
                    $Method -eq 'Post' -and
                    $Path -eq '/alerts/resolved-uuid/acknowledge' -and
                    $Body.note -eq 'investigating'
                }
            }
        }

        It 'Resolves an alias to the alert UUID before acknowledging' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Resolve-JsmAlertId' -MockWith { 'resolved-uuid' }
                Mock -CommandName 'Invoke-JsmApi' -MockWith { @{ requestId = 'r7' } }
                Confirm-JsmAlert -Id 'my alias/x' -IdentifierType 'alias' | Out-Null
                Should -Invoke -CommandName 'Resolve-JsmAlertId' -Times 1 -ParameterFilter {
                    $Id -eq 'my alias/x' -and $IdentifierType -eq 'alias'
                }
                Should -Invoke -CommandName 'Invoke-JsmApi' -Times 1 -ParameterFilter {
                    $Path -eq '/alerts/resolved-uuid/acknowledge'
                }
            }
        }

        It 'Keeps -Note as the second positional parameter' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi' -MockWith { @{ requestId = 'r8' } }
                Confirm-JsmAlert 'abc-123' 'investigating' | Out-Null
                Should -Invoke -CommandName 'Invoke-JsmApi' -Times 1 -ParameterFilter {
                    $Path -eq '/alerts/abc-123/acknowledge' -and $Body.note -eq 'investigating'
                }
            }
        }

        It 'Rejects an unknown -IdentifierType value' {
            { Confirm-JsmAlert -Id 'abc-123' -IdentifierType 'bogus' } | Should -Throw
        }
    }
}
