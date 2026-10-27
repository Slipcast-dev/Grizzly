import QuickLook
import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case files, recent, favorites
    var id: String { rawValue }

    var title: String {
        switch self {
        case .files: return L("Файлы")
        case .recent: return L("Недавние")
        case .favorites: return L("Избранное")
        }
    }

    var symbol: String {
        switch self {
        case .files: return "folder"
        case .recent: return "clock"
        case .favorites: return "star"
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var library: LibraryStore
    @AppStorage("sidebarSection") private var section: SidebarSection = .files

    @State private var query = ""
    @State private var isNaming = false
    @State private var newName = ""
    @State private var nameError: String?
    @State private var pendingMove: UUID?
    @State private var renamingID: UUID?
    @State private var renameText = ""
    @State private var targetedFolder: UUID?
    @FocusState private var nameFocused: Bool
    @State private var previewURL: URL?
    @State private var spaceMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            Picker("Раздел", selection: $section) {
                ForEach(SidebarSection.allCases) { s in
                    Image(systemName: s.symbol).help(s.title).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.top, 8)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Фильтр файлов", text: $query)
                    .textFieldStyle(.plain)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.07)))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            List(selection: $state.selectedFileID) {
                switch section {
                case .files: filesContent
                case .recent: recentContent
                case .favorites: favoritesContent
                }
            }
            .listStyle(.sidebar)
            .dropDestination(for: String.self) { items, _ in
                guard section == .files else { return false }
                return drop(items, into: nil)
            }
            .overlay { emptyState }
        }
        .onChange(of: state.selectedFileID) { id in
            // Option-click opens the file in the right pane.
            state.openLibraryFile(id, inRight: NSEvent.modifierFlags.contains(.option))
        }
        .onChange(of: section) { _ in cancelNaming() }
        .quickLookPreview($previewURL)
        .onAppear(perform: installSpaceMonitor)
        .onDisappear(perform: removeSpaceMonitor)
    }

    // MARK: Sections

    @ViewBuilder
    private var filesContent: some View {
        Section {
            if isNaming { nameField }
            ForEach(visibleFolders) { folder in folderRow(folder) }
            ForEach(filtered(library.files(in: nil))) { file in fileRow(file) }
        } header: {
            HStack {
                Text("Файлы")
                Spacer()
                Button {
                    pendingMove = nil
                    beginNaming()
                } label: { Image(systemName: "folder.badge.plus") }
                .buttonStyle(.borderless)
                .help("Новая папка")
            }
        }
    }

    @ViewBuilder
    private var recentContent: some View {
        let items = filtered(library.recents)
        if !items.isEmpty {
            Section {
                ForEach(items) { file in fileRow(file, showsDate: true) }
            } header: {
                HStack {
                    Text("Недавно открытые")
                    Spacer()
                    Button("Очистить") { library.clearRecents() }
                        .buttonStyle(.borderless)
                }
            }
        }
    }

    @ViewBuilder
    private var favoritesContent: some View {
        let items = filtered(library.favorites)
        if !items.isEmpty {
            Section("Избранное") {
                ForEach(items) { file in fileRow(file) }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch section {
        case .files where library.folders.isEmpty && library.files(in: nil).isEmpty && !isNaming:
            hint("doc.badge.plus", "Откройте файл (⌘O) или перетащите его в окно.")
        case .recent where library.recents.isEmpty:
            hint("clock", "Здесь появятся файлы, которые вы открывали.")
        case .favorites where library.favorites.isEmpty:
            hint("star", "Добавьте файл в избранное через контекстное меню.")
        default:
            EmptyView()
        }
    }

    private func hint(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 26, weight: .light))
            Text(text).multilineTextAlignment(.center).font(.callout)
        }
        .foregroundColor(.secondary)
        .padding(24)
    }

    // MARK: Rows

    private var visibleFolders: [LibraryFolder] {
        guard !query.isEmpty else { return library.folders }
        return library.folders.filter { !filtered(library.files(in: $0.id)).isEmpty }
    }

    private func filtered(_ files: [LibraryFile]) -> [LibraryFile] {
        query.isEmpty ? files : files.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private func folderRow(_ folder: LibraryFolder) -> some View {
        let files = filtered(library.files(in: folder.id))
        return DisclosureGroup(
            isExpanded: Binding(
                get: { folder.isExpanded },
                set: { library.setExpanded(folder.id, $0) })
        ) {
            ForEach(files) { file in fileRow(file) }
            if files.isEmpty && query.isEmpty {
                Text("Пусто. Перетащите сюда файл.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } label: {
            folderLabel(folder, count: files.count)
        }
        .contextMenu {
            Button("Переименовать") {
                renameText = folder.name
                renamingID = folder.id
                nameFocused = true
            }
            Button("Показать в Finder") {
                if let url = library.folderURL(folder.id) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
            .disabled(library.folderURL(folder.id) == nil)
            Button("Обновить из папки") { state.syncFolder(folder.id) }
                .disabled(library.folderURL(folder.id) == nil)
            Button("Удалить папку", role: .destructive) { library.deleteFolder(folder.id) }
        }
    }

    @ViewBuilder
    private func folderLabel(_ folder: LibraryFolder, count: Int) -> some View {
        if renamingID == folder.id {
            TextField("Название", text: $renameText)
                .focused($nameFocused)
                .onSubmit { commitRename(folder) }
                .onExitCommand { renamingID = nil }
        } else {
            HStack {
                Label(folder.name, systemImage: "folder").lineLimit(1)
                Spacer()
                Text("\(count)").font(.caption).foregroundColor(.secondary)
            }
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(targetedFolder == folder.id ? Color.accentColor.opacity(0.28) : .clear)
            )
            .contentShape(Rectangle())
            .dropDestination(for: String.self) { items, _ in
                drop(items, into: folder.id)
            } isTargeted: { targeted in
                targetedFolder = targeted ? folder.id : (targetedFolder == folder.id ? nil : targetedFolder)
            }
        }
    }

    private func fileRow(_ file: LibraryFile, showsDate: Bool = false) -> some View {
        let isMissing = library.isMissing(file.id)
        return HStack(spacing: 6) {
            Image(systemName: isMissing ? "exclamationmark.triangle" : file.type.symbol)
                .foregroundColor(isMissing ? .orange : .secondary)
            Text(file.name)
                .lineLimit(1)
                .foregroundColor(isMissing ? .secondary : .primary)
            Spacer(minLength: 4)
            if showsDate, let date = file.lastOpened {
                Text(relative(date)).font(.caption).foregroundColor(.secondary)
            }
            if file.isFavorite {
                Image(systemName: "star.fill").font(.caption).foregroundColor(.yellow)
            }
        }
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .tag(file.id)
        .draggable(file.id.uuidString)
        // Hit-testing of a draggable row is flaky near its edges; handle the click on the whole row ourselves.
        .simultaneousGesture(TapGesture().onEnded {
            let inRight = NSEvent.modifierFlags.contains(.option)
            if state.selectedFileID == file.id {
                state.openLibraryFile(file.id, inRight: inRight)
            } else {
                state.selectedFileID = file.id
            }
        })
        .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
        .contextMenu { fileMenu(file) }
    }

    @ViewBuilder
    private func fileMenu(_ file: LibraryFile) -> some View {
        Button("Открыть") { state.openLibraryFile(file.id) }
        Button("Открыть справа") { state.openLibraryFile(file.id, inRight: true) }
        Button("Быстрый просмотр") { quickLook(file.id) }
        Button(LocalizedStringKey(file.isFavorite ? "Убрать из избранного" : "Добавить в избранное")) {
            library.toggleFavorite(file.id)
        }
        Menu("Переместить в…") {
            ForEach(library.folders) { folder in
                Button(folder.name) { library.move(file.id, to: folder.id) }
                    .disabled(file.folderID == folder.id)
            }
            if file.folderID != nil {
                Divider()
                Button("Вне папки") { library.move(file.id, to: nil) }
            }
            Divider()
            Button("Новая папка…") {
                section = .files
                pendingMove = file.id
                beginNaming()
            }
        }
        Divider()
        Button("Показать в Finder") {
            if let url = library.resolve(file.id) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        }
        Button("Убрать из библиотеки", role: .destructive) { state.removeFromLibrary(file.id) }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "folder").foregroundColor(.accentColor)
                TextField("Название папки", text: $newName)
                    .focused($nameFocused)
                    .onSubmit(commitNew)
                    .onExitCommand(perform: cancelNaming)
            }
            if let nameError {
                Text(nameError).font(.caption).foregroundColor(.red)
            }
        }
    }

    // MARK: Quick Look

    /// Previews the file in the system Quick Look panel without opening it in a tab.
    private func quickLook(_ id: UUID?) {
        guard let id, library.file(id) != nil else { return }
        guard let url = library.resolve(id) else {
            state.errorMessage = L("Файл «%@» не найден. Возможно, он перемещён или удалён.", library.file(id)?.name ?? "")
            return
        }
        previewURL = url
    }

    /// Space previews the selected sidebar file, unless text is being typed somewhere.
    private func installSpaceMonitor() {
        guard spaceMonitor == nil else { return }
        spaceMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == 49,
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty,
                  !(NSApp.keyWindow?.firstResponder is NSText),
                  NSApp.keyWindow?.identifier?.rawValue.contains("QLPreview") != true,
                  state.selectedFileID != nil else { return event }
            if previewURL != nil { previewURL = nil } else { quickLook(state.selectedFileID) }
            return nil
        }
    }

    private func removeSpaceMonitor() {
        if let spaceMonitor { NSEvent.removeMonitor(spaceMonitor) }
        spaceMonitor = nil
    }

    // MARK: Actions

    private func beginNaming() {
        newName = ""
        nameError = nil
        isNaming = true
        DispatchQueue.main.async { nameFocused = true }
    }

    private func cancelNaming() {
        isNaming = false
        newName = ""
        nameError = nil
        pendingMove = nil
    }

    private func commitNew() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { cancelNaming(); return }
        guard !library.folderExists(name) else {
            nameError = L("Папка с таким именем уже есть.")
            return
        }
        let folder = library.createFolder(name)
        if let pendingMove { library.move(pendingMove, to: folder.id) }
        cancelNaming()
    }

    private func commitRename(_ folder: LibraryFolder) {
        let name = renameText.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty, name != folder.name, !library.folderExists(name) {
            library.renameFolder(folder.id, to: name)
        }
        renamingID = nil
    }

    private func drop(_ items: [String], into folderID: UUID?) -> Bool {
        var moved = false
        for item in items {
            if let id = UUID(uuidString: item), library.file(id) != nil {
                library.move(id, to: folderID)
                moved = true
            }
        }
        return moved
    }

    private func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}
