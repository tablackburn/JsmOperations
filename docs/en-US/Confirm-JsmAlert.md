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
Confirm-JsmAlert [-Id] <String> [[-Note] <String>] [[-IdentifierType] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Sends POST /v1/alerts/{id}/acknowledge.
A tinyId or alias given with
-IdentifierType is first resolved to the alert UUID.
The acknowledge
operation is asynchronous on the server side, so the response is a
request-status object rather than the updated alert.
Pass -Verbose to
see the request URL.

Pipeline-friendly: pipe alerts (or their ids) directly in.

## EXAMPLES

### EXAMPLE 1
```
Confirm-JsmAlert -Id 'abc-123-...'
```

Acknowledges a single alert.

### EXAMPLE 2
```
Confirm-JsmAlert -Id 623551 -IdentifierType tiny
```

Acknowledges the alert whose tinyId (the number shown in the JSM UI) is
623551.

### EXAMPLE 3
```
Get-JsmAlert -Query 'status:open AND priority:P5' | Confirm-JsmAlert -Note 'Bulk-acked low-priority'
```

Acknowledges all open P5 alerts with an explanatory note.

## PARAMETERS

### -Id
The alert identifier.
Interpreted as the alert UUID by default; pass
-IdentifierType tiny for the short numeric tinyId shown in the JSM UI, or
-IdentifierType alias for an integration alias.
Accepts pipeline input by
value and by property name.

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

### -IdentifierType
How to interpret -Id: 'id' (alert UUID, the default), 'tiny' (tinyId), or
'alias' (integration alias).
The JSM Cloud API only addresses alerts by
UUID, so 'tiny' and 'alias' cost one extra lookup call.
tinyIds are
reused over time; if several alerts share one, the single non-closed
alert is used, otherwise the most recently created (with a warning).
Piped alert objects bind their id (UUID) property, so leave the default
when piping.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: Id
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
