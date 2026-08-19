---
applyTo: '**/*'
description: 'Repository-specific instructions for JsmOperations'
---

# JsmOperations Repository Instructions

This file contains instructions specific to the JsmOperations PowerShell module. These
instructions supplement the standard AIM modules and take precedence for repository-specific
conventions.

## Project Overview

PowerShell module for the Atlassian Jira Service Management (JSM) Operations REST API (formerly Opsgenie) - manage alerts, on-call schedules, and teams from PowerShell.

The repository follows the standard conventions of this module fleet:

- Module structure (Public and Private function separation)
- Build automation (psake and PowerShellBuild)
- Testing (Pester - `build.depend.psd1` names the version the build resolves)
- Continuous integration and delivery (GitHub Actions)

## Module Structure

```text
JsmOperations/
├── JsmOperations/
│   ├── Public/           # Exported cmdlets (user-facing functions)
│   ├── Private/          # Internal helper functions
│   ├── JsmOperations.psd1   # Module manifest
│   └── JsmOperations.psm1   # Module loader
├── tests/                # Pester tests
│   ├── Unit/Public/      # Tests for public functions
│   ├── Unit/Private/     # Tests for private functions
│   └── *.tests.ps1       # Meta, Manifest, Help tests
├── instructions/         # AI agent instructions (AIM)
├── build.ps1             # Build entry point
└── build.psake.ps1       # psake build tasks
```

### Key Files

| File                               | Purpose                              |
| ---------------------------------- | ------------------------------------ |
| `build.ps1`                        | Entry point for all build operations |
| `build.psake.ps1`                  | psake task definitions               |
| `build.depend.psd1`                | PSDepend build dependency versions   |
| `JsmOperations/JsmOperations.psd1` | Module manifest                      |
| `JsmOperations/JsmOperations.psm1` | Module root file                     |
| `tests/`                           | Pester test suite                    |

## Naming Conventions

### Function Prefix

All public cmdlets use the `Jsm` prefix:

- `Get-JsmExample`

### Private Function Naming

Private functions also use the `Jsm` prefix but are not exported:

- `Invoke-JsmHelper`

## Code Style

- Include full comment-based help with `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, and `.EXAMPLE`
- Use `[CmdletBinding()]` on all functions
- Follow the PSScriptAnalyzer rules configured in `PSScriptAnalyzerSettings.psd1`

## Adding a New Function

1. Create the function file in `JsmOperations/Public/` or `JsmOperations/Private/`
2. Add the function name to `FunctionsToExport` in the module manifest (public functions only)
3. Create the corresponding test file in `tests/Unit/Public/` or `tests/Unit/Private/`

## Testing Requirements

### Pester Tests

- All public functions must have corresponding tests in `tests/Unit/Public/`
- All private functions should have tests in `tests/Unit/Private/`
- Mock external dependencies - never make real HTTP requests in tests
- Write tests for the Pester major version the build resolves, currently Pester 6 (`BeforeAll`,
  `BeforeDiscovery`, and so on). `build.depend.psd1` sets `Version = 'latest'` rather than a
  pinned version, so the build floats onto the newest release and can cross a major boundary;
  the `UnitTest` task in `build.psake.ps1` reads that same value, so the installed and imported
  versions agree. Treat `build.depend.psd1` as the source of truth, not this sentence

### Running Tests

```powershell
# Run all tests
./build.ps1 -Task Test

# Run specific tests
Invoke-Pester -Path ./tests/Unit/Public/Get-JsmExample.tests.ps1
```

## Build Process

The module uses psake for build automation:

```powershell
# Bootstrap and build
./build.ps1 -Task Build -Bootstrap

# Run specific tasks
./build.ps1 -Task Test
./build.ps1 -Task Analyze
```

## Dependencies

- PowerShell 5.1 or higher (PowerShell 7+ recommended)
- No external module dependencies for runtime
- Pester (for testing; `build.depend.psd1` sets `Version = 'latest'`)
- psake (for build automation)

## Release Process

1. Update version in `JsmOperations/JsmOperations.psd1`
2. Update `CHANGELOG.md` with new version section
3. Commit changes with message: `chore: Bump version to X.Y.Z`
4. Push to main branch
5. CI will automatically publish to PowerShell Gallery when version changes
