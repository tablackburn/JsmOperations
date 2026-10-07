function Resolve-JsmAlertId {
    <#
    .SYNOPSIS
        Resolves an alert identifier of the given type to the alert's UUID.

    .DESCRIPTION
        The JSM Cloud Operations alert endpoints (GET /v1/alerts/{id}, close,
        acknowledge) only accept the alert UUID; there is no identifierType query
        parameter as there was in the legacy Opsgenie API. This helper maps the
        other identifier types to a UUID client-side:

        - id: returned unchanged, no API call.
        - alias: GET /v1/alerts/alias?alias={alias}. That endpoint only resolves
          open alerts, so on a 404 it falls back to
          GET /v1/alerts?query=alias:"{alias}", filtered to exact matches.
        - tiny: GET /v1/alerts?query=tinyId:{tinyId}, filtered to exact matches.

        tinyIds are reused over time, and an alias is only unique among open
        alerts, so a query can return several alerts. When that happens the
        single non-closed match wins; otherwise the most recently created match
        is used and a warning is written.

        Not exported; not callable by module consumers.

    .PARAMETER Id
        The alert identifier to resolve.

    .PARAMETER IdentifierType
        How to interpret -Id: 'id' (alert UUID), 'tiny' (tinyId), or 'alias'.

    .EXAMPLE
        Resolve-JsmAlertId -Id '623551' -IdentifierType 'tiny'

        Returns the UUID of the alert whose tinyId is 623551.

    .OUTPUTS
        System.String
        The alert UUID.

    .NOTES
        Throws when no alert matches. HTTP errors from Invoke-JsmApi propagate as-is.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [ValidateSet('id', 'tiny', 'alias')]
        [string]
        $IdentifierType
    )

    begin {
        Write-Verbose 'Starting Resolve-JsmAlertId'
    }

    process {
        try {
            if ($IdentifierType -eq 'id') {
                Write-Output $Id
                return
            }

            if ($IdentifierType -eq 'alias') {
                try {
                    $alert = Invoke-JsmApi -Method 'Get' -Path '/alerts/alias' -Query @{ alias = $Id }
                    Write-Output $alert.id
                    return
                }
                catch {
                    # The alias endpoint only resolves open alerts; anything other than a 404 is a real error.
                    if ([int]$_.Exception.Response.StatusCode -ne 404) {
                        throw
                    }
                }
                $escapedAlias = $Id -replace '([\\"])', '\$1'
                $searchQuery = "alias:`"$escapedAlias`""
                $matchProperty = 'alias'
                $label = 'alias'
            }
            else {
                if ($Id -notmatch '^\d+$') {
                    throw "Invalid tinyId '$Id'. A tinyId is a whole number, such as 623551."
                }
                $searchQuery = "tinyId:$Id"
                $matchProperty = 'tinyId'
                $label = 'tinyId'
            }

            $queryParams = @{
                query = $searchQuery
                size  = 100
                sort  = 'createdAt'
                order = 'desc'
            }
            $response = Invoke-JsmApi -Method 'Get' -Path '/alerts' -Query $queryParams
            # The query matches loosely (tinyId:77070 also returns 770701), so keep exact matches only.
            $alertMatches = @($response.values | Where-Object { [string]$_.$matchProperty -ceq $Id })
            if ($alertMatches.Count -eq 0) {
                throw "No alert found with $label '$Id'."
            }

            $openMatches = @($alertMatches | Where-Object { $_.status -ne 'closed' })
            if ($openMatches.Count -eq 1) {
                Write-Output $openMatches[0].id
            }
            else {
                $candidates = if ($openMatches.Count -gt 1) { $openMatches } else { $alertMatches }
                $newest = $candidates | Sort-Object -Property { [datetime]$_.createdAt } -Descending | Select-Object -First 1
                if ($candidates.Count -gt 1) {
                    Write-Warning "$label '$Id' matches $($candidates.Count) alerts; using the most recently created ($($newest.id)). Pass the UUID to target a different one."
                }
                Write-Output $newest.id
            }
        }
        catch {
            throw
        }
    }

    end {
        Write-Verbose 'Completed Resolve-JsmAlertId'
    }
}
