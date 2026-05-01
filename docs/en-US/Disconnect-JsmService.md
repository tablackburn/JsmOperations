---
external help file: JsmOperations-help.xml
Module Name: JsmOperations
online version:
schema: 2.0.0
---

# Disconnect-JsmService

## SYNOPSIS
Clears the in-memory JSM connection.

## SYNTAX

```
Disconnect-JsmService [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Removes the connection state set by Connect-JsmService from the module's
script scope.
Idempotent - calling without an active connection is not
an error.
Subsequent JsmOperations cmdlets will throw a "no active
connection" error until Connect-JsmService is called again.

## EXAMPLES

### EXAMPLE 1
```
Disconnect-JsmService
```

Clears the active connection.
The next call to Get-JsmAlert (or any
other cmdlet that hits the API) will throw.

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

### None.
## NOTES
Useful at the end of automation scripts or before switching between sites
in the same session.

## RELATED LINKS
