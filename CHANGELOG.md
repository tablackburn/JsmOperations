# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- `Get-JsmAlert -Id`, `Close-JsmAlert`, and `Confirm-JsmAlert` returned 404 when given an alert tinyId, because the JSM Cloud API only addresses alerts by UUID. They now accept `-IdentifierType` (`id`, `tiny`, `alias`; default `id`) and resolve a tinyId or alias to the alert UUID before calling the API ([#35](https://github.com/tablackburn/JsmOperations/issues/35)). tinyIds are reused over time: when several alerts share one, the single non-closed alert is used, otherwise the most recently created (with a warning).

## [0.1.0] - 2026-05-01

### Added

- Initial release. JSM Cloud canonical backend; alerts list / get / acknowledge / close.
- `Connect-JsmService` - establish in-memory connection (no on-disk persistence; see README for SecretManagement-based persistence).
- `Disconnect-JsmService` - clear the active connection.
- `Get-JsmConnection` - inspect the active connection (API token omitted).
- `Get-JsmAlert` - list alerts (with optional Lucene query, sort, page size) or fetch one by id.
- `Confirm-JsmAlert` - acknowledge an alert.
- `Close-JsmAlert` - close an alert.
