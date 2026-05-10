---
external help file: JsmOperations-help.xml
Module Name: JsmOperations
online version:
schema: 2.0.0
---

# Get-JsmConnection

## SYNOPSIS
Returns the active JSM connection, with the API token omitted.

## SYNTAX

```
Get-JsmConnection [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Surfaces the connection state set by Connect-JsmService for inspection
and logging.
The returned object intentionally omits the ApiToken
SecureString so it is safe to pipe into Format-Table, write to logs, or
share in transcripts.
Returns $null when no connection is active.

## EXAMPLES

### EXAMPLE 1
```
Get-JsmConnection
```

Shows the active connection's email, cloud ID, base URI, and the
timestamp at which Connect-JsmService was last successful.

### EXAMPLE 2
```
if (-not (Get-JsmConnection)) { Connect-JsmService }
```

Idiom for "connect only if not already connected" inside a script.

## PARAMETERS

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
### With Email, CloudId, BaseUri, and ConnectedAt fields. $null if not connected.
## NOTES
Returns a fresh PSCustomObject - the underlying SecureString token is
never copied into the result.

## RELATED LINKS
