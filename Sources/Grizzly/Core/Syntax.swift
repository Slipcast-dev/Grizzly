import SwiftUI

/// Line-by-line syntax coloring. Every rule works on a single line, so rows stay independent
/// and search/bookmark units (one line = one unit) are unaffected.
enum Syntax {
    private enum Role { case key, string, number, keyword, comment, error, warning, success, secondary }

    private struct Rule {
        let regex: NSRegularExpression
        let role: Role
        init(_ pattern: String, _ role: Role, options: NSRegularExpression.Options = []) {
            self.regex = try! NSRegularExpression(pattern: pattern, options: options)
            self.role = role
        }
    }

    private static let stringRule = Rule(#""(?:[^"\\]|\\.)*"|'[^']*'"#, .string)
    private static let numberRule = Rule(#"(?<![\w.])-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?(?![\w.])"#, .number)

    /// Rules are applied in order; a character claimed by an earlier rule is never recolored.
    private static let rules: [FileType: [Rule]] = [
        .json: [
            Rule(#""(?:[^"\\]|\\.)*"(?=\s*:)"#, .key),
            stringRule, numberRule,
            Rule(#"\b(?:true|false|null)\b"#, .keyword),
        ],
        .yaml: [
            Rule(#"(?:^|\s)#.*$"#, .comment),
            Rule(#"^\s*(?:-\s+)?(?:"[^"]*"|'[^']*'|[\w.\-/ ]+?)(?=:(?:\s|$))"#, .key),
            stringRule, numberRule,
            Rule(#"\b(?:true|false|null|yes|no|on|off)\b|(?<=\s)~(?=\s|$)"#, .keyword),
            Rule(#"^(?:---|\.\.\.)\s*$"#, .secondary),
            Rule(#"[&*]\w+|![\w!]+"#, .keyword),
        ],
        .config: [
            Rule(#"^\s*[;#].*$"#, .comment),
            Rule(#"^\s*\[[^\]]*\]"#, .keyword),
            Rule(#"^\s*[\w.\-"]+(?=\s*[=:])"#, .key),
            stringRule, numberRule,
            Rule(#"\b(?:true|false)\b"#, .keyword),
            Rule(#"\s[;#].*$"#, .comment),
        ],
        .xml: markup,
        .html: markup,
        .tex: [
            Rule(#"(?<!\\)%.*$"#, .comment),
            Rule(#"\$\$?[^$]*\$\$?"#, .string),
            Rule(#"\\(?:begin|end)\{[^}]*\}"#, .keyword),
            Rule(#"\\[A-Za-z]+\*?"#, .key),
            Rule(#"[{}\[\]]"#, .secondary),
        ],
        .log: [
            Rule(#"\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:[.,]\d+)?(?:Z|[+-]\d{2}:?\d{2})?"#, .secondary),
            Rule(#"\b\d{2}:\d{2}:\d{2}(?:[.,]\d+)?\b"#, .secondary),
            Rule(#"\b(?:ERROR|ERR|FATAL|CRITICAL|SEVERE|PANIC|EXCEPTION|FAILED)\b"#, .error),
            Rule(#"\b(?:WARN|WARNING)\b"#, .warning),
            Rule(#"\b(?:INFO|NOTICE|SUCCESS|OK)\b"#, .success),
            Rule(#"\b(?:DEBUG|TRACE|VERBOSE)\b"#, .secondary),
            Rule(#"\[[^\]\n]{1,40}\]"#, .key),
        ],
    ]

    private static let markup: [Rule] = [
        Rule(#"<!--.*?-->|<!--.*$|^.*?-->"#, .comment),
        Rule(#""[^"]*"|'[^']*'"#, .string),
        Rule(#"<[!?/]?[A-Za-z][\w:\-.]*|<[!?]\w+"#, .keyword),
        Rule(#"[\w:\-.]+(?==)"#, .key),
        Rule(#"/?\??>"#, .keyword),
        Rule(#"&\w+;|&#\d+;"#, .number),
    ]

    private static let maxLength = 2000

    static func hasHighlighting(_ type: FileType) -> Bool { rules[type] != nil }

    static func highlight(_ line: String, type: FileType, theme: Theme) -> AttributedString {
        var out = AttributedString(line)
        guard let rules = rules[type], !line.isEmpty, line.utf16.count <= maxLength else { return out }

        let ns = line as NSString
        let full = NSRange(location: 0, length: ns.length)
        var claimed = [Bool](repeating: false, count: ns.length)
        var spans: [(NSRange, Color)] = []

        for rule in rules {
            rule.regex.enumerateMatches(in: line, options: [], range: full) { match, _, _ in
                guard let r = match?.range, r.length > 0 else { return }
                if (r.location..<(r.location + r.length)).contains(where: { claimed[$0] }) {
                    // Partly claimed already: color only the free runs.
                    var runStart: Int?
                    for i in r.location...(r.location + r.length) {
                        let free = i < r.location + r.length && !claimed[i]
                        if free, runStart == nil { runStart = i }
                        if !free, let s = runStart {
                            spans.append((NSRange(location: s, length: i - s), color(rule.role, theme)))
                            for k in s..<i { claimed[k] = true }
                            runStart = nil
                        }
                    }
                } else {
                    spans.append((r, color(rule.role, theme)))
                    for k in r.location..<(r.location + r.length) { claimed[k] = true }
                }
            }
        }

        for (range, color) in spans {
            guard let r = Range(range, in: line) else { continue }
            let lo = line.distance(from: line.startIndex, to: r.lowerBound)
            let hi = line.distance(from: line.startIndex, to: r.upperBound)
            let a = out.characters.index(out.startIndex, offsetBy: lo)
            let b = out.characters.index(out.startIndex, offsetBy: hi)
            out[a..<b].foregroundColor = color
        }
        return out
    }

    private static func color(_ role: Role, _ t: Theme) -> Color {
        switch role {
        case .key: return t.key
        case .string: return t.string
        case .number: return t.number
        case .keyword: return t.keyword
        case .comment, .secondary: return t.comment
        case .error: return t.error
        case .warning: return t.warning
        case .success: return t.success
        }
    }
}
