# Changelog

All notable changes are documented here. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions follow [Semantic Versioning](https://semver.org/).

## [0.3.1] - 2026-10-28

### Fixed
- macOS: the Quick Look preview no longer spins forever; the extension is now declared as a data-based preview.
- Docs: troubleshooting for the Quick Look extension (listed twice in System Settings, preview not showing).

## [0.3.0] - 2026-10-28

### Added
- macOS: **Quick Look extension** — press Space on Markdown, YAML, CSV/TSV and log files in Finder to see them formatted, without opening Grizzly. Enable it in System Settings → Login Items & Extensions → Quick Look.
- macOS: **Settings → File types** — make Grizzly the default app for any supported extension with one click (or for all of them), and add your own extensions.
- macOS: Grizzly declares generic text and source-code types, so it can be chosen as the default app for extensions beyond the built-in list.

### Notes
- Use 0.3.1 or later: the Quick Look preview in 0.3.0 never finished loading.
- This release is macOS-only. The Windows portable build is unchanged and stays at 0.2.1.

## [0.2.1] - 2026-10-27

### Fixed
- A new sidebar folder is now created when the name field loses focus (not only on Return); previously an unconfirmed name vanished when switching sections, and the folder could not be opened, renamed, deleted or receive files.
- Clicking a folder row anywhere expands or collapses it.

## [0.2.0] - 2026-10-27

### Added
- Toolbar **Open** button (menu: open file, add folder from disk).
- Folders from disk: files of a directory and its subdirectories are added to the sidebar; "Refresh from folder" and "Show in Finder" in the folder menu; folders can be dropped into the window.
- Quick Look: Space or the context menu previews a sidebar file without opening it (system Quick Look on macOS, a text preview on Windows).

### Fixed
- Sidebar rows now react to clicks on the file name, not only at the row edges.
- Folder context menu (rename, delete) works on the whole folder row.

## [0.1.0] - 2026-10-27

First public release.

### Added
- Reading, source and edit modes for Markdown and text; CSV/TSV tables; syntax colors for JSON, YAML, INI/TOML, XML/HTML, TeX and logs.
- Line bookmarks, find with live highlighting, tabs, two files side by side.
- Virtual library with folders, recents and favorites.
- Live reload when files change on disk.
- Seven themes, light / dark / system appearance, font and size settings.
- Russian and English interface.
- Builds: macOS Apple Silicon (`.dmg`), macOS Intel (`.dmg`), Windows x64 portable (`.exe`).

[0.3.1]: https://github.com/Slipcast-dev/Grizzly/releases/tag/v0.3.1
[0.3.0]: https://github.com/Slipcast-dev/Grizzly/releases/tag/v0.3.0
[0.2.1]: https://github.com/Slipcast-dev/Grizzly/releases/tag/v0.2.1
[0.2.0]: https://github.com/Slipcast-dev/Grizzly/releases/tag/v0.2.0
[0.1.0]: https://github.com/Slipcast-dev/Grizzly/releases/tag/v0.1.0
