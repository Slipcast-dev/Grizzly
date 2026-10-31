import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        AppState.shared.startWatching()
        AppState.shared.scanTagsInLibrary()
        // Every launch asks GitHub whether a newer version is out; the answer appears only if there is one.
        Task { await UpdateManager.shared.check(silent: true) }

        let paths = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-") }
        let urls = paths.map { URL(fileURLWithPath: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
        AppState.shared.openExternal(urls)
        // Let a file-open event that is already on its way land first, then open everything that was queued.
        DispatchQueue.main.async { AppState.shared.markReady() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppState.shared.library.flush()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let state = AppState.shared
        return state.confirmDiscard(state.documents.map(\.id)) ? .terminateNow : .terminateCancel
    }

    /// Finder (double click, "Open With"), the Dock and `open -a` deliver files here, also while the app is launching.
    func application(_ application: NSApplication, open urls: [URL]) {
        AppState.shared.openExternal(urls)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Clicking the Dock icon after the last window was closed brings a window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { true }

    /// One window is enough: a file opened from Finder becomes a tab instead of a second window.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct GrizzlyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var state = AppState.shared
    @StateObject private var settings = Preferences.shared

    var body: some Scene {
        // A single window: files opened while the app runs become tabs, never a second window.
        Window("Grizzly", id: "main") {
            ContentView()
                .background(CloseGuard())
                .environmentObject(state)
                .environmentObject(state.library)
                .environmentObject(settings)
                .frame(minWidth: 720, minHeight: 460)
                // Some macOS versions deliver Finder's open event to the scene instead of the app delegate.
                .onOpenURL { state.openExternal([$0]) }
        }
        .windowToolbarStyle(.unified)
        Settings { SettingsView().environmentObject(settings) }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Новый файл…") { state.presentNewFilePanel() }
                    .keyboardShortcut("n")
                Button("Открыть…") { state.presentOpenPanel() }
                    .keyboardShortcut("o")
                Button("Добавить папку с диска…") { state.presentFolderPanel() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Button("Сохранить") { if let id = state.current?.id { state.save(id) } }
                    .keyboardShortcut("s")
                    .disabled(!(state.current.map { state.isDirty($0.id) } ?? false))
                Button("Сохранить как…") { state.presentSaveAsPanel() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(state.current == nil)
                Button("Закрыть вкладку") {
                    if let id = state.current?.id { state.close(id) }
                }
                .keyboardShortcut("w")
            }
            CommandMenu("Поиск") {
                Button("Найти…") { state.showFind() }
                    .keyboardShortcut("f")
                Button("Найти далее") { state.stepMatch(1) }
                    .keyboardShortcut("g")
                Button("Найти ранее") { state.stepMatch(-1) }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
            }
            CommandMenu("Вкладки") {
                Button("Следующая вкладка") { state.cycleTab(1) }
                    .keyboardShortcut("]", modifiers: [.command, .shift])
                Button("Предыдущая вкладка") { state.cycleTab(-1) }
                    .keyboardShortcut("[", modifiers: [.command, .shift])
                Divider()
                Button("Два файла рядом") { state.toggleSplit() }
                    .keyboardShortcut("\\")
            }
            CommandMenu("Формат") {
                Group {
                    Button("Название") { FormatActions.perform(.paragraph(.title)) }
                        .keyboardShortcut("t", modifiers: [.command, .shift])
                    Button("Заголовок") { FormatActions.perform(.paragraph(.heading)) }
                        .keyboardShortcut("h", modifiers: [.command, .shift])
                    Button("Подзаголовок") { FormatActions.perform(.paragraph(.subheading)) }
                        .keyboardShortcut("j", modifiers: [.command, .shift])
                    Button("Основной текст") { FormatActions.perform(.paragraph(.body)) }
                        .keyboardShortcut("b", modifiers: [.command, .shift])
                    Button("Моноширинный") { FormatActions.perform(.paragraph(.monospaced)) }
                        .keyboardShortcut("m", modifiers: [.command, .shift])
                    Divider()
                    Button("Жирный") { FormatActions.perform(.inline(.bold)) }.keyboardShortcut("b")
                    Button("Курсив") { FormatActions.perform(.inline(.italic)) }.keyboardShortcut("i")
                    Button("Подчёркнутый") { FormatActions.perform(.inline(.underline)) }.keyboardShortcut("u")
                    Button("Зачёркнутый") { FormatActions.perform(.inline(.strike)) }
                        .keyboardShortcut("x", modifiers: [.command, .shift])
                    Menu("Цветной маркер") {
                        ForEach(InlineMarkup.highlightNames, id: \.self) { name in
                            Button(FormatBar.colorTitle(name)) { FormatActions.perform(.highlight(name)) }
                        }
                        Divider()
                        Button("Без выделения") { FormatActions.perform(.highlight(nil)) }
                    }
                    Menu("Выравнивание") {
                        Button("По левому краю") { FormatActions.perform(.align(.left)) }
                        Button("По центру") { FormatActions.perform(.align(.center)) }
                        Button("По правому краю") { FormatActions.perform(.align(.right)) }
                        Button("По ширине") { FormatActions.perform(.align(.justify)) }
                    }
                    Divider()
                    Button("Маркированный список") { FormatActions.perform(.list(.bullet)) }
                        .keyboardShortcut("7", modifiers: [.command, .shift])
                    Button("Штриховой список") { FormatActions.perform(.list(.dash)) }
                        .keyboardShortcut("8", modifiers: [.command, .shift])
                    Button("Нумерованный список") { FormatActions.perform(.list(.numbered)) }
                        .keyboardShortcut("9", modifiers: [.command, .shift])
                    Button("Список задач") { FormatActions.perform(.list(.checklist)) }
                        .keyboardShortcut("l", modifiers: [.command, .shift])
                    Button("Цитата") { FormatActions.perform(.quote) }.keyboardShortcut("'")
                    Button("Линия-разделитель") { FormatActions.perform(.rule) }
                    Button("Вставить таблицу") { FormatActions.perform(.table(.insert)) }
                        .keyboardShortcut("t", modifiers: [.command, .option])
                    Menu("Вставить") {
                    Button("Фото…") { FormatActions.attach(.image) }
                    Button("Видео…") { FormatActions.attach(.video) }
                    Button("PDF…") { FormatActions.attach(.pdf) }
                    Button("Файл…") { FormatActions.attach(.file) }
                    Divider()
                    Button("Ссылка на сайт…") { FormatActions.insertWebLink() }
                }
                Menu("Таблица") {
                        Button("Добавить строку") { FormatActions.perform(.table(.addRow)) }
                        Button("Добавить столбец") { FormatActions.perform(.table(.addColumn)) }
                        Button("Удалить строку") { FormatActions.perform(.table(.deleteRow)) }
                        Button("Удалить столбец") { FormatActions.perform(.table(.deleteColumn)) }
                        Divider()
                        Button("Строку вверх") { FormatActions.perform(.table(.moveRowUp)) }
                        Button("Строку вниз") { FormatActions.perform(.table(.moveRowDown)) }
                        Button("Столбец влево") { FormatActions.perform(.table(.moveColumnLeft)) }
                        Button("Столбец вправо") { FormatActions.perform(.table(.moveColumnRight)) }
                        Divider()
                        Button("Преобразовать таблицу в текст") { FormatActions.perform(.table(.toText)) }
                    }
                }
                .disabled(state.current?.type != .markdown)
            }
            CommandMenu("Вид") {
                Button("Пользователь") { state.mode = .user }.keyboardShortcut("1", modifiers: [.command, .option])
                Button("Разработчик") { state.mode = .developer }.keyboardShortcut("2", modifiers: [.command, .option])
                Divider()
                Button("Копировать весь текст") { state.copyAllText() }
                    .keyboardShortcut("c", modifiers: [.command, .option])
                    .disabled(state.current == nil)
                Button("Обновить файл") { if let id = state.current?.id { state.refresh(id) } }
                    .keyboardShortcut("r")
                Button("Крупнее") { settings.resizeFont(by: 1) }.keyboardShortcut("+")
                Button("Мельче") { settings.resizeFont(by: -1) }.keyboardShortcut("-")
            }
        }
    }
}

/// Changing the language needs a relaunch: menus and system strings are bound to the language at launch.
enum AppRestart {
    static func offer() {
        let alert = NSAlert()
        alert.messageText = L("Чтобы сменить язык, нужно перезапустить Grizzly.")
        alert.informativeText = L("Перед выходом предложим сохранить несохранённые изменения.")
        alert.addButton(withTitle: L("Перезапустить"))
        alert.addButton(withTitle: L("Позже"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", path]
        try? task.run()
        NSApp.terminate(nil)
    }
}


/// Asks about unsaved edits when the window's close button is pressed, then closes it.
struct CloseGuard: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window, !(window.delegate is CloseGuardDelegate) else { return }
            let guardian = CloseGuardDelegate(original: window.delegate)
            context.coordinator.delegate = guardian
            window.delegate = guardian
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
    func makeCoordinator() -> Holder { Holder() }
    final class Holder { var delegate: CloseGuardDelegate? }
}

/// Wraps the window's own delegate (SwiftUI's) and only adds the unsaved-changes question.
final class CloseGuardDelegate: NSObject, NSWindowDelegate {
    private weak var original: NSWindowDelegate?
    init(original: NSWindowDelegate?) { self.original = original }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard AppState.shared.confirmCloseWindow() else { return false }
        return original?.windowShouldClose?(sender) ?? true
    }

    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || (original?.responds(to: selector) ?? false)
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        original?.responds(to: selector) == true ? original : super.forwardingTarget(for: selector)
    }
}
