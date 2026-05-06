---
external help file: JsmOperations-help.xml
Module Name: JsmOperations
online version:
schema: 2.0.0
---

# Connect-JsmService

## SYNOPSIS
Establishes an in-memory connection to the JSM Cloud Operations API.

## SYNTAX

### Email (Default)
```
Connect-JsmService [-Email <String>] [-ApiToken <SecureString>] [-CloudId <String>] [-PassThru]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### Credential
```
Connect-JsmService [-Credential <PSCredential>] [-CloudId <String>] [-PassThru]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Stores connection state (email, API token, cloud ID, base URI) in a
script-scoped variable consumed by the rest of the module.
The connection
lives only for the current PowerShell session - there is no on-disk
persistence.
To skip this cmdlet on every session, see the README's
SecretManagement-based persistence recipe.

Credentials may be supplied three ways:
1.
-Credential (PSCredential where UserName is the email and Password is the API token)
2.
-Email + -ApiToken (the token as a SecureString)
3.
JSM_EMAIL / JSM_API_TOKEN / JSM_CLOUD_ID environment variables (used as fallback when the corresponding parameter is unbound - primarily for unattended/CI use)

On success, performs a smoke-test GET against /alerts?size=1 to validate
credentials.
If the smoke test fails, the connection state is cleared and
the original error rethrown.

## EXAMPLES

### EXAMPLE 1
```
$credential = Get-Credential
Connect-JsmService -Credential $credential -CloudId 'xxxx-xxxx-xxxx-xxxx'
```

Connects using a PSCredential where the user enters email + token interactively.

### EXAMPLE 2
```
Connect-JsmService
```

Connects using the JSM_EMAIL, JSM_API_TOKEN, and JSM_CLOUD_ID environment
variables.
Useful for unattended scripts and CI.

## PARAMETERS

### -Credential
A PSCredential object whose UserName is the Atlassian account email and
whose Password (SecureString) is the Atlassian API token.

```yaml
Type: PSCredential
Parameter Sets: Credential
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Email
The Atlassian account email.
Falls back to the JSM_EMAIL environment
variable when omitted.

```yaml
Type: String
Parameter Sets: Email
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ApiToken
The Atlassian API token as a SecureString.
Falls back to the JSM_API_TOKEN
environment variable when omitted.

```yaml
Type: SecureString
Parameter Sets: Email
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CloudId
The Atlassian cloud ID for the target site.
Falls back to the
JSM_CLOUD_ID environment variable when omitted.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PassThru
If specified, emits the resolved connection object (with the API token
omitted) on success.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Management.Automation.PSCustomObject
### With -PassThru, the connection object (Email, CloudId, BaseUri, ConnectedAt).
## NOTES
The API token is held as a SecureString and only decrypted inside the
private transport when constructing the Authorization header.

## RELATED LINKS
