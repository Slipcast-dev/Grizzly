<p align="center">
  <img src="docs/assets/banner.svg" alt="Grizzly — быстрая спокойная читалка Markdown и текста" width="100%">
</p>

<p align="center">
  <a href="https://github.com/Slipcast-dev/Grizzly/releases/latest"><img alt="Последний релиз" src="https://img.shields.io/github/v/release/Slipcast-dev/Grizzly?style=for-the-badge&color=ff9f0a"></a>
  <a href="LICENSE"><img alt="Лицензия: MIT" src="https://img.shields.io/github/license/Slipcast-dev/Grizzly?style=for-the-badge&color=7fd4c1"></a>
  <a href="https://github.com/Slipcast-dev/Grizzly/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/Slipcast-dev/Grizzly/ci.yml?style=for-the-badge&label=CI"></a>
  <img alt="Платформы" src="https://img.shields.io/badge/платформы-macOS%20%7C%20Windows-4a9eff?style=for-the-badge">
  <img alt="Языки" src="https://img.shields.io/badge/UI-EN%20%7C%20RU-c9b6f5?style=for-the-badge">
</p>

<p align="center">
  <a href="README.md">English</a> · <b>Русский</b> · <a href="docs/README.md">Документация</a> · <a href="CHANGELOG.md">Список изменений</a>
</p>

---

**Grizzly** — небольшая читалка для файлов Markdown и обычного текста. Открывает документ, показывает его так,
как удобно читать, и не мешает. Версия для macOS нативная (SwiftUI); версия для Windows — переносимый
порт на Electron с тем же набором функций.

<p align="center">
  <img src="docs/assets/features.svg" alt="Возможности: чтение Markdown, исходник и правка, вкладки и два файла рядом, темы и языки" width="100%">
</p>

## Скачать

<p align="center">
  <img src="docs/assets/downloads.svg" alt="Загрузки: macOS Apple Silicon, macOS Intel, Windows x64" width="100%">
</p>

Файлы лежат на странице **[последнего релиза](https://github.com/Slipcast-dev/Grizzly/releases/latest)**.

| Платформа | Файл | Примечание |
|---|---|---|
| macOS 13+, Apple Silicon | `Grizzly-1.1.0-arm64.dmg` | Перетащите *Grizzly* в *Программы* |
| macOS 13+, Intel | `Grizzly-1.1.0-x64.dmg` | Перетащите *Grizzly* в *Программы* |
| Windows 10/11, x64 | `Grizzly-1.1.0-portable.exe` | Без установки |

> [!IMPORTANT]
> Сборки **не подписаны и не нотаризованы**. macOS (Gatekeeper) и Windows (SmartScreen) покажут предупреждение
> при первом запуске. Точные шаги — в разделе [Установка](docs/ru/installation.md). Перед запуском сверьте
> контрольные суммы SHA-256 из описания релиза.

## Возможности

- **Режим чтения** — Markdown: заголовки, списки, чек-листы, цитаты, блоки кода, таблицы, ссылки.
- **Исходник** — номера строк, **закладки** по клику на номер (сохраняются между запусками), подсветка
  **Python, Swift, C/C++, C#, JavaScript, TypeScript, CSS и PHP** (в том числе в блоках кода Markdown), а также JSON,
  YAML, INI/TOML, XML/HTML, TeX и логов. Цвета берутся из темы; многострочные комментарии и строки поддерживаются.
- **Новый файл** — `⌘N` / `Ctrl+N`: выберите имя, папку и формат; файл создаётся с небольшим шаблоном и открывается для правки.
- **Правка** — редактирование и сохранение на месте; исходная кодировка (UTF-8 с BOM и без, UTF-16,
  Windows-1251, ISO-8859-1) сохраняется.
- **Таблицы CSV / TSV** с автоопределением разделителя.
- **Сохранить как…** — копия файла в любом поддерживаемом формате и в выбранном месте, оригинал не меняется.
- **Поиск** с подсветкой по мере ввода, переход к следующему / предыдущему.
- **Вкладки** и **два файла рядом**.
- **Виртуальная библиотека** — папки и избранное; ваши файлы она не трогает. История открытых файлов остаётся, даже если убрать файл из боковой панели.
- **Автообновление** — когда файл меняется на диске, появляется плашка (удобно для файлов, которые пишут скрипты и ИИ-инструменты).
- **7 тем** (Xcode, GitHub, Solarized, Dracula, Monokai, Nord, One Dark), светлая / тёмная / как в системе, выбор шрифта и размера.
- **Быстрый просмотр в Finder** (macOS) — пробел на файле Markdown, YAML, CSV или лога показывает его без открытия Grizzly.
- **Выбор программы по умолчанию** (macOS) — Настройки → Типы файлов назначают Grizzly для нужных расширений.
- Интерфейс на **русском и английском**.

Поддерживаемые расширения: `md markdown mdown txt text log json yaml yml csv tsv xml html htm ini conf toml tex rtf` и исходный код: `py pyw swift c h cpp cc cxx hpp hh hxx cs js mjs cjs jsx ts tsx css scss php`.

## Быстрый старт

1. Скачайте файл для своей платформы со [страницы релиза](https://github.com/Slipcast-dev/Grizzly/releases/latest).
2. Следуйте инструкции [Установка](docs/ru/installation.md).
3. Откройте файл (`⌘O` / `Ctrl+O`) или перетащите его в окно. Для пробы есть файлы в [`samples/`](samples).

## Горячие клавиши

| Действие | macOS | Windows |
|---|---|---|
| Открыть | `⌘O` | `Ctrl+O` |
| Сохранить | `⌘S` | `Ctrl+S` |
| Закрыть вкладку | `⌘W` | `Ctrl+W` |
| Поиск / далее / ранее | `⌘F` / `⌘G` / `⇧⌘G` | `Ctrl+F` / `Ctrl+G` / `Ctrl+Shift+G` |
| Следующая / предыдущая вкладка | `⇧⌘]` / `⇧⌘[` | `Ctrl+Shift+]` / `Ctrl+Shift+[` |
| Два файла рядом | `⌘\` | `Ctrl+\` |
| Чтение / Исходник / Правка | `⌥⌘1` / `⌥⌘2` / `⌥⌘3` | `Ctrl+Alt+1` / `2` / `3` |
| Сохранить как… | `⇧⌘S` | `Ctrl+Shift+S` |
| Обновить файл | `⌘R` | `Ctrl+R` |
| Крупнее / мельче | `⌘+` / `⌘-` | `Ctrl++` / `Ctrl+-` |

Подробнее — в [руководстве пользователя](docs/ru/usage.md).

## Приватность и безопасность

Grizzly работает полностью офлайн: без телеметрии, без сетевых запросов, без аккаунтов. Интерфейс Windows-версии
выполняется в изолированном (sandbox) процессе с context isolation и строгим Content-Security-Policy. О
уязвимостях сообщайте приватно — см. [SECURITY.md](SECURITY.md).

## Сборка из исходников

```bash
# macOS (достаточно Command Line Tools)
./scripts/build-app.sh && ./scripts/make-dmg.sh

# Windows-порт (Electron)
cd electron && npm ci && npm run dist
```

Подробности: [Сборка](docs/ru/building.md) · Устройство: [Архитектура](docs/ru/architecture.md).

## Участие в проекте

Issues и pull request’ы приветствуются — сначала прочитайте [CONTRIBUTING.md](CONTRIBUTING.md) и
[Кодекс поведения](CODE_OF_CONDUCT.md).

## Лицензия

[MIT](LICENSE) © 2026 Slipcast-dev
