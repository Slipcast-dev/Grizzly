<p align="center">
  <img src="docs/assets/banner.svg" alt="Grizzly — a fast, calm reader for Markdown and text" width="100%">
</p>

<p align="center">
  <a href="https://github.com/Slipcast-dev/Grizzly/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/Slipcast-dev/Grizzly?style=for-the-badge&color=ff9f0a"></a>
  <a href="https://github.com/Slipcast-dev/Grizzly/releases"><img alt="Total downloads" src="https://img.shields.io/github/downloads/Slipcast-dev/Grizzly/total?style=for-the-badge&color=34c759&label=downloads"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/github/license/Slipcast-dev/Grizzly?style=for-the-badge&color=7fd4c1"></a>
  <a href="https://github.com/Slipcast-dev/Grizzly/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/Slipcast-dev/Grizzly/ci.yml?branch=main&style=for-the-badge&label=CI"></a>
  <img alt="Platforms" src="https://img.shields.io/badge/platform-macOS%20%7C%20Windows-4a9eff?style=for-the-badge">
  <img alt="Languages" src="https://img.shields.io/badge/UI-EN%20%7C%20RU-c9b6f5?style=for-the-badge">
</p>

<p align="center">
  <b>English</b> · <a href="README.ru.md">Русский</a> · <a href="docs/README.md">Documentation</a> · <a href="CHANGELOG.md">Changelog</a>
</p>

---

**Grizzly** is a small reader for Markdown, plain-text and source-code files (with syntax highlighting for Python, Swift,
C/C++, C#, JavaScript, TypeScript, CSS and PHP). It opens a document, renders it the way you
would like to read it, and gets out of the way. The macOS app is native (SwiftUI); the Windows app is a
portable Electron port with the same features.

<p align="center">
  <img src="docs/assets/features.svg" alt="Features: read Markdown, source and edit, tabs and split view, themes and languages" width="100%">
</p>

## Download

<p align="center">
  <img src="docs/assets/downloads.svg" alt="Downloads: macOS Apple Silicon, macOS Intel, Windows x64" width="100%">
</p>

Get the files from the **[latest release](https://github.com/Slipcast-dev/Grizzly/releases/latest)**.

| Platform | File | Notes |
|---|---|---|
| macOS 13+, Apple Silicon | `Grizzly-1.2.1-arm64.dmg` | Drag *Grizzly* to *Applications* |
| macOS 13+, Intel | `Grizzly-1.2.1-x64.dmg` | Drag *Grizzly* to *Applications* |
| Windows 10/11, x64 | `Grizzly-1.2.1-portable.exe` | Portable, no installer |

> [!IMPORTANT]
> The builds are **not code-signed or notarized**. macOS Gatekeeper and Windows SmartScreen will warn on first
> launch. See [Installation](docs/en/installation.md) for the exact steps, and verify the SHA-256 checksums
> published in the release notes before running anything you downloaded.

## Features

- **Reading mode** — Markdown with headings, lists, task lists, quotes, code blocks, tables and links. Reading and Source are real text views: drag across lines, `⌘A` / `Ctrl+A` selects the whole document, `⌘C` copies it.
- **Source mode** — line numbers, clickable line **bookmarks** (kept between sessions), syntax colors for
  **Python, Swift, C/C++, C#, JavaScript, TypeScript, CSS and PHP** (also inside fenced code blocks in Markdown) as well as
  JSON, YAML, INI/TOML, XML/HTML, TeX and log files. Colors follow the theme; comments and strings that span several lines are handled.
- **New file** — `⌘N` / `Ctrl+N`: pick a name, folder and format; the file is created with a small template and opens for editing.
- **Edit mode** — edit and save in place; the original encoding (UTF-8 with/without BOM, UTF-16, Windows-1251,
  ISO-8859-1) is preserved (a file that cannot hold emoji is offered UTF-8). *Undo* steps back one word at a time; spelling and grammar are checked in Russian and English (Markdown, TXT, RTF, TeX).
- **CSV / TSV tables** with automatic delimiter detection.
- **Save As…** — save a copy in any supported format and location, without touching the original.
- **Find** with live highlighting, next / previous match; also in Edit mode.
- **Search files** by the beginning of a name or of any word in it (files and folders).
- **Tags like in Apple Notes** — `#hashtags` (emoji allowed) written in a file are its tags: colored in the text, suggested while typing, listed in the sidebar; click one or several to list the files that carry them; rename or delete a tag everywhere.
- **Notifications** for saving, copying, tags and other actions; an emoji picker button in Edit mode.
- **Updates** — *Settings → Updates* checks GitHub (also at every launch) and installs a new version from inside the app.
- **Tabs** and **two files side by side**.
- **Virtual library** — folders and favorites that never touch your files (only renaming or deleting a tag edits the text of files that use it, after a confirmation), plus an open history that survives removing a file from the sidebar.
- **Live reload** — a banner appears when the file changes on disk (handy for files written by scripts or AI tools).
- **7 themes** (Xcode, GitHub, Solarized, Dracula, Monokai, Nord, One Dark), light / dark / follow system,
  font and size choices.
- **Quick Look in Finder** (macOS) — press Space on Markdown, YAML, CSV or log files to preview them without opening Grizzly.
- **Default app picker** (macOS) — Settings → File types makes Grizzly the default app for chosen extensions.
- **English and Russian** interface.

Supported extensions: `md markdown mdown txt text log json yaml yml csv tsv xml html htm ini conf toml tex rtf` and source code: `py pyw swift c h cpp cc cxx hpp hh hxx cs js mjs cjs jsx ts tsx css scss php`.

## Quick start

1. Download the file for your platform from the [release page](https://github.com/Slipcast-dev/Grizzly/releases/latest).
2. Follow [Installation](docs/en/installation.md).
3. Open a file (`⌘O` / `Ctrl+O`) or drag it onto the window. Try the files in [`samples/`](samples).

## Keyboard shortcuts

| Action | macOS | Windows |
|---|---|---|
| Open | `⌘O` | `Ctrl+O` |
| Save | `⌘S` | `Ctrl+S` |
| Close tab | `⌘W` | `Ctrl+W` |
| Find / next / previous | `⌘F` / `⌘G` / `⇧⌘G` | `Ctrl+F` / `Ctrl+G` / `Ctrl+Shift+G` |
| Next / previous tab | `⇧⌘]` / `⇧⌘[` | `Ctrl+Shift+]` / `Ctrl+Shift+[` |
| Two files side by side | `⌘\` | `Ctrl+\` |
| Reading / Source / Edit | `⌥⌘1` / `⌥⌘2` / `⌥⌘3` | `Ctrl+Alt+1` / `2` / `3` |
| Save As… | `⇧⌘S` | `Ctrl+Shift+S` |
| Reload file | `⌘R` | `Ctrl+R` |
| Select all / copy (Reading, Source) | `⌘A` / `⌘C` | `Ctrl+A` / `Ctrl+C` |
| Undo / redo (Edit) | `⌘Z` / `⇧⌘Z` | `Ctrl+Z` / `Ctrl+Shift+Z` |
| Larger / smaller text | `⌘+` / `⌘-` | `Ctrl++` / `Ctrl+-` |

More in the [User guide](docs/en/usage.md).

## Privacy and security

Grizzly has no telemetry and no accounts. Its only network access is the update check against the public GitHub Releases API (at launch and from *Settings → Updates*); a download is installed only from GitHub over HTTPS and is verified against the SHA-256 in the release notes (a release without one is refused). The Windows app runs its UI in a
sandboxed renderer with context isolation and a strict Content-Security-Policy. Report vulnerabilities
privately — see [SECURITY.md](SECURITY.md).

## Build from source

```bash
# macOS (Command Line Tools are enough)
./scripts/build-app.sh && ./scripts/make-dmg.sh

# Windows port (Electron)
cd electron && npm ci && npm run dist
```

Details: [Building](docs/en/building.md) · Design notes: [Architecture](docs/en/architecture.md).

## Contributing

Issues and pull requests are welcome — read [CONTRIBUTING.md](CONTRIBUTING.md) and the
[Code of Conduct](CODE_OF_CONDUCT.md) first.

## License

[MIT](LICENSE) © 2026 Slipcast-dev
