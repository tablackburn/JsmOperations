---
external help file: JsmOperations-help.xml
Module Name: JsmOperations
online version:
schema: 2.0.0
---

# Get-JsmAlert

## SYNOPSIS
Retrieves alerts from the JSM Cloud Operations API.

## SYNTAX

### List (Default)
```
Get-JsmAlert [-Query <String>] [-Limit <Int32>] [-OrderBy <String>] [-Order <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### ById
```
Get-JsmAlert -Id <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Two modes of operation, selected by parameter set:
- List (default): GET /v1/alerts with optional Lucene query, sort, and
  page size.
Returns the .values payload from the response envelope.
- ById: GET /v1/alerts/{id} for a single alert.
Accepts the id from the
  pipeline (by value or by property name), so you can chain from list
  output: Get-JsmAlert -Query 'status:open' | Get-JsmAlert.

v0.1.0 returns the raw deserialized JSON.
No reshaping or type accelerator.

## EXAMPLES

### EXAMPLE 1
```
Get-JsmAlert -Limit 5
```

Returns the five most recently updated alerts.

### EXAMPLE 2
```
Get-JsmAlert -Query 'status:open AND priority:P1' -Limit 50
```

Returns up to 50 open P1 alerts.

### EXAMPLE 3
```
Get-JsmAlert -Id 'abc-123-...'
```

Returns the detail object for a single alert.

## PARAMETERS

### -Id
The alert id (UUID or tinyId).
Accepts pipeline input by value and by
property name.

```yaml
Type: String
Parameter Sets: ById
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -Query
A Lucene query string (e.g.
'status:open AND priority:P1').
See the
Atlassian JSM Operations API docs for syntax.

```yaml
Type: String
Parameter Sets: List
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Limit
Maximum number of alerts to return.
Maps to the API's 'size' parameter.
Default 20.

```yaml
Type: Int32
Parameter Sets: List
Aliases:

Required: False
Position: Named
Default value: 20
Accept pipeline input: False
Accept wildcard characters: False
```

### -OrderBy
Field to sort by.
Default 'updatedAt'.

```yaml
Type: String
Parameter Sets: List
Aliases:

Required: False
Position: Named
Default value: UpdatedAt
Accept pipeline input: False
Accept wildcard characters: False
```

### -Order
Sort direction.
'asc' or 'desc'.
Default 'desc'.

```yaml
Type: String
Parameter Sets: List
Aliases:

Required: False
Position: Named
Default value: Desc
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
### Raw alert objects as deserialized from the API JSON.
## NOTES
The List set returns the response.values array; the ById set returns the
response object directly.

## RELATED LINKS
