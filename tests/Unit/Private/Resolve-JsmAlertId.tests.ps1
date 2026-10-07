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
                Should -Invoke -CommandName 'Invoke-JsmApi' -Times 0 -ParameterFilter { $Path -eq '/alerts' }
            }
        }

        Context 'Fallback when the alias endpoint returns 404 (it only resolves open alerts)' {

            BeforeAll {
                $script:NotFound = [Microsoft.PowerShell.Commands.HttpResponseException]::new(
                    'Response status code does not indicate success: 404 (Not Found).',
                    [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::NotFound)
                )
            }

            It 'Falls back to a quoted alias: list query and returns the exact match' {
                InModuleScope -ModuleName $Env:BHProjectName -Parameters @{ NotFound = $script:NotFound } -ScriptBlock {
                    param($NotFound)
                    Mock -CommandName 'Invoke-JsmApi' -ParameterFilter { $Path -eq '/alerts/alias' } -MockWith { throw $NotFound }.GetNewClosure()
                    Mock -CommandName 'Invoke-JsmApi' -ParameterFilter { $Path -eq '/alerts' } -MockWith {
                        [pscustomobject]@{ values = @(
                                [pscustomobject]@{ id = 'uuid-loose'; alias = 'my alias/x-2'; status = 'closed'; createdAt = '2026-10-02T00:00:00Z' }
                                [pscustomobject]@{ id = 'uuid-closed'; alias = 'my alias/x'; status = 'closed'; createdAt = '2026-10-01T00:00:00Z' }
                            ) }
                    }
                    Resolve-JsmAlertId -Id 'my alias/x' -IdentifierType 'alias' | Should -Be 'uuid-closed'
                    Should -Invoke -CommandName 'Invoke-JsmApi' -Times 1 -ParameterFilter {
                        $Path -eq '/alerts' -and $Query.query -eq 'alias:"my alias/x"'
                    }
                }
            }

            It 'Escapes quotes and backslashes inside the quoted alias' {
                InModuleScope -ModuleName $Env:BHProjectName -Parameters @{ NotFound = $script:NotFound } -ScriptBlock {
                    param($NotFound)
                    Mock -CommandName 'Invoke-JsmApi' -ParameterFilter { $Path -eq '/alerts/alias' } -MockWith { throw $NotFound }.GetNewClosure()
                    Mock -CommandName 'Invoke-JsmApi' -ParameterFilter { $Path -eq '/alerts' } -MockWith {
                        [pscustomobject]@{ values = @([pscustomobject]@{ id = 'uuid-q'; alias = 'a"b\c'; status = 'closed'; createdAt = '2026-10-01T00:00:00Z' }) }
                    }
                    Resolve-JsmAlertId -Id 'a"b\c' -IdentifierType 'alias' | Should -Be 'uuid-q'
                    Should -Invoke -CommandName 'Invoke-JsmApi' -Times 1 -ParameterFilter {
                        $Path -eq '/alerts' -and $Query.query -eq 'alias:"a\"b\\c"'
                    }
                }
            }

            It 'Picks the most recently created when several closed alerts share the alias, and warns' {
                InModuleScope -ModuleName $Env:BHProjectName -Parameters @{ NotFound = $script:NotFound } -ScriptBlock {
                    param($NotFound)
                    Mock -CommandName 'Invoke-JsmApi' -ParameterFilter { $Path -eq '/alerts/alias' } -MockWith { throw $NotFound }.GetNewClosure()
                    Mock -CommandName 'Invoke-JsmApi' -ParameterFilter { $Path -eq '/alerts' } -MockWith {
                        [pscustomobject]@{ values = @(
                                [pscustomobject]@{ id = 'uuid-older'; alias = 'dup'; status = 'closed'; createdAt = '2026-04-01T00:00:00Z' }
                                [pscustomobject]@{ id = 'uuid-newer'; alias = 'dup'; status = 'closed'; createdAt = '2026-10-01T00:00:00Z' }
                            ) }
                    }
                    Mock -CommandName 'Write-Warning'
                    Resolve-JsmAlertId -Id 'dup' -IdentifierType 'alias' | Should -Be 'uuid-newer'
                    Should -Invoke -CommandName 'Write-Warning' -Times 1
                }
            }

            It 'Throws a not-found error naming the alias when the query has no exact match' {
                InModuleScope -ModuleName $Env:BHProjectName -Parameters @{ NotFound = $script:NotFound } -ScriptBlock {
                    param($NotFound)
                    Mock -CommandName 'Invoke-JsmApi' -ParameterFilter { $Path -eq '/alerts/alias' } -MockWith { throw $NotFound }.GetNewClosure()
                    Mock -CommandName 'Invoke-JsmApi' -ParameterFilter { $Path -eq '/alerts' } -MockWith { [pscustomobject]@{ values = @() } }
                    { Resolve-JsmAlertId -Id 'missing-alias' -IdentifierType 'alias' } | Should -Throw "*alias 'missing-alias'*"
                }
            }

            It 'Pages past a full page of loose matches to find the exact alias' {
                InModuleScope -ModuleName $Env:BHProjectName -Parameters @{ NotFound = $script:NotFound } -ScriptBlock {
                    param($NotFound)
                    Mock -CommandName 'Invoke-JsmApi' -ParameterFilter { $Path -eq '/alerts/alias' } -MockWith { throw $NotFound }.GetNewClosure()
                    Mock -CommandName 'Invoke-JsmApi' -ParameterFilter { $Path -eq '/alerts' } -MockWith {
                        if ($Query.offset -eq 0) {
                            $loose = foreach ($index in 1..100) {
                                [pscustomobject]@{ id = "uuid-loose-$index"; alias = "errors_host$index"; status = 'closed'; createdAt = '2026-10-05T00:00:00Z' }
                            }
                            [pscustomobject]@{ values = @($loose) }
                        }
                        else {
                            [pscustomobject]@{ values = @([pscustomobject]@{ id = 'uuid-exact'; alias = 'errors'; status = 'closed'; createdAt = '2026-04-01T00:00:00Z' }) }
                        }
                    }
                    Resolve-JsmAlertId -Id 'errors' -IdentifierType 'alias' | Should -Be 'uuid-exact'
                    Should -Invoke -CommandName 'Invoke-JsmApi' -Times 1 -Exactly -ParameterFilter { $Path -eq '/alerts' -and $Query.offset -eq 0 }
                    Should -Invoke -CommandName 'Invoke-JsmApi' -Times 1 -Exactly -ParameterFilter { $Path -eq '/alerts' -and $Query.offset -eq 100 }
                }
            }

            It 'Stops paging at the first page that contains an exact alias match' {
                InModuleScope -ModuleName $Env:BHProjectName -Parameters @{ NotFound = $script:NotFound } -ScriptBlock {
                    param($NotFound)
                    Mock -CommandName 'Invoke-JsmApi' -ParameterFilter { $Path -eq '/alerts/alias' } -MockWith { throw $NotFound }.GetNewClosure()
                    Mock -CommandName 'Invoke-JsmApi' -ParameterFilter { $Path -eq '/alerts' } -MockWith {
                        $page = foreach ($index in 1..100) {
                            [pscustomobject]@{ id = "uuid-$($Query.offset)-$index"; alias = 'dup'; status = 'closed'; createdAt = '2026-10-01T00:00:00Z' }
                        }
                        [pscustomobject]@{ values = @($page) }
                    }
                    Mock -CommandName 'Write-Warning'
                    Resolve-JsmAlertId -Id 'dup' -IdentifierType 'alias' | Should -Not -BeNullOrEmpty
                    Should -Invoke -CommandName 'Invoke-JsmApi' -Times 1 -Exactly -ParameterFilter { $Path -eq '/alerts' }
                    Should -Invoke -CommandName 'Write-Warning' -Times 1 -ParameterFilter { $Message -like '*at least 100 alerts*' }
                }
            }

            It 'Rethrows non-404 errors from the alias endpoint without falling back' {
                InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                    $forbidden = [Microsoft.PowerShell.Commands.HttpResponseException]::new(
                        'Response status code does not indicate success: 403 (Forbidden).',
                        [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Forbidden)
                    )
                    Mock -CommandName 'Invoke-JsmApi' -ParameterFilter { $Path -eq '/alerts/alias' } -MockWith { throw $forbidden }.GetNewClosure()
                    Mock -CommandName 'Invoke-JsmApi' -ParameterFilter { $Path -eq '/alerts' }
                    { Resolve-JsmAlertId -Id 'some-alias' -IdentifierType 'alias' } | Should -Throw '*403*'
                    Should -Invoke -CommandName 'Invoke-JsmApi' -Times 0 -ParameterFilter { $Path -eq '/alerts' }
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

        It 'Pages past a full page of loose matches to find the exact tinyId' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi' -MockWith {
                    if ($Query.offset -eq 0) {
                        $loose = foreach ($index in 1..100) {
                            [pscustomobject]@{ id = "uuid-loose-$index"; tinyId = "62355$index"; status = 'closed'; createdAt = '2026-10-05T00:00:00Z' }
                        }
                        [pscustomobject]@{ values = @($loose) }
                    }
                    else {
                        [pscustomobject]@{ values = @([pscustomobject]@{ id = 'uuid-exact'; tinyId = '623551'; status = 'open'; createdAt = '2026-04-01T00:00:00Z' }) }
                    }
                }
                Resolve-JsmAlertId -Id '623551' -IdentifierType 'tiny' | Should -Be 'uuid-exact'
                Should -Invoke -CommandName 'Invoke-JsmApi' -Times 2 -Exactly -ParameterFilter { $Path -eq '/alerts' }
            }
        }

        It 'Prefers an open match on a later page over closed matches on the first page' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi' -MockWith {
                    if ($Query.offset -eq 0) {
                        $closed = foreach ($index in 1..100) {
                            [pscustomobject]@{ id = "uuid-closed-$index"; tinyId = '623551'; status = 'closed'; createdAt = '2026-10-05T00:00:00Z' }
                        }
                        [pscustomobject]@{ values = @($closed) }
                    }
                    else {
                        [pscustomobject]@{ values = @([pscustomobject]@{ id = 'uuid-open'; tinyId = '623551'; status = 'open'; createdAt = '2026-04-01T00:00:00Z' }) }
                    }
                }
                Mock -CommandName 'Write-Warning'
                Resolve-JsmAlertId -Id '623551' -IdentifierType 'tiny' | Should -Be 'uuid-open'
                Should -Invoke -CommandName 'Write-Warning' -Times 0
            }
        }

        It 'Stops after 10 pages and says the search was truncated' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi' -MockWith {
                    $loose = foreach ($index in 1..100) {
                        [pscustomobject]@{ id = "uuid-$($Query.offset)-$index"; tinyId = '9999999'; status = 'closed'; createdAt = '2026-10-05T00:00:00Z' }
                    }
                    [pscustomobject]@{ values = @($loose) }
                }
                Mock -CommandName 'Write-Warning'
                { Resolve-JsmAlertId -Id '623551' -IdentifierType 'tiny' } | Should -Throw '*first 1000 search results*'
                Should -Invoke -CommandName 'Invoke-JsmApi' -Times 10 -Exactly -ParameterFilter { $Path -eq '/alerts' }
                Should -Invoke -CommandName 'Write-Warning' -Times 1 -ParameterFilter { $Message -like '*Stopped searching*' }
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
