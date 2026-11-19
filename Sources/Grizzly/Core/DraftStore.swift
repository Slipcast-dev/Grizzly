import Foundation
import CryptoKit

/// Crash recovery: unsaved text is copied to disk a moment after it is typed, one small JSON file per document, and
/// removed as soon as the text is saved or discarded. After a crash the next launch finds what is left.
final class DraftStore {
    struct Entry: Codable, Equatable {
        let path: String
        let text: String
        let date: Date
    }

    let directory: URL

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.directory = support.appendingPathComponent("Grizzly/Recovery", isDirectory: true)
        }
    }

    private func file(for path: String) -> URL {
        let digest = SHA256.hash(data: Data(path.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent("\(digest).json")
    }

    func save(path: String, text: String) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let entry = Entry(path: path, text: text, date: Date())
        if let data = try? JSONEncoder().encode(entry) { try? data.write(to: file(for: path), options: .atomic) }
    }

    func remove(path: String) { try? FileManager.default.removeItem(at: file(for: path)) }

    func removeAll() { try? FileManager.default.removeItem(at: directory) }

    func entries() -> [Entry] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }
            .compactMap { try? Data(contentsOf: $0) }
            .compactMap { try? JSONDecoder().decode(Entry.self, from: $0) }
            .sorted { $0.date < $1.date }
    }
}
