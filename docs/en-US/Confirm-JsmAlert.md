---
external help file: JsmOperations-help.xml
Module Name: JsmOperations
online version:
schema: 2.0.0
---

# Confirm-JsmAlert

## SYNOPSIS
Acknowledges an alert in JSM Cloud Operations.

## SYNTAX

```
Confirm-JsmAlert [-Id] <String> [[-Note] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Sends POST /v1/alerts/{id}/acknowledge.
The acknowledge operation is
asynchronous on the server side, so the response is a request-status
object rather than the updated alert.
Pass -Verbose to see the request
URL.

Pipeline-friendly: pipe alerts (or their ids) directly in.

## EXAMPLES

### EXAMPLE 1
```
Confirm-JsmAlert -Id 'abc-123-...'
```

Acknowledges a single alert.

### EXAMPLE 2
```
Get-JsmAlert -Query 'status:open AND priority:P5' | Confirm-JsmAlert -Note 'Bulk-acked low-priority'
```

Acknowledges all open P5 alerts with an explanatory note.

## PARAMETERS

### -Id
The alert id (UUID or tinyId).
Accepts pipeline input by value and by
property name.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -Note
An optional note attached to the acknowledge action.
Visible in the
alert's activity log.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
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
### The asynchronous request-status object returned by the API.
## NOTES
Acknowledgement is async: the alert's status field will not update
immediately.
Re-fetch with Get-JsmAlert -Id to confirm.

## RELATED LINKS
