# Building from source

## macOS app (SwiftUI)

Requirements: macOS 13+, Xcode Command Line Tools (`xcode-select --install`). A full Xcode install is not needed —
the scripts call `swiftc` directly.

```bash
./scripts/build-app.sh          # -> build/Grizzly.app (host architecture, ad-hoc signed)
./scripts/make-dmg.sh           # -> build/Grizzly-<version>.dmg
```

Other architecture, separate output folder:

```bash
ARCH=arm64  OUT=build/arm64 ./scripts/build-app.sh && ARCH=arm64  OUT=build/arm64 ./scripts/make-dmg.sh
ARCH=x86_64 OUT=build/x64   ./scripts/build-app.sh && ARCH=x86_64 OUT=build/x64   ./scripts/make-dmg.sh
```

Optional signing and notarization for your own distribution:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="my-notary-profile" ./scripts/make-dmg.sh
```

`Package.swift` is provided for editors that understand SwiftPM; the release builds use the scripts above.

## Windows app (Electron)

Requirements: a current Node.js LTS and npm. The portable .exe can be built on macOS or Linux as well as on Windows.

```bash
cd electron
npm ci
npm start          # run from source
npm run dist       # -> dist/Grizzly-<version>-portable.exe (x64)
```

Other commands:

```bash
npm run strings                          # regenerate the English table from ../resources/en.lproj
npx electron scripts/smoke.js a.md b.csv # launch the real app and print the renderer state
```

## Release checklist

1. Bump the version in `scripts/build-app.sh` (`CFBundleShortVersionString`) and `electron/package.json`.
2. Update [CHANGELOG.md](../../CHANGELOG.md).
3. Build all three artifacts and compute checksums with `shasum -a 256`.
4. Tag `vX.Y.Z` and create a GitHub release with the artifacts and checksums.
