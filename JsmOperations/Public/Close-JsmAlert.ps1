function Close-JsmAlert {
    <#
    .SYNOPSIS
        Closes an alert in JSM Cloud Operations.

    .DESCRIPTION
        Sends POST /v1/alerts/{id}/close. The close operation is asynchronous on
        the server side, so the response is a request-status object rather than
        the updated alert. Pass -Verbose to see the request URL.

        Pipeline-friendly: pipe alerts (or their ids) directly in.

    .PARAMETER Id
        The alert id (UUID or tinyId). Accepts pipeline input by value and by
        property name.

    .PARAMETER Note
        An optional note attached to the close action. Visible in the alert's
        activity log.

    .EXAMPLE
        Close-JsmAlert -Id 'abc-123-...'

        Closes a single alert.

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
        $Note
    )

    begin {
        Write-Verbose -Message 'Starting Close-JsmAlert'
    }

    process {
        try {
            $body = @{}
            if ($PSBoundParameters.ContainsKey('Note')) {
                $body.note = $Note
            }
            $response = Invoke-JsmApi -Method 'Post' -Path "/alerts/$Id/close" -Body $body
            Write-Output -InputObject $response
        }
        catch {
            throw
        }
    }

    end {
        Write-Verbose -Message 'Completed Close-JsmAlert'
    }
}
