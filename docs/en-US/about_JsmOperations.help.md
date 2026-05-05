# JsmOperations

## about_JsmOperations

## SHORT DESCRIPTION
PowerShell cmdlets for managing alerts in Atlassian Jira Service Management
(JSM) Cloud Operations.

## LONG DESCRIPTION
JsmOperations targets the JSM Cloud canonical Operations API at
`https://api.atlassian.com/jsm/ops/api/{cloudId}/v1`.

Authentication is Atlassian email + API token (HTTP Basic). The token is
held as a SecureString in script scope and only decrypted inside the
private transport when constructing the Authorization header. Connection
state lives only for the current PowerShell session — there is no on-disk
persistence baked into the module. To skip `Connect-JsmService` on every
new session, see the README's Microsoft.PowerShell.SecretManagement-based
persistence recipe.

v0.1.0 covers the alert read / acknowledge / close path:

- `Connect-JsmService`, `Disconnect-JsmService`, `Get-JsmConnection`
- `Get-JsmAlert` (list with Lucene query, or fetch by id; pipeline-friendly)
- `Confirm-JsmAlert`, `Close-JsmAlert` (both accept an optional note;
  pipeline-friendly)

Cmdlets return the deserialized JSON from the API without reshaping.

## EXAMPLES
Connect, acknowledge an open P1, then close it:

```powershell
$cred = Get-Credential  # UserName = email, Password = API token
Connect-JsmService -Credential $cred -CloudId 'xxxx-xxxx-xxxx-xxxx'

Get-JsmAlert -Query 'status:open AND priority:P1' -Limit 1 |
    Confirm-JsmAlert -Note 'On it'

Get-JsmAlert -Query 'status:open AND priority:P1' -Limit 1 |
    Close-JsmAlert -Note 'Resolved by oncall script'

Disconnect-JsmService
```

For unattended/CI use, set `JSM_EMAIL`, `JSM_API_TOKEN`, and `JSM_CLOUD_ID`
and call `Connect-JsmService` with no parameters.

## NOTE
- Acknowledge and close are asynchronous server-side. The cmdlets return
  the request-status object, not the updated alert; re-fetch with
  `Get-JsmAlert -Id` to confirm the new state.
- `Connect-JsmService` smoke-tests credentials with `GET /alerts?size=1`
  and clears connection state on failure.

## TROUBLESHOOTING NOTE
- **401 on `Connect-JsmService`**: invalid email/token combination, or the
  token has been revoked. Generate a fresh token at
  https://id.atlassian.com/manage-profile/security/api-tokens.
- **404 on alert operations**: verify the `-CloudId` matches the site that
  owns the alert. The same alert id is not valid across cloud sites.
- **"No active JSM connection"**: `Connect-JsmService` was not called, or
  `Disconnect-JsmService` cleared the state. Reconnect.

## SEE ALSO
- Atlassian JSM Cloud Operations API: https://developer.atlassian.com/cloud/jira/service-desk-ops/rest/
- `Microsoft.PowerShell.SecretManagement`: https://learn.microsoft.com/en-us/powershell/utility-modules/secretmanagement/overview

## KEYWORDS
- JSM
- Jira Service Management
- Atlassian
- Operations
- Alerts
- Acknowledge
- Close
