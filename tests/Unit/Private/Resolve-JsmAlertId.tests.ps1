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

Describe 'Resolve-JsmAlertId' {

    Context 'id' {

        It 'Returns the id unchanged without calling the API' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi'
                Resolve-JsmAlertId -Id 'abc-123' -IdentifierType 'id' | Should -Be 'abc-123'
                Should -Invoke -CommandName 'Invoke-JsmApi' -Times 0
            }
        }
    }

    Context 'alias' {

        It 'Looks the alert up via GET /alerts/alias and returns its id' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi' -MockWith { [pscustomobject]@{ id = 'uuid-from-alias'; alias = 'my alias/x' } }
                Resolve-JsmAlertId -Id 'my alias/x' -IdentifierType 'alias' | Should -Be 'uuid-from-alias'
                Should -Invoke -CommandName 'Invoke-JsmApi' -Times 1 -ParameterFilter {
                    $Method -eq 'Get' -and
                    $Path -eq '/alerts/alias' -and
                    $Query.alias -eq 'my alias/x'
                }
            }
        }
    }

    Context 'tiny' {

        It 'Queries the list endpoint by tinyId' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi' -MockWith {
                    [pscustomobject]@{ values = @([pscustomobject]@{ id = 'uuid-1'; tinyId = '623551'; status = 'open'; createdAt = '2026-10-01T00:00:00Z' }) }
                }
                Resolve-JsmAlertId -Id '623551' -IdentifierType 'tiny' | Should -Be 'uuid-1'
                Should -Invoke -CommandName 'Invoke-JsmApi' -Times 1 -ParameterFilter {
                    $Method -eq 'Get' -and
                    $Path -eq '/alerts' -and
                    $Query.query -eq 'tinyId:623551'
                }
            }
        }

        It 'Ignores loose matches whose tinyId is not an exact match' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi' -MockWith {
                    [pscustomobject]@{ values = @(
                            [pscustomobject]@{ id = 'uuid-wrong'; tinyId = '6235510'; status = 'open'; createdAt = '2026-10-02T00:00:00Z' }
                            [pscustomobject]@{ id = 'uuid-right'; tinyId = '623551'; status = 'open'; createdAt = '2026-10-01T00:00:00Z' }
                        ) }
                }
                Resolve-JsmAlertId -Id '623551' -IdentifierType 'tiny' | Should -Be 'uuid-right'
            }
        }

        It 'Prefers the single non-closed alert when a tinyId has been reused' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi' -MockWith {
                    [pscustomobject]@{ values = @(
                            [pscustomobject]@{ id = 'uuid-old-closed'; tinyId = '623551'; status = 'closed'; createdAt = '2026-10-05T00:00:00Z' }
                            [pscustomobject]@{ id = 'uuid-open'; tinyId = '623551'; status = 'open'; createdAt = '2026-04-01T00:00:00Z' }
                        ) }
                }
                Mock -CommandName 'Write-Warning'
                Resolve-JsmAlertId -Id '623551' -IdentifierType 'tiny' | Should -Be 'uuid-open'
                Should -Invoke -CommandName 'Write-Warning' -Times 0
            }
        }

        It 'Falls back to the most recently created match and warns when still ambiguous' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi' -MockWith {
                    [pscustomobject]@{ values = @(
                            [pscustomobject]@{ id = 'uuid-older'; tinyId = '623551'; status = 'closed'; createdAt = '2026-04-01T00:00:00Z' }
                            [pscustomobject]@{ id = 'uuid-newer'; tinyId = '623551'; status = 'closed'; createdAt = '2026-10-01T00:00:00Z' }
                        ) }
                }
                Mock -CommandName 'Write-Warning'
                Resolve-JsmAlertId -Id '623551' -IdentifierType 'tiny' | Should -Be 'uuid-newer'
                Should -Invoke -CommandName 'Write-Warning' -Times 1
            }
        }

        It 'Picks the most recently created of several non-closed matches and warns' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi' -MockWith {
                    [pscustomobject]@{ values = @(
                            [pscustomobject]@{ id = 'uuid-closed-newest'; tinyId = '623551'; status = 'closed'; createdAt = '2026-10-05T00:00:00Z' }
                            [pscustomobject]@{ id = 'uuid-open-older'; tinyId = '623551'; status = 'open'; createdAt = '2026-04-01T00:00:00Z' }
                            [pscustomobject]@{ id = 'uuid-open-newer'; tinyId = '623551'; status = 'open'; createdAt = '2026-09-01T00:00:00Z' }
                        ) }
                }
                Mock -CommandName 'Write-Warning'
                Resolve-JsmAlertId -Id '623551' -IdentifierType 'tiny' | Should -Be 'uuid-open-newer'
                Should -Invoke -CommandName 'Write-Warning' -Times 1
            }
        }

        It 'Throws when no alert has that tinyId' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi' -MockWith { [pscustomobject]@{ values = @() } }
                { Resolve-JsmAlertId -Id '623551' -IdentifierType 'tiny' } | Should -Throw '*623551*'
            }
        }

        It 'Rejects a non-numeric tinyId without calling the API' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi'
                { Resolve-JsmAlertId -Id '1 OR status:open' -IdentifierType 'tiny' } | Should -Throw
                Should -Invoke -CommandName 'Invoke-JsmApi' -Times 0
            }
        }
    }
}
