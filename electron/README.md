# Grizzly — Windows (Electron)

Port of the macOS SwiftUI app. Same features: Markdown reading mode, source view with line numbers and
bookmarks, CSV tables, syntax coloring (JSON, YAML, INI, XML/HTML, TeX, logs), find, two panes side by side,
tabs, virtual library with folders / recents / favorites, themes, reload on change, drag and drop,
Russian and English UI.

## Run from source

    npm install
    npm start

## Build the portable .exe

    npm run dist

The result is `dist/Grizzly-<version>-portable.exe`. It needs no installation: settings and the library
are stored in a `GrizzlyData` folder next to the .exe (or in `%APPDATA%` if that folder is read-only).

Command line: `Grizzly-0.1.0-portable.exe file1.md file2.csv` opens the files; a second launch hands its
files to the running window.

`npm run strings` regenerates the English table from `../resources/en.lproj/Localizable.strings`.
`npx electron scripts/smoke.js <files>` launches the real app and prints the renderer state (dev check).
