import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        AppState.shared.startWatching()

        let paths = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-") }
        let urls = paths.map { URL(fileURLWithPath: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
        AppState.shared.openExternal(urls)
        // Let a file-open event that is already on its way land first, then open everything that was queued.
        DispatchQueue.main.async { AppState.shared.markReady() }
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
        WindowGroup("Grizzly") {
            ContentView()
                .environmentObject(state)
                .environmentObject(state.library)
                .environmentObject(settings)
                .frame(minWidth: 720, minHeight: 460)
                // Some macOS versions deliver Finder's open event to the scene instead of the app delegate.
                .onOpenURL { state.openExternal([$0]) }
        }
        .handlesExternalEvents(matching: ["*"])
        .windowToolbarStyle(.unified)
        Settings { SettingsView().environmentObject(settings) }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Открыть…") { state.presentOpenPanel() }
                    .keyboardShortcut("o")
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
            CommandMenu("Вид") {
                Button("Режим чтения") { state.mode = .reading }.keyboardShortcut("1", modifiers: [.command, .option])
                Button("Исходник") { state.mode = .source }.keyboardShortcut("2", modifiers: [.command, .option])
                Button("Правка") { state.mode = .edit }.keyboardShortcut("3", modifiers: [.command, .option])
                Divider()
                Button("Обновить файл") { if let id = state.current?.id { state.refresh(id) } }
                    .keyboardShortcut("r")
                Button("Крупнее") { settings.resizeFont(by: 1) }.keyboardShortcut("+")
                Button("Мельче") { settings.resizeFont(by: -1) }.keyboardShortcut("-")
            }
        }
    }
}
