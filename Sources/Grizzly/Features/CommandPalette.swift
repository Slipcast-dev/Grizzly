import SwiftUI

/// ⌘⇧P: one list for commands, open tabs, the headings of the open file and the files of the sidebar.
struct CommandPalette: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.theme) private var theme
    @State private var query = ""
    @State private var selected = 0
    @State private var monitor: Any?
    @FocusState private var focused: Bool

    struct Item: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let symbol: String
        let run: () -> Void
    }

    private var items: [Item] {
        var all: [Item] = []
        func cmd(_ title: String, _ symbol: String, _ run: @escaping () -> Void) { all.append(Item(title: title, detail: L("Команда"), symbol: symbol, run: run)) }
        cmd(L("Новый файл…"), "doc.badge.plus") { state.presentNewFilePanel() }
        cmd(L("Открыть…"), "folder") { state.presentOpenPanel() }
        if let doc = state.current {
            cmd(L("Сохранить"), "square.and.arrow.down") { state.save(doc.id) }
            cmd(L("Сохранить как…"), "square.and.arrow.down.on.square") { state.presentSaveAsPanel() }
            cmd(L("Найти…"), "magnifyingglass") { state.showFind() }
            cmd(L("Найти и заменить…"), "arrow.left.arrow.right") { state.isReplaceVisible = true; state.showFind() }
            cmd(L("Экспорт в HTML…"), "chevron.left.forwardslash.chevron.right") { state.exportHTML() }
            cmd(L("Экспорт в PDF…"), "doc.richtext") { state.exportPDF() }
            cmd(L("Закрыть вкладку"), "xmark") { state.close(doc.id) }
            cmd(L("Режим «Пользователь»"), "person") { state.mode = .user }
            cmd(L("Режим «Разработчик»"), "hammer") { state.mode = .developer }
            cmd(L("Два файла рядом"), "rectangle.split.2x1") { state.toggleSplit() }
            if state.changedOnDisk.contains(doc.id) {
                cmd(L("Сравнить с файлом на диске…"), "arrow.triangle.merge") { state.compareWithDisk(doc.id) }
            }
            for h in Outline.items(state.text(for: doc), type: doc.type) {
                all.append(Item(title: h.title, detail: L("Перейти · строка %d", h.line + 1), symbol: "number",
                                run: { state.scrollTarget = ScrollTarget(unit: h.line) }))
            }
        }
        cmd(L("Настройки…"), "gearshape") { SettingsOpener.show() }
        for d in state.documents {
            all.append(Item(title: d.name, detail: L("Открытая вкладка"), symbol: d.type.symbol, run: { state.assign(d.id, to: state.isSplit ? state.focusedPane : .left) }))
        }
        for f in library.allFiles {
            all.append(Item(title: f.name, detail: f.path, symbol: "doc.text", run: { state.open(urls: [URL(fileURLWithPath: f.path)]) }))
        }
        return all
    }

    private var results: [Item] {
        let words = query.lowercased().split { $0.isWhitespace }
        guard !words.isEmpty else { return Array(items.prefix(14)) }
        return Array(items.filter { item in
            let hay = (item.title + " " + item.detail).lowercased()
            return words.allSatisfy { hay.contains($0) }
        }.prefix(14))
    }

    var body: some View {
        let list = results
        VStack(spacing: 0) {
            TextField("Команда, вкладка, заголовок или файл", text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
                .padding(12)
                .focused($focused)
                .onSubmit { run(list) }
                .onExitCommand { state.paletteVisible = false }
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(list.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 10) {
                            Image(systemName: item.symbol).frame(width: 20).foregroundColor(theme.secondary)
                            Text(item.title).lineLimit(1)
                            Spacer()
                            Text(item.detail).font(AppFont.caption).foregroundColor(theme.secondary).lineLimit(1)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(index == min(selected, list.count - 1) ? theme.match.opacity(0.5) : .clear)
                        .contentShape(Rectangle())
                        .onTapGesture { selected = index; run(list) }
                    }
                }
            }
            .frame(maxHeight: 340)
        }
        .frame(width: 560)
        .background(.regularMaterial)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.15)))
        .shadow(radius: 24)
        .onAppear {
            focused = true
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                switch event.keyCode {
                case 125: selected = min(selected + 1, max(0, results.count - 1)); return nil
                case 126: selected = max(selected - 1, 0); return nil
                default: return event
                }
            }
        }
        .onDisappear { if let monitor { NSEvent.removeMonitor(monitor) } }
        .onChange(of: query) { _ in selected = 0 }
    }

    private func run(_ list: [Item]) {
        guard !list.isEmpty else { return }
        let item = list[min(selected, list.count - 1)]
        state.paletteVisible = false
        DispatchQueue.main.async { item.run() }
    }
}
