function Disconnect-JsmService {
    <#
    .SYNOPSIS
        Clears the in-memory JSM connection.

    .DESCRIPTION
        Removes the connection state set by Connect-JsmService from the module's
        script scope. Idempotent: calling without an active connection is not
        an error. Subsequent JsmOperations cmdlets will throw a "no active
        connection" error until Connect-JsmService is called again.

    .EXAMPLE
        Disconnect-JsmService

        Clears the active connection. The next call to Get-JsmAlert (or any
        other cmdlet that hits the API) will throw.

    .OUTPUTS
        None.

    .NOTES
        Useful at the end of automation scripts or before switching between sites
        in the same session.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    begin {
        Write-Verbose 'Starting Disconnect-JsmService'
    }

    process {
        $script:JsmConnection = $null
    }

    end {
        Write-Verbose 'Completed Disconnect-JsmService'
    }
}
