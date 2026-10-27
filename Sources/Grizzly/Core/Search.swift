import SwiftUI

/// One hit. `unit` is the row the hit lives in (a source line or a Markdown block),
/// `occurrence` counts hits inside that unit in display order.
struct SearchMatch: Equatable {
    let unit: Int
    let occurrence: Int
}

/// What a view needs to paint matches: the query plus the hit that is currently selected.
struct SearchHighlight {
    let query: String
    let current: SearchMatch?
}

struct ScrollTarget: Equatable {
    let unit: Int
    let id = UUID()
}

enum Searcher {
    static func ranges(of query: String, in text: String) -> [Range<String.Index>] {
        guard !query.isEmpty else { return [] }
        var result: [Range<String.Index>] = []
        var start = text.startIndex
        while start < text.endIndex,
              let r = text.range(of: query, options: [.caseInsensitive], range: start..<text.endIndex) {
            result.append(r)
            start = r.upperBound > r.lowerBound ? r.upperBound : text.index(after: start)
        }
        return result
    }

    /// Markdown reading mode is searched per rendered block; every other view is searched per line.
    static func usesBlocks(_ doc: Document, _ mode: ReadMode) -> Bool {
        mode == .reading && doc.type == .markdown
    }

    static func matches(query: String, in doc: Document, mode: ReadMode) -> [SearchMatch] {
        guard !query.isEmpty else { return [] }
        var result: [SearchMatch] = []

        func collect(unit: Int, texts: [String]) {
            var occurrence = 0
            for text in texts {
                for _ in ranges(of: query, in: text) {
                    result.append(SearchMatch(unit: unit, occurrence: occurrence))
                    occurrence += 1
                }
            }
        }

        if usesBlocks(doc, mode) {
            for (i, block) in doc.blocks.enumerated() { collect(unit: i, texts: segments(of: block)) }
        } else {
            for (i, line) in doc.lines.enumerated() { collect(unit: i, texts: [line]) }
        }
        return result
    }

    /// Visible text pieces of a block in the order MarkdownView draws them.
    static func segments(of block: MDBlock) -> [String] {
        switch block {
        case .heading(_, let t), .paragraph(let t), .quote(let t): return [plain(t)]
        case .bullets(let items), .numbered(let items): return items.map(plain)
        case .code(_, let code): return [code]
        case .rule: return []
        case .table(let header, let rows): return (header + rows.flatMap { $0 }).map(plain)
        }
    }

    /// Number of hits before each segment, so a segment knows its first occurrence index.
    static func offsets(for block: MDBlock, query: String) -> [Int] {
        var running = 0
        return segments(of: block).map { text in
            defer { running += ranges(of: query, in: text).count }
            return running
        }
    }

    private static func plain(_ s: String) -> String { String(inlineMarkdown(s).characters) }
}

extension AttributedString {
    func highlighted(_ highlight: SearchHighlight?, unit: Int, offset: Int, theme: Theme) -> AttributedString {
        guard let highlight, !highlight.query.isEmpty else { return self }
        let plain = String(characters)
        let found = Searcher.ranges(of: highlight.query, in: plain)
        guard !found.isEmpty else { return self }

        var out = self
        for (k, r) in found.enumerated() {
            let lo = plain.distance(from: plain.startIndex, to: r.lowerBound)
            let hi = plain.distance(from: plain.startIndex, to: r.upperBound)
            let a = out.characters.index(out.startIndex, offsetBy: lo)
            let b = out.characters.index(out.startIndex, offsetBy: hi)
            let isCurrent = highlight.current == SearchMatch(unit: unit, occurrence: offset + k)
            out[a..<b].backgroundColor = isCurrent ? theme.currentMatch : theme.match
            if isCurrent { out[a..<b].foregroundColor = .black }
        }
        return out
    }
}
