import Foundation

struct LibraryFile: Identifiable, Codable, Hashable {
    var id = UUID()
    var bookmark: Data
    var path: String
    var name: String
    var folderID: UUID?
    var isFavorite = false
    var lastOpened: Date?
    /// 1-based line numbers the reader has bookmarked.
    var bookmarks: [Int] = []
    var tags: [String] = []

    var type: FileType { FileType(url: URL(fileURLWithPath: path)) }

    enum CodingKeys: String, CodingKey {
        case id, bookmark, path, name, folderID, isFavorite, lastOpened, bookmarks, tags
    }
}

extension LibraryFile {
    // Written by hand so libraries saved before bookmarks existed still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        bookmark = try c.decode(Data.self, forKey: .bookmark)
        path = try c.decode(String.self, forKey: .path)
        name = try c.decode(String.self, forKey: .name)
        folderID = try c.decodeIfPresent(UUID.self, forKey: .folderID)
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        lastOpened = try c.decodeIfPresent(Date.self, forKey: .lastOpened)
        bookmarks = try c.decodeIfPresent([Int].self, forKey: .bookmarks) ?? []
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
}

struct LibraryFolder: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var isExpanded = true
    /// Directory on disk this folder mirrors; nil for a purely virtual folder.
    var sourcePath: String?
}

/// A file the reader opened. Lives apart from the library, so removing a file from the sidebar keeps its history.
struct HistoryEntry: Identifiable, Codable, Hashable {
    var path: String
    var name: String
    var bookmark: Data
    var date: Date

    var id: String { path }
    var type: FileType { FileType(url: URL(fileURLWithPath: path)) }
}

private struct LibraryData: Codable {
    var files: [LibraryFile] = []
    var folders: [LibraryFolder] = []
    var history: [HistoryEntry] = []
    /// Tags created by the user, also those no file carries yet.
    var tags: [String] = []

    enum CodingKeys: String, CodingKey { case files, folders, history, tags }

    init() {}

    // Libraries saved before the history existed have no "history" key.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        files = try c.decodeIfPresent([LibraryFile].self, forKey: .files) ?? []
        folders = try c.decodeIfPresent([LibraryFolder].self, forKey: .folders) ?? []
        history = try c.decodeIfPresent([HistoryEntry].self, forKey: .history) ?? []
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        // First launch with a history: seed it from the "last opened" dates of the library files.
        if history.isEmpty {
            history = files.compactMap { f in
                f.lastOpened.map { HistoryEntry(path: f.path, name: f.name, bookmark: f.bookmark, date: $0) }
            }.sorted { $0.date > $1.date }
        }
    }
}

/// Virtual library: files stay where they are on disk, folders only group references to them.
final class LibraryStore: ObservableObject {
    static let recentLimit = 20
    /// More is stored than shown, so clearing the oldest entries never happens by surprise.
    static let historyStored = 200

    @Published private var data = LibraryData()
    @Published private(set) var missing: Set<UUID> = []

    private let storeURL: URL

    init(storeURL: URL? = nil) {
        if let storeURL {
            self.storeURL = storeURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let base = support.appendingPathComponent("Grizzly", isDirectory: true)
            // The app used to be called MD Reader: carry its library over once.
            let old = support.appendingPathComponent("MDReader", isDirectory: true)
            if !FileManager.default.fileExists(atPath: base.path), FileManager.default.fileExists(atPath: old.path) {
                try? FileManager.default.moveItem(at: old, to: base)
            }
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            self.storeURL = base.appendingPathComponent("library.json")
        }
        load()
        refreshMissing()
    }

    // MARK: Queries

    var folders: [LibraryFolder] {
        data.folders.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func file(_ id: UUID) -> LibraryFile? { data.files.first { $0.id == id } }

    func files(in folderID: UUID?) -> [LibraryFile] {
        data.files
            .filter { $0.folderID == folderID }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Opened files, newest first, whether or not they are still in the library.
    var recents: [HistoryEntry] {
        Array(data.history.sorted { $0.date > $1.date }.prefix(Self.recentLimit))
    }

    func file(atPath path: String) -> LibraryFile? { data.files.first { $0.path == path } }

    var favorites: [LibraryFile] {
        data.files
            .filter(\.isFavorite)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func folderExists(_ name: String) -> Bool {
        data.folders.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    func isMissing(_ id: UUID) -> Bool { missing.contains(id) }

    // MARK: Files

    @discardableResult
    func add(url: URL) -> LibraryFile {
        let path = url.standardizedFileURL.path
        if let existing = data.files.first(where: { $0.path == path }) { return existing }
        let bookmark = (try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)) ?? Data()
        let entry = LibraryFile(bookmark: bookmark, path: path, name: url.lastPathComponent)
        mutate { $0.files.append(entry) }
        return entry
    }

    /// Finds the file on disk, following moves and renames through the bookmark. Nil if it is gone.
    func resolve(_ id: UUID) -> URL? {
        guard let entry = file(id) else { return nil }
        let fm = FileManager.default

        var stale = false
        if !entry.bookmark.isEmpty,
           let url = try? URL(resolvingBookmarkData: entry.bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale),
           fm.fileExists(atPath: url.path) {
            if stale || url.path != entry.path { refresh(id, url: url) }
            setMissing(id, false)
            return url
        }
        if fm.fileExists(atPath: entry.path) {
            setMissing(id, false)
            return URL(fileURLWithPath: entry.path)
        }
        setMissing(id, true)
        return nil
    }

    /// Puts a file at the top of the history (once per path).
    func recordOpened(_ url: URL) {
        let path = url.standardizedFileURL.path
        let bookmark = (try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)) ?? Data()
        mutate { d in
            d.history.removeAll { $0.path == path }
            d.history.append(HistoryEntry(path: path, name: url.lastPathComponent, bookmark: bookmark, date: Date()))
            if d.history.count > Self.historyStored {
                d.history = Array(d.history.sorted { $0.date > $1.date }.prefix(Self.historyStored))
            }
            if let i = d.files.firstIndex(where: { $0.path == path }) { d.files[i].lastOpened = Date() }
        }
    }

    /// Finds a history file on disk, following moves and renames through the bookmark.
    func resolve(_ entry: HistoryEntry) -> URL? {
        let fm = FileManager.default
        var stale = false
        if !entry.bookmark.isEmpty,
           let url = try? URL(resolvingBookmarkData: entry.bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale),
           fm.fileExists(atPath: url.path) { return url }
        return fm.fileExists(atPath: entry.path) ? URL(fileURLWithPath: entry.path) : nil
    }

    func isMissing(_ entry: HistoryEntry) -> Bool { resolve(entry) == nil }

    func removeFromHistory(_ path: String) {
        mutate { $0.history.removeAll { $0.path == path } }
    }

    func clearRecents() {
        mutate { d in
            d.history = []
            for i in d.files.indices { d.files[i].lastOpened = nil }
        }
    }

    func toggleFavorite(_ id: UUID) {
        mutate { d in
            if let i = d.files.firstIndex(where: { $0.id == id }) { d.files[i].isFavorite.toggle() }
        }
    }

    func bookmarks(for id: UUID?) -> [Int] {
        guard let id else { return [] }
        return file(id)?.bookmarks ?? []
    }

    func toggleBookmark(_ id: UUID?, line: Int) {
        guard let id else { return }
        mutate { d in
            guard let i = d.files.firstIndex(where: { $0.id == id }) else { return }
            if let at = d.files[i].bookmarks.firstIndex(of: line) {
                d.files[i].bookmarks.remove(at: at)
            } else {
                d.files[i].bookmarks.append(line)
                d.files[i].bookmarks.sort()
            }
        }
    }

    /// Removes the reference only; the file on disk is never touched.
    func remove(_ id: UUID) {
        mutate { $0.files.removeAll { $0.id == id } }
        missing.remove(id)
    }

    func move(_ fileID: UUID, to folderID: UUID?) {
        mutate { d in
            guard let i = d.files.firstIndex(where: { $0.id == fileID }), d.files[i].folderID != folderID else { return }
            d.files[i].folderID = folderID
            if let folderID, let f = d.folders.firstIndex(where: { $0.id == folderID }) {
                d.folders[f].isExpanded = true
            }
        }
    }

    // MARK: Tags

    /// Tag text as stored: trimmed, without a leading "#".
    static func cleanTag(_ raw: String) -> String {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while t.hasPrefix("#") { t.removeFirst() }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Every known tag, alphabetically: the ones created by the user plus any a file still carries.
    var allTags: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for tag in data.tags + data.files.flatMap(\.tags) where seen.insert(tag.lowercased()).inserted { result.append(tag) }
        return result.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    func files(withTag tag: String) -> [LibraryFile] {
        data.files
            .filter { $0.tags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame } }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func tagExists(_ tag: String) -> Bool { allTags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame } }

    /// Creates a tag (and returns its stored spelling); an existing tag is returned as it is. Nil for an empty name.
    @discardableResult
    func createTag(_ raw: String) -> String? {
        let tag = Self.cleanTag(raw)
        guard !tag.isEmpty else { return nil }
        if let existing = allTags.first(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) { return existing }
        mutate { $0.tags.append(tag) }
        return tag
    }

    func hasTag(_ fileID: UUID, _ tag: String) -> Bool {
        file(fileID)?.tags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame } ?? false
    }

    func toggleTag(_ fileID: UUID, _ tag: String) {
        mutate { d in
            guard let i = d.files.firstIndex(where: { $0.id == fileID }) else { return }
            if let at = d.files[i].tags.firstIndex(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
                d.files[i].tags.remove(at: at)
            } else {
                d.files[i].tags.append(tag)
            }
        }
    }

    func renameTag(_ old: String, to raw: String) {
        let new = Self.cleanTag(raw)
        guard !new.isEmpty else { return }
        func swap(_ list: inout [String]) {
            var out: [String] = []
            for t in list {
                let value = t.caseInsensitiveCompare(old) == .orderedSame ? new : t
                if !out.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) { out.append(value) }
            }
            list = out
        }
        mutate { d in
            swap(&d.tags)
            for i in d.files.indices { swap(&d.files[i].tags) }
        }
    }

    func deleteTag(_ tag: String) {
        mutate { d in
            d.tags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
            for i in d.files.indices { d.files[i].tags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame } }
        }
    }

    // MARK: Folders

    func folderURL(_ id: UUID) -> URL? {
        guard let path = data.folders.first(where: { $0.id == id })?.sourcePath,
              FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// Finds or creates the library folder that mirrors a directory on disk.
    func folder(forDirectory url: URL, name: String) -> LibraryFolder {
        let path = url.standardizedFileURL.path
        if let existing = data.folders.first(where: { $0.sourcePath == path }) { return existing }
        var unique = name
        var n = 2
        while folderExists(unique) { unique = "\(name) (\(n))"; n += 1 }
        var folder = LibraryFolder(name: unique)
        folder.sourcePath = path
        mutate { $0.folders.append(folder) }
        return folder
    }

    @discardableResult
    func createFolder(_ name: String) -> LibraryFolder {
        let folder = LibraryFolder(name: name)
        mutate { $0.folders.append(folder) }
        return folder
    }

    func renameFolder(_ id: UUID, to name: String) {
        mutate { d in
            if let i = d.folders.firstIndex(where: { $0.id == id }) { d.folders[i].name = name }
        }
    }

    func setExpanded(_ id: UUID, _ expanded: Bool) {
        mutate { d in
            if let i = d.folders.firstIndex(where: { $0.id == id }) { d.folders[i].isExpanded = expanded }
        }
    }

    /// Files from the deleted folder go back to the root of the library.
    func deleteFolder(_ id: UUID) {
        mutate { d in
            for i in d.files.indices where d.files[i].folderID == id { d.files[i].folderID = nil }
            d.folders.removeAll { $0.id == id }
        }
    }

    // MARK: Internals

    func refreshMissing() {
        for entry in data.files { _ = resolve(entry.id) }
    }

    private func setMissing(_ id: UUID, _ value: Bool) {
        if value { missing.insert(id) } else { missing.remove(id) }
    }

    private func refresh(_ id: UUID, url: URL) {
        let bookmark = (try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)) ?? Data()
        mutate { d in
            if let i = d.files.firstIndex(where: { $0.id == id }) {
                d.files[i].path = url.path
                d.files[i].name = url.lastPathComponent
                if !bookmark.isEmpty { d.files[i].bookmark = bookmark }
            }
        }
    }

    private func mutate(_ change: (inout LibraryData) -> Void) {
        var copy = data
        change(&copy)
        data = copy
        save()
    }

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let raw = try? Data(contentsOf: storeURL),
              let decoded = try? decoder.decode(LibraryData.self, from: raw) else { return }
        data = decoded
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let raw = try? encoder.encode(data) else { return }
        try? raw.write(to: storeURL, options: .atomic)
    }
}
