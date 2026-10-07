# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-10-07

### Added

- `-IdentifierType` parameter (`id`, `tiny`, `alias`; default `id`) on `Get-JsmAlert -Id`, `Close-JsmAlert`, and `Confirm-JsmAlert`. A tinyId (the number shown in the JSM UI) or an integration alias is resolved to the alert UUID before the API call, because the JSM Cloud API only addresses alerts by UUID ([#35](https://github.com/tablackburn/JsmOperations/issues/35)).
  - Aliases resolve for closed alerts too: when the `/alerts/alias` endpoint (open alerts only) returns 404, the lookup falls back to an `alias:` search.
  - tinyIds are reused over time and aliases are only unique among open alerts. When several alerts match, the single non-closed alert is used; otherwise the most recently created is used and a warning names it. Pass the UUID to target a specific alert.

### Fixed

- Passing a tinyId to `Get-JsmAlert -Id`, `Close-JsmAlert`, or `Confirm-JsmAlert` returned 404 even though the help described `-Id` as accepting a tinyId. Use `-IdentifierType tiny` ([#35](https://github.com/tablackburn/JsmOperations/issues/35)).

## [0.1.0] - 2026-05-01

### Added

- Initial release. JSM Cloud canonical backend; alerts list / get / acknowledge / close.
- `Connect-JsmService` - establish in-memory connection (no on-disk persistence; see README for SecretManagement-based persistence).
- `Disconnect-JsmService` - clear the active connection.
- `Get-JsmConnection` - inspect the active connection (API token omitted).
- `Get-JsmAlert` - list alerts (with optional Lucene query, sort, page size) or fetch one by id.
- `Confirm-JsmAlert` - acknowledge an alert.
- `Close-JsmAlert` - close an alert.

[Unreleased]: https://github.com/tablackburn/JsmOperations/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/tablackburn/JsmOperations/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/tablackburn/JsmOperations/releases/tag/v0.1.0
