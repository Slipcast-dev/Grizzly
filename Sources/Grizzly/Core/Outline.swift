import Foundation

/// A table of contents for any file type: Markdown headings, TeX sections, INI sections, HTML headings,
/// and the declarations (classes, functions) of source code.
enum Outline {
    struct Item: Equatable {
        let line: Int      // 0-based
        let level: Int     // 1 = top level
        let title: String
    }

    private static func re(_ p: String) -> NSRegularExpression { try! NSRegularExpression(pattern: p) }

    private static let python = re(#"^(\s*)(?:async\s+)?(def|class)\s+(\w+)"#)
    private static let swift = re(#"^(\s*)(?:(?:public|private|fileprivate|internal|open|final|static|class|override|mutating|indirect)\s+)*(func|class|struct|enum|protocol|extension|actor|init)\b\s*([\w<>.]*)"#)
    private static let js = re(#"^(\s*)(?:export\s+)?(?:default\s+)?(?:async\s+)?(function\*?|class|interface|enum|type)\s+(\w+)"#)
    private static let jsConst = re(#"^(\s*)(?:export\s+)?(?:const|let|var)\s+(\w+)\s*=\s*(?:async\s*)?(?:\([^)]*\)|\w+)\s*=>"#)
    private static let php = re(#"^(\s*)(?:(?:public|private|protected|static|final|abstract)\s+)*(function|class|interface|trait|enum)\s+&?(\w+)"#)
    private static let csharp = re(#"^(\s*)(?:(?:public|private|protected|internal|static|abstract|sealed|override|virtual|async|partial|readonly)\s+)*(class|struct|interface|enum|record|namespace)\s+([\w.]+)"#)
    private static let csMethod = re(#"^(\s*)(?:(?:public|private|protected|internal|static|abstract|override|virtual|async|partial)\s+)+[\w<>\[\],.?]+\s+(\w+)\s*\([^;]*$"#)
    private static let java = re(#"^(\s*)(?:(?:public|private|protected|static|final|abstract|synchronized|default)\s+)*(class|interface|enum|record)\s+(\w+)"#)
    private static let javaMethod = re(#"^(\s*)(?:(?:public|private|protected|static|final|abstract|synchronized)\s+)+[\w<>\[\],.?]+\s+(\w+)\s*\([^;]*$"#)
    private static let cFunc = re(#"^()[A-Za-z_][\w\s\*&:<>,~]*?[\s\*&]([A-Za-z_~][\w:~]*)\s*\([^;]*$"#)
    private static let cType = re(#"^(\s*)(?:typedef\s+)?(class|struct|enum|namespace)\s+(\w+)"#)
    private static let go = re(#"^()(func|type)\s+(?:\([^)]*\)\s*)?(\w+)"#)
    private static let rust = re(#"^(\s*)(?:pub(?:\([^)]*\))?\s+)?(?:async\s+)?(?:unsafe\s+)?(fn|struct|enum|trait|impl|mod)\s+(\w+)"#)
    private static let kotlin = re(#"^(\s*)(?:(?:public|private|protected|internal|open|abstract|override|suspend|data|sealed|inline)\s+)*(fun|class|object|interface)\s+(?:<[^>]*>\s*)?([\w.]+)"#)
    private static let sql = re(#"(?i)^()\s*create\s+(?:or\s+replace\s+)?(table|view|function|procedure|index|trigger)\s+(?:if\s+not\s+exists\s+)?([\w."]+)"#)
    private static let shell = re(#"^()(?:function\s+)?(\w[\w-]*)\s*\(\)\s*\{?"#)
    private static let ruby = re(#"^(\s*)(def|class|module)\s+([\w.:]+)"#)
    private static let css = re(#"^([^\s@/}][^{;]*?)\s*\{\s*$"#)
    private static let cssAt = re(#"^(@(?:media|keyframes|font-face|supports)[^{]*)\{"#)
    private static let yamlKey = re(#"^([A-Za-z_][\w .-]*):(?:\s|$)"#)
    private static let ini = re(#"^\s*\[+([^\]]+)\]+"#)
    private static let tex = re(#"\\(chapter|section|subsection|subsubsection|part)\*?\{([^}]*)\}"#)
    private static let html = re(#"<h([1-6])[^>]*>(.*?)</h[1-6]>"#)

    private static func group(_ m: NSTextCheckingResult, _ i: Int, in s: String) -> String {
        guard i < m.numberOfRanges, let r = Range(m.range(at: i), in: s) else { return "" }
        return String(s[r])
    }

    static func items(_ text: String, type: FileType) -> [Item] {
        var out: [Item] = []
        var inFence = false
        for (i, line) in text.components(separatedBy: "\n").enumerated() {
            guard line.utf16.count < 400 else { continue }
            let full = NSRange(location: 0, length: line.utf16.count)
            func first(_ r: NSRegularExpression) -> NSTextCheckingResult? { r.firstMatch(in: line, range: full) }
            func indentLevel(_ m: NSTextCheckingResult) -> Int { min(4, group(m, 1, in: line).count / 4 + 1) }

            switch type {
            case .markdown:
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("```") || t.hasPrefix("~~~") { inFence.toggle(); continue }
                guard !inFence, t.hasPrefix("#") else { continue }
                let level = t.prefix { $0 == "#" }.count
                guard level <= 6, t.dropFirst(level).first == " " else { continue }
                let title = t.dropFirst(level).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty { out.append(Item(line: i, level: level, title: title)) }
            case .tex:
                if let m = first(tex) {
                    let lv = ["part": 1, "chapter": 1, "section": 2, "subsection": 3, "subsubsection": 4][group(m, 1, in: line)] ?? 2
                    out.append(Item(line: i, level: lv, title: group(m, 2, in: line)))
                }
            case .config:
                if let m = first(ini) { out.append(Item(line: i, level: 1, title: group(m, 1, in: line))) }
            case .yaml:
                if let m = first(yamlKey) { out.append(Item(line: i, level: 1, title: group(m, 1, in: line))) }
            case .html:
                if let m = first(html) {
                    let title = group(m, 2, in: line).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    out.append(Item(line: i, level: Int(group(m, 1, in: line)) ?? 1, title: title))
                }
            case .css:
                if let m = first(cssAt) { out.append(Item(line: i, level: 1, title: group(m, 1, in: line).trimmingCharacters(in: .whitespaces))) }
                else if let m = first(css) { out.append(Item(line: i, level: 1, title: group(m, 1, in: line))) }
            case .python, .ruby, .swift, .php, .go, .rust, .kotlin, .java, .csharp:
                let r: NSRegularExpression
                switch type {
                case .python: r = python
                case .ruby: r = ruby
                case .swift: r = swift
                case .php: r = php
                case .go: r = go
                case .rust: r = rust
                case .kotlin: r = kotlin
                case .java: r = java
                default: r = csharp
                }
                if let m = first(r) {
                    let kind = group(m, 2, in: line), name = group(m, 3, in: line)
                    out.append(Item(line: i, level: indentLevel(m), title: name.isEmpty ? kind : "\(kind) \(name)"))
                } else if type == .java, let m = first(javaMethod) {
                    out.append(Item(line: i, level: indentLevel(m) + 1, title: group(m, 2, in: line) + "()"))
                } else if type == .csharp, let m = first(csMethod) {
                    out.append(Item(line: i, level: indentLevel(m) + 1, title: group(m, 2, in: line) + "()"))
                }
            case .javascript, .typescript:
                if let m = first(js) { out.append(Item(line: i, level: indentLevel(m), title: "\(group(m, 2, in: line)) \(group(m, 3, in: line))")) }
                else if let m = first(jsConst) { out.append(Item(line: i, level: indentLevel(m), title: "\(group(m, 2, in: line))()")) }
            case .cpp:
                if let m = first(cType) { out.append(Item(line: i, level: indentLevel(m), title: "\(group(m, 2, in: line)) \(group(m, 3, in: line))")) }
                else if !line.hasPrefix(" "), !line.hasPrefix("\t"), !line.hasPrefix("#"), !line.hasPrefix("//"),
                        let m = first(cFunc) {
                    let name = group(m, 2, in: line)
                    if !["if", "for", "while", "switch", "return", "sizeof"].contains(name) { out.append(Item(line: i, level: 1, title: name + "()")) }
                }
            case .sql:
                if let m = first(sql) { out.append(Item(line: i, level: 1, title: "\(group(m, 2, in: line).lowercased()) \(group(m, 3, in: line))")) }
            case .shell:
                if let m = first(shell) { out.append(Item(line: i, level: 1, title: group(m, 2, in: line) + "()")) }
            case .text, .json, .csv, .log, .xml, .rtf:
                continue
            }
        }
        return out
    }
}
