# User guide

## Opening files

- `⌘O` / `Ctrl+O`, or drag files onto the window or the Dock / taskbar icon.
- **From Finder (macOS)**: double-click a file or use *Open With → Grizzly*. If Grizzly is not running it starts with the file; if it is, the file opens as a tab in the existing window (never a second window or a second copy of the app). To make it the default app, see *Settings → File types*.
- Several files open as tabs. `⇧⌘]` / `⇧⌘[` (`Ctrl+Shift+]` / `[`) cycle through them.
- Supported extensions: `md markdown mdown txt text log json yaml yml csv tsv xml html htm ini conf toml tex rtf`,
  plus source code: `py pyw swift c h cpp cc cxx hpp hh hxx cs js mjs cjs jsx ts tsx css scss php`.
  Anything unknown opens as plain text.

## New file

`⌘N` / `Ctrl+N` (or the *New File* button in the sidebar next to *New Folder*) asks for a name, folder and format in the save dialog, creates the file with a
small starter template (a heading for Markdown, `{}` for JSON, a header row for CSV, a skeleton for HTML, C/C++, C#, PHP and so on) and opens it in a new tab in
Edit mode. Existing files are replaced only after the system dialog's confirmation.

## Three modes

| Mode | Shortcut (macOS / Windows) | What it is for |
|---|---|---|
| **Reading** | `⌥⌘1` / `Ctrl+Alt+1` | Rendered Markdown, formatted CSV tables |
| **Source** | `⌥⌘2` / `Ctrl+Alt+2` | Raw text with line numbers, bookmarks and syntax colors |
| **Edit** | `⌥⌘3` / `Ctrl+Alt+3` | Change the text and save with `⌘S` / `Ctrl+S` |

Saving writes the text back in the encoding the file was read with; a UTF-8 BOM is kept.

## Markdown

Headings, emphasis, inline code, fenced code blocks, ordered / unordered lists, task lists (`- [x]`), block quotes,
tables and links are rendered in the current theme. Open [`samples/README.md`](../../samples/README.md) for an example.

## Other formats

| Type | Treatment |
|---|---|
| CSV / TSV | Shown as a table; the delimiter (`,` `;` tab) is detected automatically |
| Python, Swift, C / C++, C#, JavaScript, TypeScript, CSS, PHP | Syntax colors in Reading and Source modes (and live in Edit mode on macOS); comments and strings spanning lines are supported. Fenced Markdown blocks (```` ```python ````) use the same colors |
| JSON, YAML, INI / conf / TOML | Syntax colors in source mode |
| XML / HTML | Shown as source with syntax colors (HTML is never executed) |
| TeX | Syntax colors |
| Log | Errors, warnings and successes are highlighted |
| RTF | Converted to plain text |

## Bookmarks

In source mode, click a line number to toggle an orange bookmark. Bookmarks are remembered per file between sessions.
The line-number gutter can be turned off in Settings.

## Find

`⌘F` / `Ctrl+F` opens the find bar; matches are highlighted as you type. `⌘G` / `Ctrl+G` goes to the next match,
`⇧⌘G` / `Ctrl+Shift+G` to the previous one (Windows also accepts `F3` / `Shift+F3`). `Esc` closes the bar.

Find also works in Edit mode: hits are highlighted in the text you are editing.

## Select all and copy

In Reading and Source, `⌘A` / `Ctrl+A` selects the whole document and `⌘C` / `Ctrl+C` copies all of it.

## Search files, tags

The sidebar field **Search files** matches the beginning of a file or folder name, or of any word in it ("gri" finds "My Grizzly notes.md"). Typing `#work` searches tags.

**Tags** live at the bottom of the sidebar. Create one with **+**, assign it from a file's context menu (*Tags*), rename or delete it from the tag's context menu. Tags are the `#words` you write in a Markdown / text file: they are colored in the text, a click on one lists the files that carry it, and typing `#` in Edit mode suggests the known tags. In the sidebar, click a tag to filter, click more tags to narrow the list (files must carry all of them), or *All Tags* to reset. *Rename* and *Delete* in a tag's context menu also change the text of every file that uses it (RTF files and files with unsaved edits are skipped).

## Spelling and grammar

In Edit mode, Markdown, TXT, RTF and TeX files are checked in Russian and English; mistakes are underlined and corrections are in the context menu (macOS also checks grammar). Switch it off in *Settings → Text*. Source code is never checked. On Windows the dictionaries are downloaded by the system on first use.

## Emoji

The 😀 button at the right end of the toolbar (Edit mode) opens the system emoji picker (`⌃⌘Space` on macOS, `Win+.` on Windows). If a file is in an 8-bit encoding (Windows-1251, ISO-8859-1) that cannot hold emoji, Grizzly offers to save it as UTF-8.

Tag names may contain emoji (`#🍕`). A tag typed into the text appears in the sidebar after a short pause, without saving.

## Unsaved changes

Closing a tab or the window with unsaved edits asks whether to save, discard or cancel.

## Edit mode buttons and notifications

In Edit mode the *Undo* button (top right) reverts the last change and *Save* writes the file. Short pop-up notifications confirm actions such as saving, copying all text, creating a file, reloading, and changing tags, bookmarks or favorites.

## Updates

*Settings → Updates → Check for Updates* looks for a newer release on GitHub. If there is one, Grizzly downloads and installs it (verifying the SHA-256 from the release notes) and restarts. The check also runs silently at every launch. On macOS the app must be in a folder you can write to (normally *Applications*).

## Two files side by side

`⌘\` / `Ctrl+\` splits the window into two panes so you can compare or cross-reference two documents. Press it again to go back.

## Save As

The **Save As…** button in the sidebar action row (`⇧⌘S` / `Ctrl+Shift+S`) saves a **copy** of the current file, including unsaved edits, to a place you choose.
The name field starts with the file name **without an extension**. Pick the format in the dialog (Markdown, Text, JSON, YAML, CSV, TSV, Log, XML, HTML, INI/TOML, TeX, RTF); it is appended when you save. An extension you type yourself wins.
The text is not converted between formats, only the file type changes. The source encoding is kept; if it cannot hold some characters the copy is written in UTF-8, and RTF sources are saved as UTF-8 text.
The open document is not changed. *Save* (`⌘S`) still writes edits back to the original file.

## Library

The sidebar holds a **virtual library**: your own folders and favorites (⭐), plus the history of opened files on the clock tab. It is only a list of
references — it never moves, copies or changes your files.

- **New folder** (the folder button in the sidebar header): type a name and press Return (leaving the field also saves it). Drag files onto a folder to move them; right-click a folder to rename or delete it.
- The sidebar has one row of equal buttons: **New File**, **Open File**, **New Folder** (virtual) and **Save As…**. *File → Add Folder from Disk…* (`⇧⌘O` / `Ctrl+Shift+O`) adds a whole folder from disk (subfolders become sidebar folders; use
  *Refresh from folder* in its menu to pick up new files). Dropping a folder into the window does the same.
- **History** (the clock tab): every file you open is recorded there, newest first. Removing a file from the library does **not** remove it from the history; opening it from there shows it in a tab without putting it back in the sidebar. Right-click an entry to remove it, or use *Clear* to empty the list.
- **Quick Look**: select a file in the sidebar and press Space (or use the context menu) to preview it without opening a tab.

## Preview in Finder and default app (macOS)

- **Finder preview**: with the *Grizzly Quick Look* extension enabled (see the installation guide), pressing Space on a Markdown, YAML, CSV/TSV or log file shows it formatted without opening Grizzly.
- **Default app**: *Settings → File types* lists the supported extensions. Click one to open such files in Grizzly by default, use *Make Grizzly the default app for all*, or type your own extension (e.g. `py`). A checkmark means Grizzly is already the default; macOS may ask you to confirm.

Where it is stored:

| Platform | Location |
|---|---|
| macOS | `~/Library/Application Support/Grizzly/library.json` |
| Windows | `GrizzlyData\library.json` next to the .exe (or `%APPDATA%\Grizzly`) |

## Live reload

When a file changes on disk (a build script, a sync tool, an AI assistant), Grizzly shows a banner. Click it or press
`⌘R` / `Ctrl+R` to reload. With *auto reload* enabled in Settings the file refreshes itself; text you are editing is
never overwritten without asking.

## Appearance

Open Settings (`⌘,` / `Ctrl+,`):

- **Appearance:** follow system, light or dark.
- **Sections:** Appearance, Text, Syntax highlighting, Files, Language and (macOS) File types are listed on the left; the window can be resized in both directions.
- **Syntax highlighting:** one switch for everything and a switch per language (Settings → Syntax highlighting).
- **Theme:** Xcode, GitHub, Solarized, Dracula, Monokai, Nord, One Dark. Themes without a light variant stay dark in light mode.
- **Font** and **size** (`⌘+` / `⌘-` while reading), heading spacing (compact / normal / spacious).
- **Language:** *Settings → Language* switches between *Follow System*, Русский and English. On first launch the interface follows the system language (Russian on a Russian system, English otherwise). On macOS the app offers to restart after a change; on Windows it switches instantly.

## Shortcut reference

| Action | macOS | Windows |
|---|---|---|
| New file | `⌘N` | `Ctrl+N` |
| Save As | `⇧⌘S` | `Ctrl+Shift+S` |
| Open / Save / Close tab | `⌘O` / `⌘S` / `⌘W` | `Ctrl+O` / `Ctrl+S` / `Ctrl+W` |
| Settings | `⌘,` | `Ctrl+,` |
| Find / next / previous | `⌘F` / `⌘G` / `⇧⌘G` | `Ctrl+F` / `Ctrl+G` / `Ctrl+Shift+G` |
| Next / previous tab | `⇧⌘]` / `⇧⌘[` | `Ctrl+Shift+]` / `[` (or `Ctrl+Tab`) |
| Split view | `⌘\` | `Ctrl+\` |
| Reading / Source / Edit | `⌥⌘1` / `2` / `3` | `Ctrl+Alt+1` / `2` / `3` |
| Reload | `⌘R` | `Ctrl+R` |
| Font larger / smaller | `⌘+` / `⌘-` | `Ctrl++` / `Ctrl+-` |
