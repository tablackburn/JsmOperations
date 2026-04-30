function Get-JsmExample {
    <#
    .SYNOPSIS
        Example public function for JsmOperations.

    .DESCRIPTION
        This is an example public function that demonstrates the standard function template
        used in this module. Replace this with your actual implementation.

    .PARAMETER Name
        The name to use in the greeting. If not specified, defaults to 'World'.

    .EXAMPLE
        Get-JsmExample

        Returns a greeting with the default name.

    .EXAMPLE
        Get-JsmExample -Name 'PowerShell'

        Returns a greeting with the specified name.

    .OUTPUTS
        System.String
        Returns a greeting message.

    .NOTES
        This is an example function. Replace with your actual implementation.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name = 'World'
    )

    begin {
        Write-Verbose "Starting Get-JsmExample"
    }

    process {
        try {
            $greeting = Invoke-JsmHelper -Message "Hello, $Name!"
            Write-Output $greeting
        }
        catch {
            throw "Failed to generate greeting: $($_.Exception.Message)"
        }
    }

    end {
        Write-Verbose "Completed Get-JsmExample"
    }
}
