function Connect-JsmService {
    <#
    .SYNOPSIS
        Establishes an in-memory connection to the JSM Cloud Operations API.

    .DESCRIPTION
        Stores connection state (email, API token, cloud ID, base URI) in a
        script-scoped variable consumed by the rest of the module. The connection
        lives only for the current PowerShell session - there is no on-disk
        persistence. To skip this cmdlet on every session, see the README's
        SecretManagement-based persistence recipe.

        Credentials may be supplied three ways:
        1. -Credential (PSCredential where UserName is the email and Password is the API token)
        2. -Email + -ApiToken (the token as a SecureString)
        3. JSM_EMAIL / JSM_API_TOKEN / JSM_CLOUD_ID environment variables (used as fallback when the corresponding parameter is unbound, primarily for unattended/CI use)

        On success, performs a smoke-test GET against /alerts?size=1 to validate
        credentials. If the smoke test fails, the connection state is cleared and
        the original error rethrown.

    .PARAMETER Credential
        A PSCredential object whose UserName is the Atlassian account email and
        whose Password (SecureString) is the Atlassian API token.

    .PARAMETER Email
        The Atlassian account email. Falls back to the JSM_EMAIL environment
        variable when omitted.

    .PARAMETER ApiToken
        The Atlassian API token as a SecureString. Falls back to the JSM_API_TOKEN
        environment variable when omitted.

    .PARAMETER CloudId
        The Atlassian cloud ID for the target site. Falls back to the
        JSM_CLOUD_ID environment variable when omitted.

    .PARAMETER PassThru
        If specified, emits the resolved connection object (with the API token
        omitted) on success.

    .EXAMPLE
        $cred = Get-Credential
        Connect-JsmService -Credential $cred -CloudId 'xxxx-xxxx-xxxx-xxxx'

        Connects using a PSCredential where the user enters email + token interactively.

    .EXAMPLE
        Connect-JsmService

        Connects using the JSM_EMAIL, JSM_API_TOKEN, and JSM_CLOUD_ID environment
        variables. Useful for unattended scripts and CI.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
        With -PassThru, the connection object (Email, CloudId, BaseUri, ConnectedAt).

    .NOTES
        The API token is held as a SecureString and only decrypted inside the
        private transport when constructing the Authorization header.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        '',
        Justification = 'Plaintext source is JSM_API_TOKEN env var - intentional fallback for unattended/CI scenarios where the host secret store provisions the env var.'
    )]
    [CmdletBinding(DefaultParameterSetName = 'Email')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(ParameterSetName = 'Credential')]
        [ValidateNotNull()]
        [pscredential]
        $Credential,

        [Parameter(ParameterSetName = 'Email')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Email,

        [Parameter(ParameterSetName = 'Email')]
        [ValidateNotNull()]
        [securestring]
        $ApiToken,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $CloudId,

        [Parameter()]
        [switch]
        $PassThru
    )

    begin {
        Write-Verbose -Message 'Starting Connect-JsmService'
    }

    process {
        try {
            if ($PSCmdlet.ParameterSetName -eq 'Credential') {
                $resolvedEmail = $Credential.UserName
                $resolvedToken = $Credential.Password
            }
            else {
                if ($PSBoundParameters.ContainsKey('Email')) {
                    $resolvedEmail = $Email
                }
                else {
                    $resolvedEmail = $env:JSM_EMAIL
                }

                if ($PSBoundParameters.ContainsKey('ApiToken')) {
                    $resolvedToken = $ApiToken
                }
                elseif (-not [string]::IsNullOrWhiteSpace($env:JSM_API_TOKEN)) {
                    $resolvedToken = ConvertTo-SecureString -String $env:JSM_API_TOKEN -AsPlainText -Force
                }
                else {
                    $resolvedToken = $null
                }
            }

            if ($PSBoundParameters.ContainsKey('CloudId')) {
                $resolvedCloudId = $CloudId
            }
            else {
                $resolvedCloudId = $env:JSM_CLOUD_ID
            }

            if ([string]::IsNullOrWhiteSpace($resolvedEmail)) {
                throw 'Email is required. Pass -Email, pass -Credential, or set the JSM_EMAIL environment variable.'
            }
            if ($null -eq $resolvedToken) {
                throw 'API token is required. Pass -ApiToken, pass -Credential, or set the JSM_API_TOKEN environment variable.'
            }
            if ([string]::IsNullOrWhiteSpace($resolvedCloudId)) {
                throw 'CloudId is required. Pass -CloudId or set the JSM_CLOUD_ID environment variable.'
            }

            $script:JsmConnection = [pscustomobject]@{
                Email       = $resolvedEmail
                ApiToken    = $resolvedToken
                CloudId     = $resolvedCloudId
                BaseUri     = "https://api.atlassian.com/jsm/ops/api/$resolvedCloudId/v1"
                ConnectedAt = [datetime]::UtcNow
            }

            try {
                $null = Invoke-JsmApi -Method 'Get' -Path '/alerts' -Query @{ size = 1 }
            }
            catch {
                $script:JsmConnection = $null
                throw
            }

            if ($PassThru) {
                Write-Output (Get-JsmConnection)
            }
        }
        catch {
            throw
        }
    }

    end {
        Write-Verbose -Message 'Completed Connect-JsmService'
    }
}
