import AppKit
import Foundation

enum FileLoader {
    /// Reads a file and decodes it, trying UTF-8, UTF-16 (BOM) and then legacy 8-bit encodings.
    static func read(_ url: URL) throws -> (text: String, encoding: String) {
        if url.pathExtension.lowercased() == "rtf",
           let attributed = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) {
            return (attributed.string, "RTF")
        }
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int ?? 0
        if size > maxFileSize { throw CocoaError(.fileReadTooLarge) }
        let data = try Data(contentsOf: url)
        if data.starts(with: [0xEF, 0xBB, 0xBF]), let s = String(data: data.dropFirst(3), encoding: .utf8) {
            return (s, "UTF-8")
        }
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]),
           let s = String(data: data, encoding: .utf16) {
            return (s, "UTF-16")
        }
        if let s = String(data: data, encoding: .utf8) { return (s, "UTF-8") }
        if let best = detectCyrillic(data) { return best }
        if let s = String(data: data, encoding: .isoLatin1) { return (s, "ISO-8859-1") }
        throw CocoaError(.fileReadInapplicableStringEncoding)
    }

    /// Files above this size are refused: the editor keeps several copies of the text in memory.
    static let maxFileSize = 200 * 1024 * 1024
    /// Above this size syntax colors are not computed (they would freeze the editor).
    static let highlightLimit = 2 * 1024 * 1024

    private static let eightBit: [(name: String, encoding: String.Encoding)] = [
        ("Windows-1251", .windowsCP1251),
        ("KOI8-R", cfEncoding(.KOI8_R)),
        ("CP866", cfEncoding(.dosRussian)),
    ]

    private static func cfEncoding(_ e: CFStringEncodings) -> String.Encoding {
        String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(e.rawValue)))
    }

    /// Windows-1251, KOI8-R and CP866 decode almost any bytes, so the right one is the reading that looks most like
    /// Russian: many lowercase letters, few capitals inside words and no box-drawing characters.
    /// Returns nil when no reading has Cyrillic letters (the caller then falls back to ISO-8859-1).
    static func detectCyrillic(_ data: Data) -> (text: String, encoding: String)? {
        var best: (text: String, encoding: String, score: Int)?
        for (name, encoding) in eightBit {
            guard let s = String(data: data, encoding: encoding) else { continue }
            var score = 0
            for u in s.unicodeScalars {
                switch u.value {
                case 0x0430...0x044F, 0x0451: score += 2
                case 0x0410...0x042F, 0x0401: score -= 1
                case 0x2500...0x259F: score -= 6
                default: break
                }
            }
            if best == nil || score > best!.score { best = (s, name, score) }
        }
        guard let best, best.score > 0 else { return nil }
        return (best.text, best.encoding)
    }

    /// Inverse of `read`: writes the text back in the encoding the file was read with (a UTF-8 BOM is kept).
    /// Throws `.fileWriteInapplicableStringEncoding` when the text has characters the encoding cannot hold.
    static func write(_ text: String, to url: URL, encoding: String) throws {
        let data: Data
        switch encoding {
        case "UTF-8":
            let hadBOM = (try? Data(contentsOf: url, options: .mappedIfSafe))?.starts(with: [0xEF, 0xBB, 0xBF]) ?? false
            data = (hadBOM ? Data([0xEF, 0xBB, 0xBF]) : Data()) + Data(text.utf8)
        case "UTF-16":
            guard let body = text.data(using: .utf16LittleEndian) else { throw CocoaError(.fileWriteInapplicableStringEncoding) }
            data = Data([0xFF, 0xFE]) + body
        case "Windows-1251":
            guard let body = text.data(using: .windowsCP1251) else { throw CocoaError(.fileWriteInapplicableStringEncoding) }
            data = body
        case "KOI8-R", "CP866":
            let encoding = eightBit.first { $0.name == encoding }!.encoding
            guard let body = text.data(using: encoding) else { throw CocoaError(.fileWriteInapplicableStringEncoding) }
            data = body
        case "ISO-8859-1":
            guard let body = text.data(using: .isoLatin1) else { throw CocoaError(.fileWriteInapplicableStringEncoding) }
            data = body
        case "RTF":
            // Plain text is written back as a plain RTF document: the original formatting is not kept.
            let attributed = NSAttributedString(string: text)
            guard let body = try? attributed.data(
                from: NSRange(location: 0, length: attributed.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) else {
                throw CocoaError(.fileWriteUnknown)
            }
            data = body
        default:
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        try replaceFile(at: url, with: data)
    }

    /// Writes the data so that a crash never leaves half a file, and the file keeps what makes it the same file:
    /// a symbolic link still points where it did, and permissions, Finder tags and other attributes stay.
    static func replaceFile(at url: URL, with data: Data) throws {
        let fm = FileManager.default
        let target = url.resolvingSymlinksInPath()
        guard fm.fileExists(atPath: target.path) else {
            try data.write(to: target, options: .atomic)
            return
        }
        let temp = target.deletingLastPathComponent().appendingPathComponent(".grizzly-\(UUID().uuidString).tmp")
        do {
            try data.write(to: temp)
            _ = try fm.replaceItemAt(target, withItemAt: temp)
        } catch {
            try? fm.removeItem(at: temp)
            // The folder may not allow new files (a read-only folder with a writable file): write in place.
            try data.write(to: target)
        }
    }
}
