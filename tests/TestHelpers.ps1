function New-TestToken {
    <#
    .SYNOPSIS
        Returns a fresh random string for use as a throwaway test credential.

    .DESCRIPTION
        Test fixtures only. Generates a new value per call so no token literal is
        ever committed to source. That keeps PSScriptAnalyzer and GitGuardian's
        "ConvertTo-SecureString Password" detector quiet and avoids hard-coded
        "secrets" in the test suite. The contents are never asserted on; tests
        only need *a* token, not a specific one.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    [guid]::NewGuid().ToString('N')
}

function New-TestSecureString {
    <#
    .SYNOPSIS
        Builds a SecureString without going through ConvertTo-SecureString
        -AsPlainText. Uses a random value when -Value is omitted.

    .DESCRIPTION
        Test fixtures only. PSScriptAnalyzer's PSAvoidUsingConvertToSecureStringWithPlainText
        rule and GitGuardian's "ConvertTo-SecureString Password" detector both
        flag any literal passed to ConvertTo-SecureString -AsPlainText as a
        likely-credential leak. Tests legitimately need to construct a
        SecureString; this helper does that via SecureString.AppendChar so
        neither scanner false-positives. Omit -Value to get a random token
        (preferred when the contents are irrelevant to the assertion); pass
        -Value only when a test depends on the exact characters.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Random')]
    [OutputType([securestring])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Value')]
        [AllowEmptyString()]
        [string]
        $Value
    )

    if ($PSCmdlet.ParameterSetName -eq 'Random') {
        $Value = New-TestToken
    }

    $secure = [System.Security.SecureString]::new()
    foreach ($char in $Value.ToCharArray()) { $secure.AppendChar($char) }
    $secure.MakeReadOnly()
    $secure
}
