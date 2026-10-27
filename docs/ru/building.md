# Сборка из исходников

## Приложение для macOS (SwiftUI)

Нужно: macOS 13+, Xcode Command Line Tools (`xcode-select --install`). Полный Xcode не требуется —
скрипты вызывают `swiftc` напрямую.

```bash
./scripts/build-app.sh          # -> build/Grizzly.app (архитектура хоста, ad-hoc подпись)
./scripts/make-dmg.sh           # -> build/Grizzly-<версия>.dmg
```

Другая архитектура и отдельная папка вывода:

```bash
ARCH=arm64  OUT=build/arm64 ./scripts/build-app.sh && ARCH=arm64  OUT=build/arm64 ./scripts/make-dmg.sh
ARCH=x86_64 OUT=build/x64   ./scripts/build-app.sh && ARCH=x86_64 OUT=build/x64   ./scripts/make-dmg.sh
```

Подпись и нотаризация для собственной раздачи (по желанию):

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="my-notary-profile" ./scripts/make-dmg.sh
```

`Package.swift` нужен редакторам с поддержкой SwiftPM; релизные сборки делаются скриптами выше.

## Приложение для Windows (Electron)

Нужно: актуальный Node.js LTS и npm. Portable .exe можно собрать и на macOS / Linux, не только на Windows.

```bash
cd electron
npm ci
npm start          # запуск из исходников
npm run dist       # -> dist/Grizzly-<версия>-portable.exe (x64)
```

Прочее:

```bash
npm run strings                          # пересобрать английскую таблицу из ../resources/en.lproj
npx electron scripts/smoke.js a.md b.csv # запустить настоящее приложение и вывести состояние
```

## Чек-лист релиза

1. Поднимите версию в `scripts/build-app.sh` (`CFBundleShortVersionString`) и `electron/package.json`.
2. Обновите [CHANGELOG.md](../../CHANGELOG.md).
3. Соберите все три артефакта и посчитайте суммы `shasum -a 256`.
4. Поставьте тег `vX.Y.Z` и создайте релиз на GitHub с артефактами и суммами.
