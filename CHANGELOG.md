# Changelog

All notable changes are documented here. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions follow [Semantic Versioning](https://semver.org/).

## [1.2.0] - 2026-10-30

### Added
- **Check for updates** (*Settings → Updates*): asks GitHub for the latest release, says whether a newer version is out and, if so, downloads and installs it from inside the app (macOS: replaces the app from the `.dmg`; Windows: replaces the portable `.exe`). The SHA-256 from the release notes is verified when present, downloads are limited to GitHub over HTTPS. The check also runs silently on every launch and only speaks up when there is something new.
- **Spelling and grammar check** (Russian and English) in Edit mode for Markdown, TXT, RTF and TeX, with underlined mistakes (macOS: system checker with grammar; Windows: spelling with suggestions in the context menu). Switch in *Settings → Text*.
- **Tags**: create, rename and delete tags, assign them from a file's context menu, see all tags as chips at the bottom of the sidebar, click a tag to list its files. `#tag` in the search field searches tags.
- **Emoji**: an emoji button in Edit mode; saving a file in an 8-bit encoding (Windows-1251, ISO-8859-1) that cannot hold emoji offers UTF-8 instead of failing.

### Changed
- The sidebar filter is now **Search files**: it matches the beginning of a file or folder name, or of any word in it.
- Closing the window with unsaved edits asks about every changed file: save, don't save or cancel (macOS and Windows).

### Fixed
- **Reading and Source are real text views**: drag across lines and paragraphs, `⌘A` / `Ctrl+A` selects everything, `⌘C` copies it (macOS; replaces the earlier overlay). Source keeps its line numbers and bookmarks.
- **Tags in text**: `#hashtags` written in a Markdown / text file are tags of that file (listed in the sidebar, searchable); the library is scanned at launch.
- The emoji button moved to the rightmost spot of the toolbar.
- **Find** works in Edit mode too (hits are highlighted in the text being edited).
- macOS: after saving in Edit mode the text no longer disappears until the mode is switched.
- macOS: ⌘A in Reading and Source selects the whole document, ⌘C copies all of it (also *View → Select All Text*).

## [1.1.0] - 2026-10-30

### Added
- **Syntax highlighting for programming languages**: Python, Swift, C / C++, C#, JavaScript (JSX), TypeScript (TSX), CSS / SCSS and PHP, next to the existing JSON, YAML, INI/TOML, XML/HTML, TeX and log coloring. Keywords, types, literals, numbers, strings, comments, decorators / attributes, preprocessor lines and CSS properties follow the current theme. Multi-line block comments, triple-quoted strings and template literals are tracked across lines. Fenced code blocks in Markdown (```` ```python ````, `cpp`, `cs`, `js`, ...) use the same colors, and macOS colors the text live in Edit mode.
- **Syntax highlighting settings** (*Settings → Syntax highlighting*): one switch for everything and a switch per language, with *Turn On All* / *Turn Off All*.
- **New file** (`⌘N` / `Ctrl+N`, also a sidebar button): choose name, folder and format; the file is created from a small template and opens in Edit mode.
- Source-code extensions are supported: `py pyw swift c h cpp cc cxx hpp hh hxx cs js mjs cjs jsx ts tsx css scss php`. On macOS Grizzly is offered under *Open With* for them without claiming them as the default app. Sample files for every language are in `samples/`.
- **Hover and press effects on every button**: a soft tint of the theme's accent color on hover, a stronger tint and a small shrink while pressed.

### Changed
- **Settings are split into sections** (Appearance, Text, Syntax highlighting, Files, Language, and File types on macOS): a list on the left, cards on the right. The window can be resized in width and height, long sections scroll, scrollbars are always visible on Windows.
- **File actions live in the sidebar**: one row of equal buttons — New File, Open File, New Folder, Save As…. *Add Folder from Disk…* is in the File menu (`⇧⌘O` / `Ctrl+Shift+O`). The Reading / Source / Edit switch is centered at the top of the window.
- Sidebar and toolbar controls share one set of sizes and corner radii.

### Fixed
- **Select all**: the whole text of an open file can be selected at once (rows are lazily built only for files over 4000 lines). *View → Copy All Text* (`⌥⌘C`) copies the document; `Ctrl+A` on Windows.
- **Window size is remembered** between launches (macOS).
- The *Format* row of the Save As / New File dialog is centered like the other rows.

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
