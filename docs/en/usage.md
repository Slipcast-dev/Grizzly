# User guide

## Opening files

- `⌘O` / `Ctrl+O`, or drag files onto the window or the Dock / taskbar icon.
- Several files open as tabs. `⇧⌘]` / `⇧⌘[` (`Ctrl+Shift+]` / `[`) cycle through them.
- Supported extensions: `md markdown mdown txt text log json yaml yml csv tsv xml html htm ini conf toml tex rtf`.
  Anything unknown opens as plain text.

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

## Two files side by side

`⌘\` / `Ctrl+\` splits the window into two panes so you can compare or cross-reference two documents. Press it again to go back.

## Library

The sidebar holds a **virtual library**: your own folders, recents and favorites (⭐). It is only a list of
references — it never moves, copies or changes your files.

- **Open** in the toolbar opens a file or adds a whole folder from disk (subfolders become sidebar folders; use
  *Refresh from folder* in its menu to pick up new files). Dropping a folder into the window does the same.
- **Quick Look**: select a file in the sidebar and press Space (or use the context menu) to preview it without opening a tab.

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
- **Theme:** Xcode, GitHub, Solarized, Dracula, Monokai, Nord, One Dark. Themes without a light variant stay dark in light mode.
- **Font** and **size** (`⌘+` / `⌘-` while reading), heading spacing (compact / normal / spacious).
- **Language:** the interface follows the system language (Russian or English; English otherwise).

## Shortcut reference

| Action | macOS | Windows |
|---|---|---|
| Open / Save / Close tab | `⌘O` / `⌘S` / `⌘W` | `Ctrl+O` / `Ctrl+S` / `Ctrl+W` |
| Settings | `⌘,` | `Ctrl+,` |
| Find / next / previous | `⌘F` / `⌘G` / `⇧⌘G` | `Ctrl+F` / `Ctrl+G` / `Ctrl+Shift+G` |
| Next / previous tab | `⇧⌘]` / `⇧⌘[` | `Ctrl+Shift+]` / `[` (or `Ctrl+Tab`) |
| Split view | `⌘\` | `Ctrl+\` |
| Reading / Source / Edit | `⌥⌘1` / `2` / `3` | `Ctrl+Alt+1` / `2` / `3` |
| Reload | `⌘R` | `Ctrl+R` |
| Font larger / smaller | `⌘+` / `⌘-` | `Ctrl++` / `Ctrl+-` |
