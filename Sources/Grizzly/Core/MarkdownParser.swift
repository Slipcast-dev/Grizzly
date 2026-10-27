import Foundation

enum MDBlock {
    case heading(Int, String)
    case paragraph(String)
    case bullets([String])
    case numbered([String])
    case code(String, String)
    case quote(String)
    case rule
    case table(header: [String], rows: [[String]])
}

enum MarkdownParser {
    static func parse(_ lines: [String]) -> [MDBlock] {
        var blocks: [MDBlock] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty { i += 1; continue }

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                let fence = String(trimmed.prefix(3))
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var body: [String] = []
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(fence) {
                    body.append(lines[i]); i += 1
                }
                i += 1
                blocks.append(.code(lang, body.joined(separator: "\n")))
                continue
            }

            if let (level, text) = heading(trimmed) {
                blocks.append(.heading(level, text)); i += 1; continue
            }

            if isRule(trimmed) { blocks.append(.rule); i += 1; continue }

            if trimmed.hasPrefix(">") {
                var q: [String] = []
                while i < lines.count, lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                    var t = lines[i].trimmingCharacters(in: .whitespaces).dropFirst()
                    if t.hasPrefix(" ") { t = t.dropFirst() }
                    q.append(String(t)); i += 1
                }
                blocks.append(.quote(q.joined(separator: "\n")))
                continue
            }

            if bullet(trimmed) != nil {
                var items: [String] = []
                while i < lines.count, let b = bullet(lines[i].trimmingCharacters(in: .whitespaces)) {
                    items.append(b); i += 1
                }
                blocks.append(.bullets(items))
                continue
            }

            if numberedItem(trimmed) != nil {
                var items: [String] = []
                while i < lines.count, let b = numberedItem(lines[i].trimmingCharacters(in: .whitespaces)) {
                    items.append(b); i += 1
                }
                blocks.append(.numbered(items))
                continue
            }

            if trimmed.contains("|"), i + 1 < lines.count, isTableSeparator(lines[i + 1]) {
                let header = cells(trimmed)
                var rows: [[String]] = []
                i += 2
                while i < lines.count, lines[i].contains("|"),
                      !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                    rows.append(cells(lines[i])); i += 1
                }
                blocks.append(.table(header: header, rows: rows))
                continue
            }

            var para: [String] = []
            while i < lines.count {
                let t = lines[i].trimmingCharacters(in: .whitespaces)
                if t.isEmpty || t.hasPrefix("```") || t.hasPrefix(">") || heading(t) != nil
                    || bullet(t) != nil || numberedItem(t) != nil || isRule(t) { break }
                para.append(t); i += 1
            }
            if para.isEmpty { i += 1 } else { blocks.append(.paragraph(para.joined(separator: " "))) }
        }
        return blocks
    }

    private static func heading(_ s: String) -> (Int, String)? {
        var level = 0
        for ch in s { if ch == "#" { level += 1 } else { break } }
        guard (1...6).contains(level), s.dropFirst(level).first == " " else { return nil }
        return (level, s.dropFirst(level).trimmingCharacters(in: .whitespaces))
    }

    private static func isRule(_ s: String) -> Bool {
        let compact = s.replacingOccurrences(of: " ", with: "")
        guard compact.count >= 3, let c = compact.first, "-*_".contains(c) else { return false }
        return compact.allSatisfy { $0 == c }
    }

    private static func bullet(_ s: String) -> String? {
        guard s.count > 2, "-*+".contains(s.first!), s.dropFirst().first == " " else { return nil }
        var t = String(s.dropFirst(2))
        if t.hasPrefix("[ ] ") { t = "☐ " + t.dropFirst(4) }
        else if t.lowercased().hasPrefix("[x] ") { t = "☑ " + t.dropFirst(4) }
        return t
    }

    private static func numberedItem(_ s: String) -> String? {
        guard let dot = s.firstIndex(of: "."), dot != s.startIndex,
              s[s.startIndex..<dot].allSatisfy(\.isNumber),
              s[s.index(after: dot)...].first == " " else { return nil }
        return String(s[s.index(dot, offsetBy: 2)...])
    }

    private static func isTableSeparator(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard t.contains("-"), t.contains("|") else { return false }
        return t.allSatisfy { "|-: ".contains($0) }
    }

    private static func cells(_ s: String) -> [String] {
        var t = s.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("|") { t.removeFirst() }
        if t.hasSuffix("|") { t.removeLast() }
        return t.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
