function Get-JsmConnection {
    <#
    .SYNOPSIS
        Returns the active JSM connection, with the API token omitted.

    .DESCRIPTION
        Surfaces the connection state set by Connect-JsmService for inspection
        and logging. The returned object intentionally omits the ApiToken
        SecureString so it is safe to pipe into Format-Table, write to logs, or
        share in transcripts. Returns $null when no connection is active.

    .EXAMPLE
        Get-JsmConnection

        Shows the active connection's email, cloud ID, base URI, and the
        timestamp at which Connect-JsmService was last successful.

    .EXAMPLE
        if (-not (Get-JsmConnection)) { Connect-JsmService }

        Idiom for "connect only if not already connected" inside a script.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
        With Email, CloudId, BaseUri, and ConnectedAt fields. $null if not connected.

    .NOTES
        Returns a fresh PSCustomObject - the underlying SecureString token is
        never copied into the result.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    begin {
        Write-Verbose 'Starting Get-JsmConnection'
    }

    process {
        if ($null -eq $script:JsmConnection) {
            Write-Output $null
            return
        }

        $view = [pscustomobject]@{
            Email       = $script:JsmConnection.Email
            CloudId     = $script:JsmConnection.CloudId
            BaseUri     = $script:JsmConnection.BaseUri
            ConnectedAt = $script:JsmConnection.ConnectedAt
        }
        Write-Output $view
    }

    end {
        Write-Verbose 'Completed Get-JsmConnection'
    }
}
