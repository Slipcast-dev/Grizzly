import Foundation

/// How the Find bar matches text. The default (all off) is a plain, case-insensitive search.
struct SearchOptions: Equatable {
    var caseSensitive = false
    var wholeWord = false
    var regex = false

    var key: String { "\(caseSensitive ? 1 : 0)\(wholeWord ? 1 : 0)\(regex ? 1 : 0)" }
}

/// Text search and replace without any UI dependency (unit-tested).
enum TextSearch {
    /// The compiled pattern, or nil when a plain search is enough or the regular expression is invalid.
    static func expression(_ query: String, _ options: SearchOptions) -> NSRegularExpression? {
        guard options.regex || options.wholeWord else { return nil }
        var pattern = options.regex ? query : NSRegularExpression.escapedPattern(for: query)
        if options.wholeWord { pattern = "\\b(?:\(pattern))\\b" }
        return try? NSRegularExpression(pattern: pattern, options: options.caseSensitive ? [] : [.caseInsensitive])
    }

    /// False when a regular expression is typed but cannot be compiled (the bar shows it in red).
    static func isValid(_ query: String, _ options: SearchOptions) -> Bool {
        guard options.regex, !query.isEmpty else { return true }
        return (try? NSRegularExpression(pattern: query)) != nil
    }

    static func ranges(of query: String, in text: String, options: SearchOptions = SearchOptions()) -> [Range<String.Index>] {
        guard !query.isEmpty else { return [] }
        if options.regex || options.wholeWord {
            guard let re = expression(query, options) else { return [] }
            let full = NSRange(text.startIndex..., in: text)
            return re.matches(in: text, range: full).compactMap { m in
                // An empty match (for example `x*`) cannot be highlighted or replaced meaningfully.
                m.range.length > 0 ? Range(m.range, in: text) : nil
            }
        }
        var result: [Range<String.Index>] = []
        let compare: String.CompareOptions = options.caseSensitive ? [] : [.caseInsensitive]
        var start = text.startIndex
        while start < text.endIndex, let r = text.range(of: query, options: compare, range: start..<text.endIndex) {
            result.append(r)
            start = r.upperBound > r.lowerBound ? r.upperBound : text.index(after: start)
        }
        return result
    }

    /// The text of the replacement for one hit: with a regular expression `$1` and `\n` work as usual.
    private static func replacement(_ template: String, for range: Range<String.Index>, in text: String,
                                    query: String, options: SearchOptions) -> String {
        guard options.regex, let re = expression(query, options),
              let m = re.firstMatch(in: text, range: NSRange(range, in: text)) else { return template }
        return re.replacementString(for: m, in: text, offset: 0, template: template)
    }

    /// Replaces every hit; returns the new text and how many hits were replaced.
    static func replaceAll(_ query: String, with template: String, in text: String,
                           options: SearchOptions = SearchOptions()) -> (text: String, count: Int) {
        let found = ranges(of: query, in: text, options: options)
        guard !found.isEmpty else { return (text, 0) }
        var out = text
        // Back to front, so the earlier ranges stay valid.
        for r in found.reversed() {
            out.replaceSubrange(r, with: replacement(template, for: r, in: text, query: query, options: options))
        }
        return (out, found.count)
    }

    /// Replaces the n-th hit of the whole text (hits are counted in reading order).
    static func replaceOne(_ query: String, with template: String, in text: String, index: Int,
                           options: SearchOptions = SearchOptions()) -> String? {
        let found = ranges(of: query, in: text, options: options)
        guard found.indices.contains(index) else { return nil }
        var out = text
        out.replaceSubrange(found[index], with: replacement(template, for: found[index], in: text, query: query, options: options))
        return out
    }
}
