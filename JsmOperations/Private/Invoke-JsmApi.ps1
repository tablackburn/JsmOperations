function Invoke-JsmApi {
    <#
    .SYNOPSIS
        Internal HTTP transport for the JSM Cloud Operations API.

    .DESCRIPTION
        Single private helper that every public JsmOperations cmdlet routes through.
        Reads the active connection from script-scoped state (set by Connect-JsmService),
        builds Basic auth headers from the SecureString token, and invokes the REST call.

        Not exported; not callable by module consumers.

    .PARAMETER Method
        HTTP method. Currently only Get and Post are used by v0.1.0 cmdlets.

    .PARAMETER Path
        API path relative to the connection's BaseUri (e.g. '/alerts' or "/alerts/$id/acknowledge").

    .PARAMETER Body
        Optional hashtable. Serialized to JSON and sent as the request body.

    .PARAMETER Query
        Optional hashtable of query-string parameters.

    .EXAMPLE
        Invoke-JsmApi -Method Get -Path '/alerts' -Query @{ size = 5 }

        Lists the first five alerts via the JSM Cloud canonical API.

    .OUTPUTS
        System.Object
        Returns the deserialized response from Invoke-RestMethod.

    .NOTES
        Throws a friendly error if no connection is active. HTTP errors propagate as-is.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Get', 'Post')]
        [string]
        $Method,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter(Mandatory = $false)]
        [hashtable]
        $Body,

        [Parameter(Mandatory = $false)]
        [hashtable]
        $Query
    )

    begin {
        Write-Verbose 'Starting Invoke-JsmApi'
        if ($null -eq $script:JsmConnection) {
            throw 'No active JSM connection. Run Connect-JsmService before calling other JsmOperations cmdlets.'
        }
    }

    process {
        try {
            $uri = $script:JsmConnection.BaseUri + $Path

            if ($Query -and $Query.Count -gt 0) {
                $pairs = foreach ($entry in $Query.GetEnumerator()) {
                    $key = [uri]::EscapeDataString($entry.Key)
                    $val = [uri]::EscapeDataString([string]$entry.Value)
                    "$key=$val"
                }
                $uri = $uri + '?' + ($pairs -join '&')
            }

            $tokenPlain = [pscredential]::new(
                'jsm',
                $script:JsmConnection.ApiToken
            ).GetNetworkCredential().Password
            $pair = "$($script:JsmConnection.Email):$tokenPlain"
            $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pair))
            $headers = @{ Authorization = "Basic $b64" }

            $invokeParameters = @{
                Method      = $Method
                Uri         = $uri
                Headers     = $headers
                ContentType = 'application/json'
                ErrorAction = 'Stop'
            }
            if ($Body -and $Body.Count -gt 0) {
                $invokeParameters.Body = ($Body | ConvertTo-Json -Depth 10 -Compress)
            }

            Write-Verbose "Calling $Method $uri"
            $response = Invoke-RestMethod @invokeParameters
            Write-Output $response
        }
        catch {
            throw
        }
    }

    end {
        Write-Verbose 'Completed Invoke-JsmApi'
    }
}
