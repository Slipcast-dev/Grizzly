import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var prefs: Preferences
    @ObservedObject private var updater = UpdateManager.shared

    var body: some View {
        let theme = prefs.theme

        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 190, ideal: 230, max: 320)
        } detail: {
            DetailView(fontSize: CGFloat(prefs.fontSize))
                .background(theme.background)
        }
        .background(WindowFrameSaver(name: "GrizzlyMainWindow"))
        .navigationTitle(state.current?.name ?? "Grizzly")
        .toolbar {
            // The view mode switch sits in the middle of the title bar; everything else for the current file is on the right.
            ToolbarItem(placement: .principal) {
                Picker("Режим", selection: $state.mode) {
                    Text("Чтение").tag(ReadMode.reading)
                    Text("Исходник").tag(ReadMode.source)
                    Text("Правка").tag(ReadMode.edit)
                }
                .pickerStyle(.segmented)
                .frame(width: 270)
                .help("Режим просмотра")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button { state.toggleSplit() } label: {
                    Image(systemName: state.isSplit ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
                }
                .buttonStyle(.hover)
                .help("Два файла рядом (⌘\\)")
                .disabled(state.documents.isEmpty)

                Button { state.showFind() } label: { Image(systemName: "magnifyingglass") }
                    .buttonStyle(.hover)
                    .help("Найти (⌘F)")
                    .disabled(state.documents.isEmpty)

                BookmarksButton()

                Button { prefs.resizeFont(by: -1) } label: { Image(systemName: "textformat.size.smaller") }
                    .buttonStyle(.hover)
                    .help("Уменьшить текст")
                Button { prefs.resizeFont(by: 1) } label: { Image(systemName: "textformat.size.larger") }
                    .buttonStyle(.hover)
                    .help("Увеличить текст")
                // Rightmost: the system emoji picker, for the text being edited.
                Button { NSApp.orderFrontCharacterPalette(nil) } label: { Text("😀") }
                    .buttonStyle(.hover)
                    .help("Эмодзи и символы (⌃⌘Пробел)")
                    .disabled(state.mode != .edit || state.documents.isEmpty)
            }
        }
        .environment(\.theme, theme)
        .preferredColorScheme(theme.isDark ? .dark : .light)
        .onChange(of: state.mode) { _ in
            state.recomputeMatches(reset: false)
        }
        .onChange(of: state.current?.id) { _ in
            state.recomputeMatches(reset: true)
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    DispatchQueue.main.async { state.open(urls: [url]) }
                }
            }
            return true
        }
        .overlay(alignment: .bottom) {
            if let toast = state.toast {
                ToastView(toast: toast)
                    .padding(.bottom, 46)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.2), value: state.toast?.id)
        .sheet(isPresented: $updater.sheetVisible) { UpdateSheet(updater: updater) }
        .alert("Ошибка", isPresented: Binding(
            get: { state.errorMessage != nil },
            set: { if !$0 { state.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(state.errorMessage ?? "")
        }
    }
}

struct DetailView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.theme) private var theme
    let fontSize: CGFloat

    var body: some View {
        if state.documents.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(theme.secondary)
                Text("Откройте файл")
                    .font(.title3)
                Text("Перетащите Markdown или текстовый файл в окно\nили нажмите ⌘O.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(theme.secondary)
                Button("Открыть…") { state.presentOpenPanel() }
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                TabBar()
                if state.isFindVisible { FindBar() }
                HStack(spacing: 0) {
                    PaneView(pane: .left, fontSize: fontSize)
                    if state.isSplit {
                        Divider()
                        PaneView(pane: .right, fontSize: fontSize)
                    }
                }
            }
        }
    }
}

/// Remembers the window's size and position between launches (AppKit stores it under `name`).
struct WindowFrameSaver: NSViewRepresentable {
    let name: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { view.window?.setFrameAutosaveName(name) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}

/// A small rounded notification near the bottom of the window.
struct ToastView: View {
    let toast: Toast
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.symbol).foregroundColor(theme.accent)
            Text(toast.text).font(.callout).lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.12)))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
        .frame(maxWidth: 520)
    }
}
