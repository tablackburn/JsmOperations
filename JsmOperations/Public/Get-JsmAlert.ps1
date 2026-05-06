function Get-JsmAlert {
    <#
    .SYNOPSIS
        Retrieves alerts from the JSM Cloud Operations API.

    .DESCRIPTION
        Two modes of operation, selected by parameter set:
        - List (default): GET /v1/alerts with optional Lucene query, sort, and
          page size. Returns the .values payload from the response envelope.
        - ById: GET /v1/alerts/{id} for a single alert. Accepts the id from the
          pipeline (by value or by property name), so you can chain from list
          output: Get-JsmAlert -Query 'status:open' | Get-JsmAlert.

        v0.1.0 returns the raw deserialized JSON. No reshaping or type accelerator.

    .PARAMETER Id
        The alert id (UUID or tinyId). Accepts pipeline input by value and by
        property name.

    .PARAMETER Query
        A Lucene query string (e.g. 'status:open AND priority:P1'). See the
        Atlassian JSM Operations API docs for syntax.

    .PARAMETER Limit
        Maximum number of alerts to return. Maps to the API's 'size' parameter.
        Default 20.

    .PARAMETER OrderBy
        Field to sort by. Default 'updatedAt'.

    .PARAMETER Order
        Sort direction. 'asc' or 'desc'. Default 'desc'.

    .EXAMPLE
        Get-JsmAlert -Limit 5

        Returns the five most recently updated alerts.

    .EXAMPLE
        Get-JsmAlert -Query 'status:open AND priority:P1' -Limit 50

        Returns up to 50 open P1 alerts.

    .EXAMPLE
        Get-JsmAlert -Id 'abc-123-...'

        Returns the detail object for a single alert.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Raw alert objects as deserialized from the API JSON.

    .NOTES
        The List set returns the response.values array; the ById set returns the
        response object directly.
    #>
    [CmdletBinding(DefaultParameterSetName = 'List')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(
            ParameterSetName = 'ById',
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Id,

        [Parameter(ParameterSetName = 'List')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Query,

        [Parameter(ParameterSetName = 'List')]
        [ValidateRange(1, 100)]
        [int]
        $Limit = 20,

        [Parameter(ParameterSetName = 'List')]
        [ValidateSet(
            'createdAt', 'updatedAt', 'tinyId', 'alias', 'message', 'status',
            'acknowledged', 'isSeen', 'snoozed', 'snoozedUntil', 'count',
            'lastOccurredAt', 'source', 'owner', 'integration.name',
            'integration.type', 'report.ackTime', 'report.closeTime',
            'report.acknowledgedBy', 'report.closedBy'
        )]
        [string]
        $OrderBy = 'updatedAt',

        [Parameter(ParameterSetName = 'List')]
        [ValidateSet('asc', 'desc')]
        [string]
        $Order = 'desc'
    )

    begin {
        Write-Verbose 'Starting Get-JsmAlert'
    }

    process {
        try {
            if ($PSCmdlet.ParameterSetName -eq 'ById') {
                $response = Invoke-JsmApi -Method 'Get' -Path "/alerts/$Id"
                Write-Output $response
            }
            else {
                $queryParams = @{
                    size    = $Limit
                    sort    = $OrderBy
                    order   = $Order
                }
                if (-not [string]::IsNullOrWhiteSpace($Query)) {
                    $queryParams.query = $Query
                }
                $response = Invoke-JsmApi -Method 'Get' -Path '/alerts' -Query $queryParams
                if ($null -ne $response.values) {
                    Write-Output $response.values
                }
            }
        }
        catch {
            throw
        }
    }

    end {
        Write-Verbose 'Completed Get-JsmAlert'
    }
}
