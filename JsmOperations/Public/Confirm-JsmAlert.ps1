function Confirm-JsmAlert {
    <#
    .SYNOPSIS
        Acknowledges an alert in JSM Cloud Operations.

    .DESCRIPTION
        Sends POST /v1/alerts/{id}/acknowledge. The acknowledge operation is
        asynchronous on the server side, so the response is a request-status
        object rather than the updated alert. Pass -Verbose to see the request
        URL.

        Pipeline-friendly: pipe alerts (or their ids) directly in.

    .PARAMETER Id
        The alert id (UUID or tinyId). Accepts pipeline input by value and by
        property name.

    .PARAMETER Note
        An optional note attached to the acknowledge action. Visible in the
        alert's activity log.

    .EXAMPLE
        Confirm-JsmAlert -Id 'abc-123-...'

        Acknowledges a single alert.

    .EXAMPLE
        Get-JsmAlert -Query 'status:open AND priority:P5' | Confirm-JsmAlert -Note 'Bulk-acked low-priority'

        Acknowledges all open P5 alerts with an explanatory note.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
        The asynchronous request-status object returned by the API.

    .NOTES
        Acknowledgement is async: the alert's status field will not update
        immediately. Re-fetch with Get-JsmAlert -Id to confirm.
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
        Write-Verbose 'Starting Confirm-JsmAlert'
    }

    process {
        try {
            $body = @{}
            if ($PSBoundParameters.ContainsKey('Note')) {
                $body.note = $Note
            }
            $response = Invoke-JsmApi -Method 'Post' -Path "/alerts/$Id/acknowledge" -Body $body
            Write-Output $response
        }
        catch {
            throw
        }
    }

    end {
        Write-Verbose 'Completed Confirm-JsmAlert'
    }
}
