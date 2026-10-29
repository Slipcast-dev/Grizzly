# Architecture

Grizzly is two implementations of one design: a native macOS app and an Electron port for Windows. They share the
translation tables and file-type rules, not code.

```
Sources/Grizzly/          macOS app (SwiftUI, ~2.8k lines)
  App/        AppState, Settings, Theme, entry point and menu commands
  Core/       Document model, file loading/encodings, Markdown parser, CSV, syntax coloring, search
  Features/   Tab bar, panes, source view, editor, find bar, sidebar, settings
  Render/     Markdown and CSV table views
  Library/    Virtual library (folders / favorites) and the open history, persisted as JSON
QuickLook/    Quick Look preview extension (.appex): HTML rendering of Markdown, CSV, YAML and logs;
              reuses Core/FileLoader, FileType, CSVTable and MarkdownParser
resources/    App icon and Localizable.strings (ru, en)
electron/     Windows port
  main.js       Main process: window, menu, file I/O, single-instance handoff, portable data dir
  preload.js    Narrow bridge exposed to the renderer (contextIsolation)
  renderer/     UI in plain JS/CSS: state, core (parsers), ui
scripts/      build-app.sh, make-dmg.sh, test.sh
tests/        Swift test (swiftc) and JS tests (node --test); VERSION is the single source of the version
samples/      One file of each supported type for manual testing
```

## Data flow

1. A file URL arrives (open panel, drag and drop, command line).
2. `FileLoader` decodes it — UTF-8, UTF-8 BOM, UTF-16 BOM, then Windows-1251 and ISO-8859-1 as fallbacks — and remembers
   the encoding so that saving round-trips.
3. `FileType` maps the extension to a type; `Document` builds the representation (Markdown blocks, CSV table, or
   syntax-colored lines).
4. Panes render the document in the selected mode; `Search` produces matches that panes highlight.
5. A file watcher flags on-disk changes; the pane shows a reload banner and never overwrites unsaved edits silently.

## Security model

- No network code exists in either app. There is no telemetry or auto-update.
- HTML files are displayed as source, never rendered or executed.
- Electron renderer: `sandbox: true`, `contextIsolation: true`, `nodeIntegration: false`, and a
  Content-Security-Policy of `default-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:`.
  File access happens in the main process through the preload bridge.
- The Electron main process answers file IPC only to the app's own page and only for absolute paths with supported extensions.
- Quick Look HTML escapes quotes and makes only `http`, `https` and `mailto` links clickable.
- The library stores references (paths) only; it never modifies the files it points to.
- Release builds are unsigned/ad-hoc signed; integrity is established with published SHA-256 checksums.

## Localization

`resources/{ru,en}.lproj/Localizable.strings` hold the UI strings. Russian keys double as source text; the Electron
port derives `strings-en.json` from the English file via `npm run strings`.
