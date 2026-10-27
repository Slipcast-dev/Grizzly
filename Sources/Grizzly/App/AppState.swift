import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum ReadMode: String { case source, reading, edit }
enum Pane { case left, right }

final class AppState: ObservableObject {
    static let shared = AppState()

    let library = LibraryStore()

    /// Open tabs, in order. Both panes pick their document from this list.
    @Published var documents: [Document] = []
    /// Document shown in the left (or only) pane.
    @Published var selection: UUID?
    /// Document shown in the right pane while split view is on.
    @Published var rightSelection: UUID?
    @Published var isSplit = false
    @Published var focusedPane: Pane = .left
    /// Library entry highlighted in the sidebar; follows the focused pane.
    @Published var selectedFileID: UUID?
    @Published var mode: ReadMode = .reading
    @Published var errorMessage: String?
    /// Open documents whose file changed on disk after they were read.
    @Published private(set) var changedOnDisk: Set<UUID> = []
    /// Edited text per open document, kept only while it differs from the file.
    @Published private(set) var drafts: [UUID: String] = [:]
    private var watcher: Timer?

    /// Polls open files once a second; called once the app has launched.
    func startWatching() {
        guard watcher == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.checkFiles() }
        RunLoop.main.add(timer, forMode: .common)
        watcher = timer
    }

    // Find
    @Published var isFindVisible = false
    @Published var findQuery = "" { didSet { recomputeMatches(reset: true) } }
    @Published private(set) var matches: [SearchMatch] = []
    @Published private(set) var matchIndex = 0
    @Published var findFocusToken = 0
    /// Asks the target pane to scroll a row into view (find hits and bookmarks).
    @Published var scrollTarget: ScrollTarget?

    func docID(in pane: Pane) -> UUID? { pane == .left ? selection : rightSelection }
    func doc(in pane: Pane) -> Document? { documents.first { $0.id == docID(in: pane) } }
    var current: Document? { doc(in: isSplit ? focusedPane : .left) }

    // MARK: Opening

    /// Opens files from disk (Open panel, drag and drop, Finder) and adds them to the library.
    func open(urls: [URL], inRight: Bool = false) {
        for url in urls {
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                importFolder(url)
                continue
            }
            let entry = library.add(url: url)
            show(entry.id, url: url, pane: inRight ? .right : nil)
        }
    }

    /// Opens a file that is already in the library (sidebar click).
    func openLibraryFile(_ id: UUID?, inRight: Bool = false) {
        guard let id, library.file(id) != nil else { return }
        let pane: Pane = inRight ? .right : (isSplit ? focusedPane : .left)

        if let existing = documents.first(where: { $0.libraryID == id }) {
            if docID(in: pane) != existing.id || focusedPane != pane { assign(existing.id, to: pane) }
            return
        }
        guard let url = library.resolve(id) else {
            let name = library.file(id)?.name ?? ""
            errorMessage = L("Файл «%@» не найден. Возможно, он перемещён или удалён.", name)
            return
        }
        show(id, url: url, pane: pane)
    }

    private func show(_ libraryID: UUID, url: URL, pane: Pane?) {
        let target = pane ?? (isSplit ? focusedPane : .left)

        if let existing = documents.first(where: { $0.libraryID == libraryID }) {
            assign(existing.id, to: target)
            library.markOpened(libraryID)
            return
        }
        do {
            var doc = try Document(url: url)
            doc.libraryID = libraryID
            documents.append(doc)
            assign(doc.id, to: target)
            library.markOpened(libraryID)
        } catch {
            errorMessage = L("Не удалось открыть «%@».", url.lastPathComponent)
        }
    }

    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = FileType.allExtensions.compactMap { UTType(filenameExtension: $0) }
        if panel.runModal() == .OK { open(urls: panel.urls) }
    }

    func presentFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { for url in panel.urls { importFolder(url) } }
    }

    /// Mirrors a directory into the library: its supported files (subfolders too) become entries in folders named after the directories.
    func importFolder(_ url: URL) {
        let root = library.folder(forDirectory: url, name: url.lastPathComponent)
        syncFolder(root.id, root: url)
    }

    /// Re-scans a folder that was added from disk and adds files that appeared since.
    func syncFolder(_ id: UUID, root: URL? = nil) {
        guard let rootURL = root ?? library.folderURL(id) else { return }
        let fm = FileManager.default
        let supported = Set(FileType.allExtensions)
        guard let walker = fm.enumerator(at: rootURL, includingPropertiesForKeys: [.isRegularFileKey],
                                         options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return }
        for case let file as URL in walker {
            guard supported.contains(file.pathExtension.lowercased()),
                  (try? file.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
            let dir = file.deletingLastPathComponent()
            let target = dir.standardizedFileURL == rootURL.standardizedFileURL
                ? id
                : library.folder(forDirectory: dir, name: dir.lastPathComponent).id
            let entry = library.add(url: file)
            if entry.folderID == nil { library.move(entry.id, to: target) }
        }
    }

    // MARK: File watching

    private func checkFiles() {
        for doc in documents where !changedOnDisk.contains(doc.id) {
            guard let now = Document.modificationDate(doc.url), now != doc.modified else { continue }
            // Never replace text the user is editing; offer the banner instead.
            if Preferences.shared.autoReload && drafts[doc.id] == nil { reload(doc.id) } else { changedOnDisk.insert(doc.id) }
        }
    }

    /// Re-reads a document from disk, keeping its tab, library entry and bookmarks.
    func reload(_ id: UUID) {
        guard let i = documents.firstIndex(where: { $0.id == id }) else { return }
        let old = documents[i]
        do {
            var fresh = try Document(url: old.url)
            fresh.id = old.id
            fresh.libraryID = old.libraryID
            documents[i] = fresh
            drafts[id] = nil
            changedOnDisk.remove(id)
            recomputeMatches(reset: false)
        } catch {
            changedOnDisk.remove(id)
            errorMessage = L("Не удалось обновить «%@».", old.name)
        }
    }

    /// User-initiated reload: asks first when it would throw away unsaved edits.
    func refresh(_ id: UUID) {
        if confirmDiscard([id]) { reload(id) }
    }

    /// Hides the banner until the file changes again.
    func ignoreChange(_ id: UUID) {
        guard let i = documents.firstIndex(where: { $0.id == id }) else { return }
        documents[i].modified = Document.modificationDate(documents[i].url)
        changedOnDisk.remove(id)
    }

    // MARK: Editing

    func isDirty(_ id: UUID) -> Bool { drafts[id] != nil }
    func text(for doc: Document) -> String { drafts[doc.id] ?? doc.normalized }

    func setDraft(_ text: String, for doc: Document) {
        let value: String? = text == doc.normalized ? nil : text
        if drafts[doc.id] != value { drafts[doc.id] = value }
    }

    func discardDraft(_ id: UUID) { drafts[id] = nil }

    /// Writes the edited text to the file in its original encoding, then re-reads it.
    @discardableResult
    func save(_ id: UUID) -> Bool {
        guard let doc = documents.first(where: { $0.id == id }), let draft = drafts[id] else { return true }
        let text = doc.text.contains("\r\n") ? draft.replacingOccurrences(of: "\n", with: "\r\n") : draft
        do {
            try FileLoader.write(text, to: doc.url, encoding: doc.encoding)
        } catch let error as CocoaError where error.code == .fileWriteInapplicableStringEncoding {
            errorMessage = L("Не удалось сохранить «%@»: в тексте есть символы, которых нет в кодировке %@.", doc.name, doc.encoding)
            return false
        } catch {
            errorMessage = L("Не удалось сохранить «%@».", doc.name)
            return false
        }
        reload(id)
        return drafts[id] == nil
    }

    /// Asks about every unsaved document among `ids`; false means the user cancelled.
    func confirmDiscard(_ ids: [UUID]) -> Bool {
        for id in ids {
            guard drafts[id] != nil, let doc = documents.first(where: { $0.id == id }) else { continue }
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = L("Сохранить изменения в «%@»?", doc.name)
            alert.informativeText = L("Изменения будут потеряны, если их не сохранить.")
            alert.addButton(withTitle: L("Сохранить"))
            alert.addButton(withTitle: L("Не сохранять"))
            alert.addButton(withTitle: L("Отмена"))
            switch alert.runModal() {
            case .alertFirstButtonReturn: if !save(id) { return false }
            case .alertSecondButtonReturn: break
            default: return false
            }
        }
        return true
    }

    // MARK: Find and bookmarks

    var currentMatch: SearchMatch? { matches.indices.contains(matchIndex) ? matches[matchIndex] : nil }

    func showFind() {
        isFindVisible = true
        findFocusToken += 1
        recomputeMatches(reset: false)
    }

    func hideFind() {
        isFindVisible = false
        matches = []
        matchIndex = 0
    }

    /// Hits are counted in the focused pane's document; every pane paints the same query.
    func recomputeMatches(reset: Bool) {
        guard isFindVisible, !findQuery.isEmpty, mode != .edit, let doc = current else {
            matches = []
            matchIndex = 0
            return
        }
        matches = Searcher.matches(query: findQuery, in: doc, mode: mode)
        matchIndex = reset ? 0 : min(matchIndex, max(0, matches.count - 1))
        revealCurrentMatch()
    }

    func stepMatch(_ delta: Int) {
        guard isFindVisible else { showFind(); return }
        guard !matches.isEmpty else { return }
        matchIndex = (matchIndex + delta + matches.count) % matches.count
        revealCurrentMatch()
    }

    private func revealCurrentMatch() {
        if let m = currentMatch { scrollTarget = ScrollTarget(unit: m.unit) }
    }

    /// Jumps to a bookmarked line (0-based) in the source view.
    func goToLine(_ line: Int) {
        mode = .source
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.scrollTarget = ScrollTarget(unit: line)
        }
    }

    // MARK: Tabs and panes

    func assign(_ docID: UUID, to pane: Pane) {
        if pane == .right {
            isSplit = true
            rightSelection = docID
        } else {
            selection = docID
        }
        focusedPane = pane
        selectedFileID = documents.first { $0.id == docID }?.libraryID
    }

    func selectTab(_ id: UUID, inRight: Bool = false) {
        assign(id, to: inRight ? .right : (isSplit ? focusedPane : .left))
    }

    func focus(_ pane: Pane) {
        guard isSplit, focusedPane != pane else { return }
        focusedPane = pane
        selectedFileID = current?.libraryID
    }

    func toggleSplit() {
        isSplit.toggle()
        if isSplit {
            if rightSelection == nil || doc(in: .right) == nil {
                rightSelection = documents.first { $0.id != selection }?.id
            }
        } else {
            focusedPane = .left
            selectedFileID = current?.libraryID
        }
    }

    func cycleTab(_ delta: Int) {
        guard documents.count > 1 else { return }
        let pane: Pane = isSplit ? focusedPane : .left
        let index = documents.firstIndex { $0.id == docID(in: pane) } ?? 0
        let next = (index + delta + documents.count) % documents.count
        assign(documents[next].id, to: pane)
    }

    @discardableResult
    func close(_ id: UUID) -> Bool {
        guard confirmDiscard([id]) else { return false }
        guard let i = documents.firstIndex(where: { $0.id == id }) else { return true }
        documents.remove(at: i)
        changedOnDisk.remove(id)
        drafts[id] = nil

        let neighbour = documents.indices.contains(i) ? documents[i].id : documents.last?.id
        if selection == id { selection = neighbour }
        if rightSelection == id { rightSelection = neighbour }

        if documents.isEmpty {
            isSplit = false
            focusedPane = .left
        }
        selectedFileID = current?.libraryID
        return true
    }

    func closeOthers(keeping id: UUID) {
        guard confirmDiscard(documents.map(\.id).filter { $0 != id }) else { return }
        drafts = drafts.filter { $0.key == id }
        documents.removeAll { $0.id != id }
        selection = id
        rightSelection = nil
        isSplit = false
        focusedPane = .left
        selectedFileID = current?.libraryID
    }

    /// Removes a file from the library (the file on disk stays) and closes it if open.
    func removeFromLibrary(_ id: UUID) {
        if let doc = documents.first(where: { $0.libraryID == id }), !close(doc.id) { return }
        library.remove(id)
    }
}
