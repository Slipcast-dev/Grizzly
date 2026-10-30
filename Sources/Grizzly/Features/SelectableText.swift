import SwiftUI
import AppKit

// MARK: - Text builders

/// Builds the attributed text shown in Reading and Source mode. One text view holds the whole document,
/// so the mouse (and ⌘A) can select across lines and paragraphs; each search unit (a line or a Markdown block)
/// remembers its character range for find highlights and scrolling.
enum TextBuilder {
    struct Result {
        let text: NSAttributedString
        let units: [NSRange]
    }

    static func font(_ prefs: Preferences, size: CGFloat, bold: Bool = false) -> NSFont {
        if prefs.fontName == Preferences.systemFont {
            return .systemFont(ofSize: size, weight: bold ? .semibold : .regular)
        }
        let base = NSFont(name: prefs.fontName, size: size) ?? .systemFont(ofSize: size)
        return bold ? NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask) : base
    }

    private static func mono(_ size: CGFloat) -> NSFont { .monospacedSystemFont(ofSize: size, weight: .regular) }

    /// Syntax colors for one line, added at `offset` of the whole text.
    private static func colorize(_ line: String, type: FileType, state: Int, offset: Int, theme: Theme,
                                 into out: NSMutableAttributedString) {
        for span in SyntaxEngine.spans(line, type: type, state: state).spans {
            out.addAttribute(.foregroundColor, value: NSColor(Syntax.color(span.role, theme)),
                             range: NSRange(location: offset + span.range.location, length: span.range.length))
        }
    }

    /// The raw text, one unit per line. `monospaced`: Source mode; otherwise Reading mode of a plain-text file.
    static func lines(_ doc: Document, size: CGFloat, theme: Theme, prefs: Preferences, monospaced: Bool) -> Result {
        let highlight = prefs.highlights(doc.type) && SyntaxEngine.hasHighlighting(doc.type)
        let useMono = monospaced || SyntaxEngine.hasHighlighting(doc.type)
        let style = NSMutableParagraphStyle()
        style.lineSpacing = monospaced ? 1 : size * 0.3
        let baseFont = useMono ? mono(size) : font(prefs, size: size)
        let out = NSMutableAttributedString(string: doc.lines.joined(separator: "\n"), attributes: [
            .font: baseFont, .foregroundColor: NSColor(theme.text), .paragraphStyle: style,
        ])
        var units: [NSRange] = []
        var offset = 0
        for (i, line) in doc.lines.enumerated() {
            let length = line.utf16.count
            units.append(NSRange(location: offset, length: length))
            if monospaced, doc.type == .markdown, line.hasPrefix("#") {
                out.addAttribute(.foregroundColor, value: NSColor(theme.heading), range: NSRange(location: offset, length: length))
            }
            if highlight {
                colorize(line, type: doc.type, state: doc.syntaxStates.isEmpty ? 0 : doc.syntaxStates[i],
                         offset: offset, theme: theme, into: out)
            }
            offset += length + 1
        }
        return Result(text: out, units: units)
    }

    /// Markdown as formatted text, one unit per block.
    static func markdown(_ blocks: [MDBlock], size: CGFloat, theme: Theme, prefs: Preferences) -> Result {
        let out = NSMutableAttributedString()
        var units: [NSRange] = []
        let text = NSColor(theme.text)
        let gap = size * 0.9
        let hs = CGFloat(prefs.headingSpacing)

        func para(_ f: (NSMutableParagraphStyle) -> Void) -> NSMutableParagraphStyle {
            let s = NSMutableParagraphStyle()
            f(s)
            return s
        }

        func inline(_ source: String, font: NSFont, color: NSColor) -> NSMutableAttributedString {
            let result = NSMutableAttributedString()
            let parsed = inlineMarkdown(source)
            for run in parsed.runs {
                var f = font
                var attrs: [NSAttributedString.Key: Any] = [.foregroundColor: color]
                if let intent = run.inlinePresentationIntent {
                    if intent.contains(.stronglyEmphasized) { f = NSFontManager.shared.convert(f, toHaveTrait: .boldFontMask) }
                    if intent.contains(.emphasized) { f = NSFontManager.shared.convert(f, toHaveTrait: .italicFontMask) }
                    if intent.contains(.code) {
                        f = mono(font.pointSize * 0.92)
                        attrs[.backgroundColor] = NSColor(theme.codeBackground)
                    }
                    if intent.contains(.strikethrough) { attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
                }
                if let link = run.link {
                    attrs[.link] = link
                    attrs[.foregroundColor] = NSColor(theme.accent)
                    attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
                }
                attrs[.font] = f
                result.append(NSAttributedString(string: String(parsed[run.range].characters), attributes: attrs))
            }
            return result
        }

        func append(_ piece: NSAttributedString, style: NSParagraphStyle, isLast: Bool, to unitStart: Int) {
            let m = NSMutableAttributedString(attributedString: piece)
            m.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: m.length))
            out.append(m)
            if !isLast { out.append(NSAttributedString(string: "\n")) }
        }

        for (index, block) in blocks.enumerated() {
            let start = out.length
            switch block {
            case .heading(let level, let t):
                let scale: [CGFloat] = [1.9, 1.55, 1.3, 1.15, 1.05, 1.0]
                let style = para {
                    $0.paragraphSpacingBefore = size * (level <= 2 ? 0.5 : 0.25) * hs
                    $0.paragraphSpacing = size * 0.15 * hs
                }
                append(inline(t, font: font(prefs, size: size * scale[level - 1], bold: true), color: NSColor(theme.heading)),
                       style: style, isLast: true, to: start)

            case .paragraph(let t):
                append(inline(t, font: font(prefs, size: size), color: text),
                       style: para { $0.lineSpacing = size * 0.35; $0.paragraphSpacing = gap }, isLast: true, to: start)

            case .bullets(let items), .numbered(let items):
                var numbered = false
                if case .numbered = block { numbered = true }
                for (i, item) in items.enumerated() {
                    let marker = numbered ? "\(i + 1).\t" : "•\t"
                    let line = NSMutableAttributedString(string: marker, attributes: [
                        .font: font(prefs, size: size), .foregroundColor: NSColor(theme.secondary)])
                    line.append(inline(item, font: font(prefs, size: size), color: text))
                    let last = i == items.count - 1
                    let style = para {
                        $0.lineSpacing = size * 0.3
                        $0.firstLineHeadIndent = 4
                        $0.headIndent = 28
                        $0.tabStops = [NSTextTab(textAlignment: .left, location: 28)]
                        $0.paragraphSpacing = last ? gap : size * 0.35
                    }
                    append(line, style: style, isLast: last, to: start)
                }

            case .code(let lang, let code):
                let source = code.isEmpty ? " " : code
                let f = mono(size * 0.9)
                let body = NSMutableAttributedString(string: source, attributes: [
                    .font: f, .foregroundColor: NSColor(theme.codeText), .backgroundColor: NSColor(theme.codeBackground)])
                if let type = FileType.fromFenceTag(lang), prefs.highlights(type) {
                    let codeLines = source.components(separatedBy: "\n")
                    let states = SyntaxEngine.states(codeLines, type: type)
                    var offset = 0
                    for (i, l) in codeLines.enumerated() {
                        colorize(l, type: type, state: states.isEmpty ? 0 : states[i], offset: offset, theme: theme, into: body)
                        offset += l.utf16.count + 1
                    }
                }
                append(body, style: para { $0.firstLineHeadIndent = 8; $0.headIndent = 8; $0.paragraphSpacing = gap }, isLast: true, to: start)

            case .quote(let t):
                let line = NSMutableAttributedString(string: "▎\t", attributes: [
                    .font: font(prefs, size: size), .foregroundColor: NSColor(theme.rule)])
                line.append(inline(t, font: font(prefs, size: size), color: NSColor(theme.secondary)))
                append(line, style: para {
                    $0.lineSpacing = size * 0.3
                    $0.headIndent = 18
                    $0.tabStops = [NSTextTab(textAlignment: .left, location: 18)]
                    $0.paragraphSpacing = gap
                }, isLast: true, to: start)

            case .rule:
                append(NSAttributedString(string: String(repeating: "─", count: 48), attributes: [
                    .font: font(prefs, size: size), .foregroundColor: NSColor(theme.rule)]),
                       style: para { $0.paragraphSpacing = gap }, isLast: true, to: start)

            case .table(let header, let rows):
                let all = [header] + rows
                let columns = all.map(\.count).max() ?? 0
                var widths = [CGFloat](repeating: 0, count: columns)
                let cellFont = font(prefs, size: size * 0.95)
                let plainRows = all.map { $0.map { String(inlineMarkdown($0).characters) } }
                for row in plainRows {
                    for (c, cell) in row.enumerated() {
                        widths[c] = max(widths[c], (cell as NSString).size(withAttributes: [.font: cellFont]).width)
                    }
                }
                var stops: [NSTextTab] = []
                var x: CGFloat = 0
                for w in widths.dropLast() { x += w + 28; stops.append(NSTextTab(textAlignment: .left, location: x)) }
                for (r, row) in plainRows.enumerated() {
                    let last = r == plainRows.count - 1
                    let line = NSAttributedString(string: row.joined(separator: "\t"), attributes: [
                        .font: r == 0 ? font(prefs, size: size * 0.95, bold: true) : cellFont, .foregroundColor: text])
                    append(line, style: para { $0.tabStops = stops; $0.paragraphSpacing = last ? gap : 4 }, isLast: last, to: start)
                }
            }
            units.append(NSRange(location: start, length: out.length - start))
            if index < blocks.count - 1 { out.append(NSAttributedString(string: "\n")) }
        }
        return Result(text: out, units: units)
    }
}

// MARK: - Line numbers

/// Gutter with line numbers; a click on a number toggles the bookmark of that line.
final class LineNumberRuler: NSRulerView {
    var lineStarts: [Int] = [0]
    var bookmarks: Set<Int> = [] { didSet { needsDisplay = true } }
    var onToggle: ((Int) -> Void)?
    var numberFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    var numberColor = NSColor.secondaryLabelColor
    var bookmarkColor = NSColor.systemOrange
    var background = NSColor.textBackgroundColor

    func setText(_ text: String) {
        var starts = [0]
        var i = 0
        for u in text.utf16 { i += 1; if u == 10 { starts.append(i) } }
        lineStarts = starts
        needsDisplay = true
    }

    /// 1-based line that contains the UTF-16 offset.
    private func line(at offset: Int) -> Int {
        var lo = 0, hi = lineStarts.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if lineStarts[mid] <= offset { lo = mid } else { hi = mid - 1 }
        }
        return lo + 1
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        background.setFill()
        bounds.fill()
        guard let tv = clientView as? NSTextView, let lm = tv.layoutManager, let tc = tv.textContainer,
              let clip = scrollView?.contentView else { return }
        let origin = tv.textContainerOrigin
        let glyphs = lm.glyphRange(forBoundingRect: clip.bounds, in: tc)
        let ns = tv.string as NSString
        lm.enumerateLineFragments(forGlyphRange: glyphs) { frag, _, _, fragGlyphs, _ in
            let ch = lm.characterIndexForGlyph(at: fragGlyphs.location)
            guard ch == 0 || ns.character(at: ch - 1) == 10 else { return }
            let n = self.line(at: ch)
            let on = self.bookmarks.contains(n)
            let label = NSAttributedString(string: "\(n)", attributes: [
                .font: self.numberFont, .foregroundColor: on ? self.bookmarkColor : self.numberColor])
            let size = label.size()
            let y = self.convert(NSPoint(x: 0, y: frag.minY + origin.y), from: tv).y
            label.draw(at: NSPoint(x: self.bounds.width - size.width - 10, y: y + (frag.height - size.height) / 2))
            if on {
                self.bookmarkColor.setFill()
                NSBezierPath(ovalIn: NSRect(x: 8, y: y + frag.height / 2 - 3.5, width: 7, height: 7)).fill()
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let tv = clientView as? NSTextView else { return }
        let p = tv.convert(event.locationInWindow, from: nil)
        let ch = tv.characterIndexForInsertion(at: NSPoint(x: tv.textContainerOrigin.x + 1, y: p.y))
        onToggle?(line(at: min(ch, (tv.string as NSString).length)))
    }
}

// MARK: - The text view

/// Read-only, selectable text for a whole document.
struct ReadOnlyTextView: NSViewRepresentable {
    /// Changes whenever `build` would give different text; the text is rebuilt only then.
    let contentKey: String
    let build: () -> TextBuilder.Result
    let theme: Theme
    let find: SearchHighlight?
    let scrollTarget: ScrollTarget?
    let initialScrollID: UUID?
    let grabFocus: Bool
    /// Reading column width (nil: the text fills the pane).
    var maxColumn: CGFloat?
    var numbers: Numbers?

    struct Numbers {
        let size: CGFloat
        let bookmarks: Set<Int>
        let toggle: (Int) -> Void
    }

    func makeCoordinator() -> Coordinator { Coordinator(handledScroll: initialScrollID) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        guard let view = scroll.documentView as? NSTextView else { return scroll }
        view.isEditable = false
        view.isSelectable = true
        view.isRichText = true
        view.usesFontPanel = false
        view.drawsBackground = true
        view.textContainerInset = NSSize(width: 14, height: 16)
        scroll.drawsBackground = true
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = false
        if maxColumn != nil {
            scroll.contentView.postsFrameChangedNotifications = true
            NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.frameChanged),
                                                   name: NSView.frameDidChangeNotification, object: scroll.contentView)
        }
        context.coordinator.scroll = scroll
        context.coordinator.view = view
        if grabFocus {
            DispatchQueue.main.async {
                guard let window = view.window, !(window.firstResponder is NSText) else { return }
                window.makeFirstResponder(view)
            }
        }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? NSTextView else { return }
        let c = context.coordinator
        c.parent = self
        view.backgroundColor = NSColor(theme.background)
        scroll.backgroundColor = NSColor(theme.background)
        view.linkTextAttributes = [.foregroundColor: NSColor(theme.accent), .underlineStyle: NSUnderlineStyle.single.rawValue]

        if c.contentKey != contentKey {
            c.contentKey = contentKey
            let built = build()
            c.units = built.units
            // The scroll position survives a rebuild (theme, font size, reload).
            let top = scroll.contentView.bounds.origin
            view.textStorage?.setAttributedString(built.text)
            c.paintedKey = ""
            scroll.contentView.scroll(to: top)
            scroll.reflectScrolledClipView(scroll.contentView)
            c.ruler?.setText(built.text.string)
        }
        c.configureRuler(scroll, view)
        c.updateInset()
        c.applyFind()
    }

    final class Coordinator: NSObject {
        var parent: ReadOnlyTextView!
        weak var scroll: NSScrollView?
        weak var view: NSTextView?
        var ruler: LineNumberRuler?
        var contentKey = ""
        var units: [NSRange] = []
        var paintedKey = ""
        private var handledScroll: UUID?

        init(handledScroll: UUID?) { self.handledScroll = handledScroll }
        deinit { NotificationCenter.default.removeObserver(self) }

        @objc func frameChanged() { updateInset() }

        /// Centers a column of at most `maxColumn` points in the pane.
        func updateInset() {
            guard let view, let scroll, let column = parent.maxColumn else { return }
            let side = max(36, (scroll.contentView.bounds.width - column) / 2)
            if abs(view.textContainerInset.width - side) > 0.5 {
                view.textContainerInset = NSSize(width: side, height: 20)
            }
        }

        func configureRuler(_ scroll: NSScrollView, _ view: NSTextView) {
            guard let numbers = parent.numbers else {
                if scroll.hasVerticalRuler { scroll.hasVerticalRuler = false; scroll.rulersVisible = false }
                ruler = nil
                return
            }
            if ruler == nil {
                let r = LineNumberRuler(scrollView: scroll, orientation: .verticalRuler)
                r.clientView = view
                r.ruleThickness = 58
                scroll.verticalRulerView = r
                scroll.hasVerticalRuler = true
                scroll.rulersVisible = true
                r.setText(view.string)
                ruler = r
            }
            guard let r = ruler else { return }
            r.numberFont = .monospacedSystemFont(ofSize: numbers.size * 0.8, weight: .regular)
            r.numberColor = NSColor(parent.theme.gutter)
            r.bookmarkColor = NSColor(parent.theme.bookmark)
            r.background = NSColor(parent.theme.background)
            r.onToggle = numbers.toggle
            if r.bookmarks != numbers.bookmarks { r.bookmarks = numbers.bookmarks }
        }

        /// Highlights every hit of the find query (temporary attributes, never part of the text), marks the
        /// current one and scrolls to it when asked to.
        func applyFind() {
            guard let view, let lm = view.layoutManager else { return }
            let query = parent.find?.query ?? ""
            let current = parent.find?.current
            let key = "\(contentKey)|\(query)|\(current.map { "\($0.unit):\($0.occurrence)" } ?? "-")"
            let ns = view.string as NSString

            func currentRange() -> NSRange? {
                guard let current, units.indices.contains(current.unit) else { return nil }
                let unit = units[current.unit]
                let piece = ns.substring(with: unit)
                let found = Searcher.ranges(of: query, in: piece)
                guard found.indices.contains(current.occurrence) else { return nil }
                let r = NSRange(found[current.occurrence], in: piece)
                return NSRange(location: unit.location + r.location, length: r.length)
            }

            if key != paintedKey {
                paintedKey = key
                lm.removeTemporaryAttribute(.backgroundColor, forCharacterRange: NSRange(location: 0, length: ns.length))
                if !query.isEmpty {
                    for (i, unit) in units.enumerated() {
                        let piece = ns.substring(with: unit)
                        for (k, r) in Searcher.ranges(of: query, in: piece).enumerated() {
                            let isCurrent = current == SearchMatch(unit: i, occurrence: k)
                            let local = NSRange(r, in: piece)
                            lm.addTemporaryAttribute(.backgroundColor,
                                                     value: NSColor(isCurrent ? parent.theme.currentMatch : parent.theme.match),
                                                     forCharacterRange: NSRange(location: unit.location + local.location, length: local.length))
                        }
                    }
                }
            }

            if let target = parent.scrollTarget, target.id != handledScroll {
                handledScroll = target.id
                let range = (current?.unit == target.unit ? currentRange() : nil)
                    ?? (units.indices.contains(target.unit) ? NSRange(location: units[target.unit].location, length: 0) : nil)
                if let range { reveal(range) }
            }
        }

        private func reveal(_ range: NSRange) {
            guard let view, let lm = view.layoutManager, let tc = view.textContainer, let scroll else { return }
            let glyphs = lm.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var rect = lm.boundingRect(forGlyphRange: glyphs, in: tc)
            rect.origin.y += view.textContainerOrigin.y
            let clip = scroll.contentView
            let y = max(0, min(rect.midY - clip.bounds.height / 2, view.frame.height - clip.bounds.height))
            clip.scroll(to: NSPoint(x: 0, y: y))
            scroll.reflectScrolledClipView(clip)
        }
    }
}
