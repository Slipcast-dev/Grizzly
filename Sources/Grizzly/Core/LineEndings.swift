import Foundation

/// The line endings of a file as they were read, so that saving does not rewrite them.
/// The editor works with `\n` only; `apply` turns the text back into what the file used.
struct LineEndings: Equatable {
    /// The ending used for new lines and for lines past the recorded ones.
    var dominant: String = "\n"
    /// The ending of every line break in file order; nil when all of them are `dominant` (the usual case).
    var sequence: [String]?

    static let lf = LineEndings()

    /// Splits `\r\n`, `\r` and `\n`; returns the text with `\n` only.
    static func parse(_ text: String) -> (normalized: String, endings: LineEndings) {
        guard text.utf8.contains(13) else { return (text, .lf) }
        var out = String.UnicodeScalarView()
        var seq: [String] = []
        var counts: [String: Int] = [:]
        var prevCR = false
        for u in text.unicodeScalars {
            if u == "\r" {
                if prevCR { out.append("\n"); seq.append("\r"); counts["\r", default: 0] += 1 }
                prevCR = true
                continue
            }
            if u == "\n" {
                let e = prevCR ? "\r\n" : "\n"
                out.append("\n"); seq.append(e); counts[e, default: 0] += 1
                prevCR = false
                continue
            }
            if prevCR { out.append("\n"); seq.append("\r"); counts["\r", default: 0] += 1; prevCR = false }
            out.append(u)
        }
        if prevCR { out.append("\n"); seq.append("\r"); counts["\r", default: 0] += 1 }
        let dominant = counts.max { $0.value < $1.value }?.key ?? "\n"
        let mixed = counts.count > 1
        return (String(out), LineEndings(dominant: dominant, sequence: mixed ? seq : nil))
    }

    /// Puts the file's endings back: the n-th line break gets the n-th recorded ending (a file with one kind of
    /// ending simply gets that kind everywhere); breaks added by editing use the dominant one.
    func apply(to text: String) -> String {
        if sequence == nil && dominant == "\n" { return text }
        var out = ""
        out.reserveCapacity(text.utf8.count + 16)
        var n = 0
        for u in text.unicodeScalars {
            if u == "\n" {
                if let seq = sequence, n < seq.count { out += seq[n] } else { out += dominant }
                n += 1
            } else {
                out.unicodeScalars.append(u)
            }
        }
        return out
    }
}
