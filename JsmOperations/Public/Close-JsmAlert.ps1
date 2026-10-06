function Close-JsmAlert {
    <#
    .SYNOPSIS
        Closes an alert in JSM Cloud Operations.

    .DESCRIPTION
        Sends POST /v1/alerts/{id}/close. A tinyId or alias given with
        -IdentifierType is first resolved to the alert UUID. The close operation
        is asynchronous on the server side, so the response is a request-status
        object rather than the updated alert. Pass -Verbose to see the request
        URL.

        Pipeline-friendly: pipe alerts (or their ids) directly in.

    .PARAMETER Id
        The alert identifier. Interpreted as the alert UUID by default; pass
        -IdentifierType tiny for the short numeric tinyId shown in the JSM UI, or
        -IdentifierType alias for an integration alias. Accepts pipeline input by
        value and by property name.

    .PARAMETER IdentifierType
        How to interpret -Id: 'id' (alert UUID, the default), 'tiny' (tinyId), or
        'alias' (integration alias). The JSM Cloud API only addresses alerts by
        UUID, so 'tiny' and 'alias' cost one extra lookup call. tinyIds are
        reused over time; if several alerts share one, the single non-closed
        alert is used, otherwise the most recently created (with a warning).
        Piped alert objects bind their id (UUID) property, so leave the default
        when piping.

    .PARAMETER Note
        An optional note attached to the close action. Visible in the alert's
        activity log.

    .EXAMPLE
        Close-JsmAlert -Id 'abc-123-...'

        Closes a single alert.

    .EXAMPLE
        Close-JsmAlert -Id 623551 -IdentifierType tiny -Note 'Resolved'

        Closes the alert whose tinyId (the number shown in the JSM UI) is 623551.

    .EXAMPLE
        Get-JsmAlert -Query 'status:open AND tag:stale' | Close-JsmAlert -Note 'Auto-closed by stale-alert sweep'

        Closes all open alerts tagged stale and stamps a note explaining why.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
        The asynchronous request-status object returned by the API.

    .NOTES
        Close is async: the alert's status field will not update immediately.
        Re-fetch with Get-JsmAlert -Id to confirm.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Id,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Note,

        [Parameter()]
        [ValidateSet('id', 'tiny', 'alias')]
        [string]
        $IdentifierType = 'id'
    )

    begin {
        Write-Verbose 'Starting Close-JsmAlert'
    }

    process {
        try {
            $body = @{}
            if ($PSBoundParameters.ContainsKey('Note')) {
                $body.note = $Note
            }
            $alertId = Resolve-JsmAlertId -Id $Id -IdentifierType $IdentifierType
            $response = Invoke-JsmApi -Method 'Post' -Path "/alerts/$alertId/close" -Body $body
            Write-Output $response
        }
        catch {
            throw
        }
    }

    end {
        Write-Verbose 'Completed Close-JsmAlert'
    }
}
