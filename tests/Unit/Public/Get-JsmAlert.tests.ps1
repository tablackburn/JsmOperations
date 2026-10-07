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

Describe 'Get-JsmAlert' {

    Context 'List parameter set' {

        It 'Calls Invoke-JsmApi with default query parameters' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi' -MockWith { @{ values = @() } }
                Get-JsmAlert | Out-Null
                Should -Invoke -CommandName 'Invoke-JsmApi' -Times 1 -ParameterFilter {
                    $Method -eq 'Get' -and
                    $Path -eq '/alerts' -and
                    $Query.size -eq 20 -and
                    $Query.sort -eq 'updatedAt' -and
                    $Query.order -eq 'desc' -and
                    -not $Query.ContainsKey('query') -and
                    -not $Query.ContainsKey('identifierType')
                }
            }
        }

        It 'Includes the Lucene query when -Query is supplied' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi' -MockWith { @{ values = @() } }
                Get-JsmAlert -Query 'status:open' -Limit 5 -Order 'asc' | Out-Null
                Should -Invoke -CommandName 'Invoke-JsmApi' -Times 1 -ParameterFilter {
                    $Query.query -eq 'status:open' -and
                    $Query.size -eq 5 -and
                    $Query.order -eq 'asc'
                }
            }
        }

        It 'Returns the .values payload' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi' -MockWith { @{ values = @(@{ id = 'a' }, @{ id = 'b' }) } }
                $result = Get-JsmAlert
                $result.Count | Should -Be 2
                $result[0].id | Should -Be 'a'
            }
        }

        It 'Rejects -Limit values outside 1..100' {
            { Get-JsmAlert -Limit 0 } | Should -Throw
            { Get-JsmAlert -Limit 101 } | Should -Throw
        }

        It 'Rejects unknown -OrderBy values' {
            { Get-JsmAlert -OrderBy 'notARealField' } | Should -Throw
        }
    }

    Context 'ById parameter set' {

        It 'Calls Invoke-JsmApi with /alerts/{id}' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi' -MockWith { @{ id = 'abc-123'; message = 'one' } }
                Get-JsmAlert -Id 'abc-123' | Out-Null
                Should -Invoke -CommandName 'Invoke-JsmApi' -Times 1 -ParameterFilter {
                    $Method -eq 'Get' -and $Path -eq '/alerts/abc-123'
                }
            }
        }

        It 'Returns the response object directly' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi' -MockWith { @{ id = 'abc-123'; message = 'one' } }
                $result = Get-JsmAlert -Id 'abc-123'
                $result.id | Should -Be 'abc-123'
                $result.message | Should -Be 'one'
            }
        }

        It 'Accepts pipeline input by value' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi' -MockWith { @{ id = 'piped' } }
                'piped' | Get-JsmAlert | Out-Null
                Should -Invoke -CommandName 'Invoke-JsmApi' -Times 1 -ParameterFilter {
                    $Path -eq '/alerts/piped'
                }
            }
        }

        It 'Resolves the id as a UUID by default' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Invoke-JsmApi' -MockWith { @{ id = 'abc-123' } }
                Get-JsmAlert -Id 'abc-123' | Out-Null
                Should -Invoke -CommandName 'Invoke-JsmApi' -Times 1 -ParameterFilter {
                    $Path -eq '/alerts/abc-123'
                }
            }
        }

        It 'Resolves a tinyId to the alert UUID before fetching' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Resolve-JsmAlertId' -MockWith { 'resolved-uuid' }
                Mock -CommandName 'Invoke-JsmApi' -MockWith { @{ id = 'resolved-uuid'; tinyId = '623551' } }
                $result = Get-JsmAlert -Id '623551' -IdentifierType 'tiny'
                $result.id | Should -Be 'resolved-uuid'
                Should -Invoke -CommandName 'Resolve-JsmAlertId' -Times 1 -ParameterFilter {
                    $Id -eq '623551' -and $IdentifierType -eq 'tiny'
                }
                Should -Invoke -CommandName 'Invoke-JsmApi' -Times 1 -ParameterFilter {
                    $Method -eq 'Get' -and $Path -eq '/alerts/resolved-uuid'
                }
            }
        }

        It 'Resolves an alias to the alert UUID before fetching' {
            InModuleScope -ModuleName $Env:BHProjectName -ScriptBlock {
                Mock -CommandName 'Resolve-JsmAlertId' -MockWith { 'resolved-uuid' }
                Mock -CommandName 'Invoke-JsmApi' -MockWith { @{ id = 'resolved-uuid' } }
                Get-JsmAlert -Id 'my alias/x' -IdentifierType 'alias' | Out-Null
                Should -Invoke -CommandName 'Resolve-JsmAlertId' -Times 1 -ParameterFilter {
                    $Id -eq 'my alias/x' -and $IdentifierType -eq 'alias'
                }
                Should -Invoke -CommandName 'Invoke-JsmApi' -Times 1 -ParameterFilter {
                    $Path -eq '/alerts/resolved-uuid'
                }
            }
        }

        It 'Rejects an unknown -IdentifierType value' {
            { Get-JsmAlert -Id 'abc-123' -IdentifierType 'bogus' } | Should -Throw
        }

        It 'Does not allow -IdentifierType in the List parameter set' {
            { Get-JsmAlert -Query 'status:open' -IdentifierType 'tiny' } | Should -Throw
        }
    }
}
