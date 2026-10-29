# Implementation roadmap

These stages define follow-up work. Dates should only be added once the owner confirms scope and capacity.

## Phase 0 — Repository and architecture

- [x] Flutter UI source, minimal Node.js bridge and package metadata.
- [x] Repo README, AGENTS.md and architecture/security/UI documentation.
- [x] Plain-text viewer for Claude Code, Codex and OpenCode.
- [x] Bidirectional transfer via upstream Strait CLI, with review dialog.
- [x] Simple PT-BR/EN/ES localization and system theme.
- [ ] Generate and commit native Flutter Linux/Windows/macOS scaffolds using Flutter SDK.
- [ ] Owner manual compilation and smoke test on Fedora (no unit tests requested).

## Phase 1 — Reliability and compatibility

- [ ] Review actual session formats against recent Claude Code/Codex/OpenCode releases; handle deltas and unusual records gracefully.
- [ ] Confirm OpenCode database paths for Linux, Windows and macOS; handle nonstandard installations.
- [ ] Manually verify Windows npm script resolution (implemented for common prefixes, custom installs may need `STRAIT_UI_STRAIT_BIN`).
- [ ] Detect active OpenCode writer, create and verify a recoverable backup, and prevent unsafe concurrent writes.
- [ ] Improve large-session parsing to streaming and incremental pagination; do not load entire JSONL files in RAM.
- [ ] Parse source project directory/title in list metadata and group sessions by project.
- [ ] Provide complete conversion warnings and per-block loss reports from upstream Strait.
- [ ] Native cross-platform bridge/runtime packaging without requiring external Node/npm/Strait setup.
- [ ] Owner manual verification of all six conversion paths with disposable sessions and backup recovery.

## Phase 2 — Experience

- [ ] Markdown and syntax-highlighted code blocks (sanitized, no executable HTML).
- [ ] Project filter/grouping and provider history visualization.
- [ ] Copy history and preview comparison between original and imported session.
- [ ] Open/resume session in an installed terminal (with explicit user action).
- [ ] Strait offline statistics dashboard via `insights --json`.
- [ ] More robust adaptive mobile-sized desktop windows and keyboard shortcuts.

## Phase 3 — Distribution

- [ ] Linux AppImage and RPM (optional DEB), Windows installer, macOS DMG.
- [ ] CI builds and checks; do not require unit tests without owner approval.
- [ ] Supply-chain pinning of Strait versions, notices for MIT dependencies and hash verification.
- [ ] Release instructions and first-run diagnostics.

## Decision log

- **2026-10-28**: Flutter chosen as cross-platform GUI; no Electron or hosted backend.
- **2026-10-28**: Node sidecar chosen because upstream Strait is TypeScript/Node and has no public conversation JSON API.
- **2026-10-28**: SQLite operations owned by upstream Strait; GUI viewer is read-only and transfer to OpenCode has conservative guards.
- **2026-10-28**: Initial implementation requested without unit tests; owner will compile and test locally.

