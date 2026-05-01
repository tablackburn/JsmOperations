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
                { Invoke-JsmApi -Method Get -Path '/alerts' } |
                    Should -Throw -ExpectedMessage '*Connect-JsmService*'
            }
        }

        Context 'URL composition' {
            It 'Concatenates BaseUri and Path' {
                Mock Invoke-RestMethod { @{ ok = $true } }
                Invoke-JsmApi -Method Get -Path '/alerts/abc-123' | Out-Null
                Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                    $Uri -eq 'https://api.atlassian.com/jsm/ops/api/cloud-123/v1/alerts/abc-123'
                }
            }

            It 'Appends URL-encoded query parameters' {
                Mock Invoke-RestMethod { @{ ok = $true } }
                Invoke-JsmApi -Method Get -Path '/alerts' -Query @{ size = 5; query = 'status:open' } | Out-Null
                Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                    $Uri -match 'size=5' -and $Uri -match 'query=status%3Aopen'
                }
            }
        }

        Context 'Authorization header' {
            It 'Builds Basic auth from email + token' {
                Mock Invoke-RestMethod { @{ ok = $true } }
                Invoke-JsmApi -Method Get -Path '/alerts' | Out-Null
                Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                    $expectedB64 = [Convert]::ToBase64String(
                        [Text.Encoding]::UTF8.GetBytes('me@example.com:fake-token')
                    )
                    $Headers.Authorization -eq "Basic $expectedB64"
                }
            }
        }

        Context 'Body serialization' {
            It 'Serializes hashtable Body as JSON' {
                Mock Invoke-RestMethod { @{ ok = $true } }
                Invoke-JsmApi -Method Post -Path '/alerts/abc/acknowledge' -Body @{ note = 'hello' } | Out-Null
                Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                    $Body -eq '{"note":"hello"}'
                }
            }

            It 'Omits Body when not supplied' {
                Mock Invoke-RestMethod { @{ ok = $true } }
                Invoke-JsmApi -Method Get -Path '/alerts' | Out-Null
                Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                    -not $PSBoundParameters.ContainsKey('Body')
                }
            }
        }

        Context 'Error propagation' {
            It 'Rethrows HTTP errors from Invoke-RestMethod' {
                Mock Invoke-RestMethod { throw 'HTTP 401' }
                { Invoke-JsmApi -Method Get -Path '/alerts' } | Should -Throw '*HTTP 401*'
            }
        }

        Context 'Method validation' {
            It 'Rejects unsupported HTTP methods' {
                { Invoke-JsmApi -Method Delete -Path '/alerts/abc' } | Should -Throw
            }
        }
    }
}
