# User interface and product behavior

## Principles

- A local conversation manager, not a chat client or AI provider aggregator. No credentials or cloud sessions are imported.
- Flutter Material 3, system light/dark theme, lilac/purple primary accent, clean typography and minimal navigation.
- PT-BR/EN/ES based on system locale. New user-facing labels require translations in `lib/src/i18n.dart`.
- No network operations during normal use; display a local-data indicator.

## Desktop layout

At widths of 1050 px or more, use three vertical regions:

1. **Providers:** checkboxes for Claude Code, Codex and OpenCode, counts and status.
2. **Session list:** search, title/preview, source icon and last modification time. Virtualized scrolling.
3. **Conversation:** selected title, source, optional project folder, count, messages and transfer action.

At narrower widths, provider controls become chips above the session list. The list and conversation remain visible as split panes. Improve this with an adaptive single-pane flow later for very small window sizes.

## Conversation viewer

- User content right-aligned, assistant/tool content left-aligned, with clear role labels.
- Plain selectable text. Tool call arguments and results use monospace; private reasoning and image payloads are placeholders.
- Do not interpolate user text into HTML or widgets that execute scripts.
- Show read warnings (notably OpenCode WAL state) above content.
- Use lazy list construction to avoid instantiating all messages at once.

## Transfer flow

1. User selects a source conversation and presses **Copy to**.
2. Modal lists other enabled runtimes only.
3. Review modal shows source → destination, preservation notice and possible lossy blocks.
4. Only after confirmation does bridge run the upstream CLI; disable duplicate actions while it runs.
5. Success dialog offers a selectable command and a Copy button. No automatic process launch in this MVP.
6. Refresh the session list to show the new destination session.

## Future UX

- Project grouping (with consistent working-directory discovery across runtimes).
- Syntax-highlighted Markdown/code with sanitization and performance limits.
- Conversation history/diff preview before a copy, copy progress and per-block losses.
- Optional display mode that groups duplicate copies of the same conversation across providers.
- Visual analytics and statistics (using upstream `strait insights --json`).

