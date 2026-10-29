# StraitUI — Agent Instructions

## Mission

Build a lightweight, offline-first desktop GUI for local AI agent session portability. Flutter owns presentation; the Node bridge reads local session data and invokes **the upstream Strait CLI** for conversions. Supported agents in the current MVP are Claude Code, Codex and OpenCode.

## Read before acting

1. `README.md`: setup, features and known limitations.
2. `.agents/architecture.md`: process boundaries and RPC contract.
3. `.agents/security.md`: data safety, SQLite WAL and subprocess policies.
4. `.agents/ui.md`: UX and localization requirements.
5. `.agents/roadmap.md`: implementation stages and pending compatibility work.

## Development rules

- Prefer small, reusable code and simple dependencies. No Electron or remote backend.
- Keep Flutter as the UI stack; do not rewrite the project in another framework without explicit approval.
- Keep Node.js as a local stdio sidecar. Do not expose HTTP listeners, sockets or cloud telemetry.
- Use Strait for all native session **conversions**. Do not manually edit another agent's session storage in Flutter or invent a replacement converter.
- The bridge viewer may normalize **read-only** content but must never display raw private chain-of-thought or embed base64 image data in RPC responses.
- Preserve user data and original sessions. Never remove a session or invoke `strait sync --force`.
- Before writing to OpenCode's SQLite storage, enforce the safeguards described in `.agents/security.md`.
- Use structured JSON RPC over stdin/stdout; keep stdout reserved for machine-readable responses. Diagnostics go to stderr.
- Pass external command arguments as arrays without shell expansion; validate runtime identifiers and session identifiers.
- English for code identifiers, API fields and comments. UI strings must be available in PT-BR, EN and ES; do not hardcode visible labels outside localization.
- Follow OS light/dark appearance. Design for smaller desktop windows as well as wide displays.
- Keep current repository changes intact; do not overwrite unrelated work. Favor incremental, reviewable commits.

## Issue-centered workflow

- Open a dedicated GitHub issue for each new feature, bug, technical improvement or documentation demand before implementation whenever GitHub access is available.
- Break multi-phase tasks into subtasks/subissues when supported by GitHub; describe dependencies and acceptance criteria.
- Keep relevant design decisions, progress, blockers, compatibility observations and manual test results in the corresponding issue.
- Refer to issue IDs in related commits and PRs when available.
- Prioritize safety and feature completeness over speculative optimizations.

## Validation / handoff

- Manual verification is performed by the project owner unless tests are explicitly requested. Never state that a build, OS integration or conversion was tested unless it actually ran.
- When adding a provider or changing SQLite handling, specify expected formats and OS paths, and include a manual test checklist in the issue.
- Do not write sample real chats, secrets, tokens, private paths or user content to the repository.
- Document any integration limitation or unverified operating system in the README and roadmap.

