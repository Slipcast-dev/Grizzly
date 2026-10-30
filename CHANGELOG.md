# Changelog

All notable changes are documented here. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions follow [Semantic Versioning](https://semver.org/).

## [1.1.0] - 2026-10-30

This release also contains everything developed as 1.0.0 and 1.0.1 (below), which were never published separately.

### Added
- **Syntax highlighting settings** (*Settings → Syntax highlighting*): one switch for all highlighting plus a switch for every language (Python, Swift, C/C++, C#, JavaScript, TypeScript, CSS, PHP, JSON, YAML, INI/TOML, XML, HTML, TeX, Log), with *Turn On All* / *Turn Off All*. Applies to Reading, Source and Edit modes and to Markdown code blocks.
- **Hover and press effects on every button**: a soft tint of the theme's accent color on hover, a stronger tint and a small shrink while pressed. Selected controls use the accent color.

### Changed
- **Settings reorganized into sections** (Appearance, Text, Syntax highlighting, Files, Language, File types on macOS), shown as a list on the left and cards on the right. The window can be resized in width and height; long sections scroll, scrollbars are always visible on Windows.

## [1.0.1] - 2026-10-30 (shipped in 1.1.0)

### Fixed
- **Select all**: text of an open file can now be selected in one go (drag across lines or Select All). The rows were lazily built, which limited selection to a single line; they are now built together (lazily only for files over 4000 lines). New command *View → Copy All Text* (`⌥⌘C`) copies the whole document. Windows: `Ctrl+A` selects the whole document text.
- **Window size is remembered**: the window reopens with the size and position it had when closed (macOS; Windows already did).
- **Save As… / New File dialog**: the *Format* row is centered under the panel's own fields instead of sticking to the left edge.
- **Settings window**: content scrolls and the window can be resized vertically; it no longer runs off the screen.

### Changed
- **File actions moved into the sidebar**: one row of four equal buttons — New File, Open File, New Folder, Save As… — replaces the toolbar's open menu and Save As button (no duplicates, no drop-down). *Add Folder from Disk…* is now in the File menu (`⇧⌘O` / `Ctrl+Shift+O`).
- **The Reading / Source / Edit switch is centered** at the top of the window in both versions; the remaining tools stay on the right.
- Sidebar and toolbar controls share one set of sizes (30–34 pt height, equal square buttons, same corner radii): the sidebar section switcher and the folder button were too small.

## [1.0.0] - 2026-10-30 (shipped in 1.1.0)

### Added
- **Syntax highlighting for programming languages**: Python, Swift, C / C++, C#, JavaScript (JSX), TypeScript (TSX), CSS / SCSS and PHP. Keywords, types, literals, numbers, strings, comments, decorators / attributes, preprocessor lines and CSS properties are colored with the current theme. Multi-line block comments, triple-quoted strings and template literals are tracked across lines. Fenced code blocks in Markdown (```` ```python ````, `cpp`, `cs`, `js`, ...) use the same colors. macOS also colors the text live in Edit mode.
- **New file** (`⌘N` / `Ctrl+N`, also in the toolbar's open menu): choose name, folder and format; the file is created with a small template and opens in Edit mode. Works for every supported format.
- Source-code extensions are now supported: `py pyw swift c h cpp cc cxx hpp hh hxx cs js mjs cjs jsx ts tsx css scss php`. On macOS Grizzly is offered under *Open With* for them without claiming them as the default app.
- Sample files for every new language in `samples/`.

### Changed
- First stable release: all features of the 0.x line are included and documented in English and Russian.

## [0.4.0] - 2026-10-30

### Added
- **Language setting**: *Settings → Language* — *Follow System*, Русский or English. On first launch (and until you choose) the interface follows the system language: Russian on a Russian system, English otherwise. macOS offers a restart after a change; Windows switches instantly, including the menu.

### Changed
- macOS: the app now has a single window (`LSMultipleInstancesProhibited`, no automatic window tabbing); a file opened while Grizzly is running always becomes a tab in that window. Windows already behaved this way (single-instance lock).
- macOS: the fallback language is now English for any system language other than Russian (development region `en`).

## [0.3.3] - 2026-10-29

### Fixed
- **History is kept**: files you opened stay in *Recent* after they are removed from the sidebar. The history is now stored separately from the library; opening an entry shows the file in a tab without adding it back to the sidebar. Entries can be removed one by one from the context menu, and *Clear* empties the list. Existing recents are migrated.
- **Save As…**: the name field no longer comes pre-filled with the extension. It holds just the name and the format chosen in the list is added on save, so saving as another format no longer means erasing the old extension first (an extension typed by hand still wins).
- macOS (Intel / x64): a file opened from Finder (double click, *Open With*) now opens in the app on launch. Files are accepted through every route the system may use (app delegate, scene `onOpenURL`) and queued until the app has started.

### Changed
- **Windows portable build is updated to 0.3.3** (was 0.2.1) and now has everything from 0.3.x: Save As…, the hardened file IPC, and the history fix above.

## [0.3.2] - 2026-10-29

### Added
- **Save As…** (toolbar button, `⇧⌘S` / `Ctrl+Shift+S`): saves a copy of the current file, including unsaved edits, in any supported format (Markdown, Text, JSON, YAML, CSV/TSV, Log, XML, HTML, INI/TOML, TeX, RTF) and in a place you choose. The open document is not changed.
- macOS: files opened from Finder (double click, Open With) or the Dock open as tabs in the existing window, and launch the app with the file when it is not running. The built-in extensions are now declared with the default handler rank.
- Unit tests and CI (`scripts/test.sh`, `.github/workflows/ci.yml`); `VERSION` is the single source of the version number.

### Security
- Quick Look: quotes are escaped in rendered Markdown and only `http`, `https` and `mailto` links are clickable.
- Windows: the main process now accepts file IPC only from the app's own page and only for absolute paths with supported extensions.

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

[0.3.2]: https://github.com/Slipcast-dev/Grizzly/releases/tag/v0.3.2
[0.3.1]: https://github.com/Slipcast-dev/Grizzly/releases/tag/v0.3.1
[0.3.0]: https://github.com/Slipcast-dev/Grizzly/releases/tag/v0.3.0
[0.2.1]: https://github.com/Slipcast-dev/Grizzly/releases/tag/v0.2.1
[0.2.0]: https://github.com/Slipcast-dev/Grizzly/releases/tag/v0.2.0
[0.1.0]: https://github.com/Slipcast-dev/Grizzly/releases/tag/v0.1.0
