# Security and data-integrity policy

## Privacy boundary

- Session files may contain prompts, tool arguments, credentials, environment variables and proprietary code. Never upload them, include them in logs, write them to issues or report analytics from them.
- The GUI and bridge are offline-first. Do not add cloud APIs, auto-update downloads or telemetry without explicit owner approval.
- No browser HTML injection: render conversation text as plain selectable text. Keep Markdown rendering out of scope until appropriately sanitized.
- Do not send private reasoning or embedded images through the bridge JSON protocol; use placeholders.

## Safe conversions

1. Always request a specific known source session by ID; do not accept an arbitrary path.
2. Validate source and destination against `claude`, `codex`, `opencode` and require distinct runtimes.
3. Show a review dialog explaining that original content is preserved and that some blocks may be dropped.
4. Invoke only `strait sync <from> <to> --session <id>` without shell interpolation or the dangerous `--force` switch.
5. Do not start a second conversion while the first is running from the GUI.
6. For OpenCode targets, abort when `opencode.db-wal` exists and is nonempty. Require `sqlite3` CLI because upstream's integrity and lock safety checks can degrade when it is missing.
7. Never delete sessions, databases, WAL/SHM files, user configuration, or conversion history.
8. Never claim a conversion is reversible or lossless. Recommend backups prior to the first real migration and before format changes.

Upstream Strait is alpha and the emitter's SQLite handling may change. Before relaxing any safeguards, review current emitter code and test against a throwaway database (only with owner authorization).

## Error handling

- Failed subprocess status must be shown to the user; do not fake target IDs or launch commands.
- Keep stdout structured; stderr is diagnostic only. The bridge caps subprocess output size and execution time.
- If the bridge cannot locate Node.js, Strait, an agent file, or SQLite dependencies, show an actionable error.
- Protect private data from accidental clipboard operations: only copy the generated resume command when requested.

## Current limitations

- The visualizer uses `sql.js` on a copy of the main SQLite file and may not observe active WAL pages. It warns if a nonempty WAL exists.
- `sqlite3` availability does not guarantee no active database writer. The app's WAL check is an extra guard, **not** a complete concurrency lock guarantee. For safety, close OpenCode before copying into it.
- The app does not yet create its own automatic backup of OpenCode's database. This is required before shipping production-grade migration features.
- The bridge resolves common global npm `strait-cli/dist/index.js` locations through Node to avoid executing `.cmd` shims. Nonstandard Windows npm installations require manual configuration and validation.

