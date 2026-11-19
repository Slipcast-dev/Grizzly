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
        return try? NSRegularExpression(pattern: pattern, options: options.caseSensitive ? [.anchorsMatchLines] : [.caseInsensitive, .anchorsMatchLines])
    }

    /// False when a regular expression is typed but cannot be compiled (the bar shows it in red).
    static func isValid(_ query: String, _ options: SearchOptions) -> Bool {
        guard options.regex, !query.isEmpty else { return true }
        return (try? NSRegularExpression(pattern: query)) != nil
    }

    /// One hit in a whole text. `unit` is the line the hit starts in (0-based), `occurrence` counts the hits that
    /// start in that line, `range` is in UTF-16 units. A regular expression may match across lines (`\n`).
    struct Hit: Equatable {
        let unit: Int
        let occurrence: Int
        let range: NSRange
    }

    private static func matches(_ query: String, in text: String, _ options: SearchOptions) -> [(range: NSRange, match: NSTextCheckingResult?)] {
        guard !query.isEmpty else { return [] }
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        if options.regex || options.wholeWord {
            guard let re = expression(query, options) else { return [] }
            // An empty match (for example `x*`) cannot be highlighted or replaced meaningfully.
            return re.matches(in: text, range: full).filter { $0.range.length > 0 }.map { ($0.range, $0) }
        }
        var result: [(NSRange, NSTextCheckingResult?)] = []
        let compare: NSString.CompareOptions = options.caseSensitive ? [] : [.caseInsensitive]
        var from = 0
        while from < ns.length {
            let r = ns.range(of: query, options: compare, range: NSRange(location: from, length: ns.length - from))
            if r.location == NSNotFound { break }
            result.append((r, nil))
            from = r.location + max(1, r.length)
        }
        return result
    }

    static func locate(_ query: String, in text: String, options: SearchOptions = SearchOptions()) -> [Hit] {
        let found = matches(query, in: text, options)
        guard !found.isEmpty else { return [] }
        let ns = text as NSString
        var hits: [Hit] = []
        var line = 0, lineStart = 0, occurrence = 0, scanned = 0
        for (range, _) in found {
            // Count the line breaks between the previous hit and this one.
            var i = scanned
            while i < range.location {
                if ns.character(at: i) == 10 { line += 1; lineStart = i + 1; occurrence = 0 }
                i += 1
            }
            scanned = range.location
            _ = lineStart
            hits.append(Hit(unit: line, occurrence: occurrence, range: range))
            occurrence += 1
        }
        return hits
    }

    /// The same hits as ranges of a string (used for single lines and rendered blocks).
    static func ranges(of query: String, in text: String, options: SearchOptions = SearchOptions()) -> [Range<String.Index>] {
        matches(query, in: text, options).compactMap { Range($0.range, in: text) }
    }

    struct Edit: Equatable {
        let range: NSRange
        let text: String
    }

    /// The edits that replace hits with `template` (`$1`, `\n` work with a regular expression). With `only`, just the
    /// n-th hit. Edits come in ascending order and never overlap.
    static func edits(_ query: String, with template: String, in text: String, only: Int? = nil,
                      options: SearchOptions = SearchOptions()) -> [Edit] {
        let found = matches(query, in: text, options)
        let chosen = only.map { found.indices.contains($0) ? [found[$0]] : [] } ?? found
        return chosen.map { item in
            if options.regex, let m = item.match, let re = expression(query, options) {
                return Edit(range: item.range, text: re.replacementString(for: m, in: text, offset: 0, template: template))
            }
            return Edit(range: item.range, text: template)
        }
    }

    static func apply(_ edits: [Edit], to text: String) -> String {
        let ns = NSMutableString(string: text)
        for e in edits.reversed() { ns.replaceCharacters(in: e.range, with: e.text) }
        return ns as String
    }

    /// Replaces every hit; returns the new text and how many hits were replaced.
    static func replaceAll(_ query: String, with template: String, in text: String,
                           options: SearchOptions = SearchOptions()) -> (text: String, count: Int) {
        let e = edits(query, with: template, in: text, options: options)
        return e.isEmpty ? (text, 0) : (apply(e, to: text), e.count)
    }

    /// Replaces the n-th hit of the whole text (hits are counted in reading order).
    static func replaceOne(_ query: String, with template: String, in text: String, index: Int,
                           options: SearchOptions = SearchOptions()) -> String? {
        let e = edits(query, with: template, in: text, only: index, options: options)
        return e.isEmpty ? nil : apply(e, to: text)
    }
}
