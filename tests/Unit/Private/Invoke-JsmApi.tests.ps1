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

InModuleScope $Env:BHProjectName {
    Describe 'Invoke-JsmApi' {

        BeforeEach {
            $secureToken = [System.Security.SecureString]::new()
            foreach ($c in 'fake-token'.ToCharArray()) { $secureToken.AppendChar($c) }
            $secureToken.MakeReadOnly()
            $script:JsmConnection = [pscustomobject]@{
                Email       = 'me@example.com'
                ApiToken    = $secureToken
                CloudId     = 'cloud-123'
                BaseUri     = 'https://api.atlassian.com/jsm/ops/api/cloud-123/v1'
                ConnectedAt = [datetime]::UtcNow
            }
        }

        AfterEach {
            $script:JsmConnection = $null
        }

        Context 'Connection state' {
            It 'Throws a friendly error when no connection is active' {
                $script:JsmConnection = $null
                { Invoke-JsmApi -Method 'Get' -Path '/alerts' } |
                    Should -Throw -ExpectedMessage '*Connect-JsmService*'
            }
        }

        Context 'URL composition' {
            It 'Concatenates BaseUri and Path' {
                Mock -CommandName 'Invoke-RestMethod' -MockWith { @{ ok = $true } }
                Invoke-JsmApi -Method 'Get' -Path '/alerts/abc-123' | Out-Null
                Should -Invoke -CommandName 'Invoke-RestMethod' -Times 1 -ParameterFilter {
                    $Uri -eq 'https://api.atlassian.com/jsm/ops/api/cloud-123/v1/alerts/abc-123'
                }
            }

            It 'Appends URL-encoded query parameters' {
                Mock -CommandName 'Invoke-RestMethod' -MockWith { @{ ok = $true } }
                Invoke-JsmApi -Method 'Get' -Path '/alerts' -Query @{ size = 5; query = 'status:open' } | Out-Null
                Should -Invoke -CommandName 'Invoke-RestMethod' -Times 1 -ParameterFilter {
                    $Uri -match 'size=5' -and $Uri -match 'query=status%3Aopen'
                }
            }
        }

        Context 'Authorization header' {
            It 'Builds Basic auth from email + token' {
                Mock -CommandName 'Invoke-RestMethod' -MockWith { @{ ok = $true } }
                Invoke-JsmApi -Method 'Get' -Path '/alerts' | Out-Null
                Should -Invoke -CommandName 'Invoke-RestMethod' -Times 1 -ParameterFilter {
                    $expectedB64 = [Convert]::ToBase64String(
                        [Text.Encoding]::UTF8.GetBytes('me@example.com:fake-token')
                    )
                    $Headers.Authorization -eq "Basic $expectedB64"
                }
            }
        }

        Context 'Body serialization' {
            It 'Serializes hashtable Body as JSON' {
                Mock -CommandName 'Invoke-RestMethod' -MockWith { @{ ok = $true } }
                Invoke-JsmApi -Method 'Post' -Path '/alerts/abc/acknowledge' -Body @{ note = 'hello' } | Out-Null
                Should -Invoke -CommandName 'Invoke-RestMethod' -Times 1 -ParameterFilter {
                    $Body -eq '{"note":"hello"}'
                }
            }

            It 'Omits Body when not supplied' {
                Mock -CommandName 'Invoke-RestMethod' -MockWith { @{ ok = $true } }
                Invoke-JsmApi -Method 'Get' -Path '/alerts' | Out-Null
                Should -Invoke -CommandName 'Invoke-RestMethod' -Times 1 -ParameterFilter {
                    -not $PSBoundParameters.ContainsKey('Body')
                }
            }

            It 'Omits Body when supplied as empty hashtable' {
                Mock -CommandName 'Invoke-RestMethod' -MockWith { @{ ok = $true } }
                Invoke-JsmApi -Method 'Post' -Path '/alerts/abc/acknowledge' -Body @{} | Out-Null
                Should -Invoke -CommandName 'Invoke-RestMethod' -Times 1 -ParameterFilter {
                    -not $PSBoundParameters.ContainsKey('Body')
                }
            }
        }

        Context 'Error propagation' {
            It 'Rethrows HTTP errors from Invoke-RestMethod' {
                Mock -CommandName 'Invoke-RestMethod' -MockWith { throw 'HTTP 401' }
                { Invoke-JsmApi -Method 'Get' -Path '/alerts' } | Should -Throw '*HTTP 401*'
            }
        }

        Context 'Method validation' {
            It 'Rejects unsupported HTTP methods' {
                { Invoke-JsmApi -Method 'Delete' -Path '/alerts/abc' } | Should -Throw
            }
        }
    }
}
