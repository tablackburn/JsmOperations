# JsmOperations

PowerShell module for the Atlassian Jira Service Management (JSM) Operations REST API (formerly Opsgenie) - manage alerts, on-call schedules, and teams from PowerShell.

## Installation

### From PowerShell Gallery

```powershell
Install-Module -Name JsmOperations -Scope CurrentUser
```

### From Source

```powershell
git clone https://github.com/tablackburn/JsmOperations.git
cd JsmOperations
./build.ps1 -Task Build -Bootstrap
Import-Module ./Output/JsmOperations/*/JsmOperations.psd1
```

## Requirements

- PowerShell 5.1 or later (Desktop or Core)
- Windows, Linux, or macOS

## Quick Start

JsmOperations targets the JSM Cloud canonical Operations API at
`https://api.atlassian.com/jsm/ops/api/{cloudId}/v1`. Authentication is HTTP
Basic with your Atlassian email + an API token from
<https://id.atlassian.com/manage-profile/security/api-tokens>. Find your
`cloudId` at `https://<your-site>.atlassian.net/_edge/tenant_info`.

Connection state is **in-memory and per-session** — there is no on-disk
persistence built into the module. Three usage modes are supported:

### 1. Interactive

```powershell
Import-Module JsmOperations

$cred = Get-Credential   # UserName = email, Password = API token
Connect-JsmService -Credential $cred -CloudId 'xxxx-xxxx-xxxx-xxxx'

Get-JsmAlert -Limit 5
Get-JsmAlert -Query 'status:open AND priority:P1' | Confirm-JsmAlert -Note 'investigating'
```

### 2. Persistent (recommended for daily use)

Wire `Connect-JsmService` into your `$PROFILE` via
[Microsoft.PowerShell.SecretManagement](https://learn.microsoft.com/en-us/powershell/utility-modules/secretmanagement/overview)
so you only enter the token once per machine:

```powershell
# One-time setup:
Install-Module Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore
Register-SecretVault -Name JsmVault -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
Set-Secret -Name JsmApiToken -Secret (Read-Host -AsSecureString)

# Add to $PROFILE:
Connect-JsmService -Email 'me@example.com' -ApiToken (Get-Secret JsmApiToken) -CloudId 'xxxx-xxxx-xxxx-xxxx'
```

SecretStore is cross-platform (Windows / Linux / macOS) and uses .NET crypto APIs
to protect the vault on disk.

### 3. Unattended / CI

When the corresponding parameter is omitted, `Connect-JsmService` falls back to
environment variables:

```powershell
$env:JSM_EMAIL     = 'me@example.com'
$env:JSM_API_TOKEN = '...'
$env:JSM_CLOUD_ID  = 'xxxx-xxxx-xxxx-xxxx'

Connect-JsmService    # picks up all three from env
```

## Available Commands

| Command | Description |
|---------|-------------|
| `Connect-JsmService` | Establish an in-memory connection. |
| `Disconnect-JsmService` | Clear the active connection. |
| `Get-JsmConnection` | Inspect the active connection (token omitted). |
| `Get-JsmAlert` | List alerts (with `-Query` / `-Limit` / `-OrderBy`) or fetch one by `-Id`. |
| `Confirm-JsmAlert` | Acknowledge an alert (optionally with a `-Note`). |
| `Close-JsmAlert` | Close an alert (optionally with a `-Note`). |

## Development

### Prerequisites

- PowerShell 5.1+ or PowerShell 7+
- Git

### Building

```powershell
# Clone the repository
git clone https://github.com/tablackburn/JsmOperations.git
cd JsmOperations

# Bootstrap dependencies and build
./build.ps1 -Task Build -Bootstrap

# Run tests
./build.ps1 -Task Test
```

### Project Structure

```text
JsmOperations/
├── JsmOperations/           # Module source
│   ├── Public/               # Exported functions
│   └── Private/              # Internal helpers
├── tests/                    # Pester tests
│   ├── Unit/                 # Unit tests
│   ├── Meta.tests.ps1        # Code style tests
│   ├── Manifest.tests.ps1    # Manifest validation
│   └── Help.tests.ps1        # Help documentation tests
├── docs/                     # Documentation
├── .github/workflows/        # CI/CD pipelines
└── build.ps1                 # Build entry point
```

### Available Build Tasks

```powershell
./build.ps1 -Help
```

| Task | Description |
|------|-------------|
| `Build` | Build the module to Output/ |
| `Test` | Run all tests with code coverage |
| `Analyze` | Run PSScriptAnalyzer |
| `Pester` | Run Pester tests only |
| `Clean` | Remove build artifacts |
| `Publish` | Publish to PowerShell Gallery |

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `./build.ps1 -Task Test`
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.
