import SwiftUI
import AppKit

/// Plain-text editor for the open file. The draft lives in `AppState.drafts`, so switching tabs or modes keeps it.
struct EditorView: View {
    let document: Document
    let size: CGFloat
    let highlight: SearchHighlight?
    let isScrollTarget: Bool

    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var prefs: Preferences
    @Environment(\.theme) private var theme

    /// The newest version of the document: after a save the file is re-read under the same id, and the
    /// copy this view was created with would still hold the text from before the edit.
    private var live: Document { state.documents.first { $0.id == document.id } ?? document }

    var body: some View {
        let doc = live
        VStack(spacing: 0) {
            bar(doc)
            EditorTextView(
                text: Binding(
                    get: { state.text(for: doc) },
                    set: { state.setDraft($0, for: doc) }),
                font: .monospacedSystemFont(ofSize: size, weight: .regular),
                textColor: NSColor(theme.text),
                type: doc.type,
                highlightOn: prefs.highlights(doc.type),
                spellCheck: prefs.spellCheck && EditorView.isProse(doc.type),
                theme: theme,
                background: NSColor(theme.background),
                find: highlight,
                scrollTarget: isScrollTarget ? state.scrollTarget : nil,
                initialScrollID: state.scrollTarget?.id)
                .id(doc.id)
        }
    }

    /// Spelling and grammar are checked in prose; in source code and data files every identifier would be an "error".
    static func isProse(_ type: FileType) -> Bool { [.markdown, .text, .rtf, .tex].contains(type) }

    /// Undo and Save, in the same style as the other buttons. The status line is gone: saving and similar
    /// events are announced by notifications instead.
    private func bar(_ document: Document) -> some View {
        let dirty = state.isDirty(document.id)
        return HStack(spacing: 8) {
            Spacer()
            Button { NSApp.sendAction(Selector(("undo:")), to: nil, from: nil) } label: {
                Label("Отменить", systemImage: "arrow.uturn.backward")
            }
            .help("Отменить последний шаг (⌘Z)")
            Button { state.save(document.id) } label: {
                Label("Сохранить", systemImage: "square.and.arrow.down")
            }
            .help("Сохранить (⌘S)")
        }
        .buttonStyle(.hoverFilled)
        .disabled(!dirty)
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

/// NSTextView instead of SwiftUI's TextEditor so smart quotes, dash and text replacement stay off: this is a file editor.
private struct EditorTextView: NSViewRepresentable {
    @Binding var text: String
    let font: NSFont
    let textColor: NSColor
    let type: FileType
    let highlightOn: Bool
    let spellCheck: Bool
    let theme: Theme
    let background: NSColor
    let find: SearchHighlight?
    /// Set when this pane should jump to the current hit; compared by id with the last one handled.
    let scrollTarget: ScrollTarget?
    let initialScrollID: UUID?

    func makeCoordinator() -> Coordinator { Coordinator(self, handledScroll: initialScrollID) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        guard let view = scroll.documentView as? NSTextView else { return scroll }
        view.delegate = context.coordinator
        view.isRichText = false
        view.allowsUndo = true
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isAutomaticSpellingCorrectionEnabled = false
        view.isAutomaticLinkDetectionEnabled = false
        view.textContainerInset = NSSize(width: 14, height: 12)
        view.string = text
        // Russian and English are both checked: the checker picks the language of each phrase.
        NSSpellChecker.shared.automaticallyIdentifiesLanguages = true
        style(view, scroll)
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        // The text changed from outside (save, reload, revert): replace it and keep the caret in range.
        if view.string != text {
            let caret = view.selectedRange()
            view.string = text
            view.setSelectedRange(NSRange(location: min(caret.location, (text as NSString).length), length: 0))
        }
        style(view, scroll)
        context.coordinator.applyFind(to: view)
    }

    private func style(_ view: NSTextView, _ scroll: NSScrollView) {
        view.font = font
        view.textColor = textColor
        view.insertionPointColor = textColor
        view.backgroundColor = background
        scroll.backgroundColor = background
        scroll.drawsBackground = true
        if view.isContinuousSpellCheckingEnabled != spellCheck { view.isContinuousSpellCheckingEnabled = spellCheck }
        if view.isGrammarCheckingEnabled != spellCheck { view.isGrammarCheckingEnabled = spellCheck }
        colorize(view)
    }

    /// Syntax colors for the whole text (skipped for very large files, where rescanning on every key would lag).
    private func colorize(_ view: NSTextView) {
        if EditorView.isProse(type), let storage = view.textStorage {
            // #tags are colored like tokens; the background is reset first so a deleted '#' leaves nothing behind.
            storage.beginEditing()
            storage.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: storage.length))
            for (range, _) in LibraryStore.tagMatches(in: storage.string) {
                storage.addAttributes([.foregroundColor: NSColor(theme.accent),
                                       .backgroundColor: NSColor(theme.accent).withAlphaComponent(0.16)], range: range)
            }
            storage.endEditing()
        }
        guard highlightOn, SyntaxEngine.hasHighlighting(type), let storage = view.textStorage else { return }
        let text = view.string
        guard text.utf16.count <= 200_000 else { return }
        let lines = text.components(separatedBy: "\n")
        let states = SyntaxEngine.states(lines, type: type)
        storage.beginEditing()
        var offset = 0
        for (i, line) in lines.enumerated() {
            for span in SyntaxEngine.spans(line, type: type, state: states.isEmpty ? 0 : states[i]).spans {
                let range = NSRange(location: offset + span.range.location, length: span.range.length)
                storage.addAttribute(.foregroundColor, value: NSColor(Syntax.color(span.role, theme)), range: range)
            }
            offset += line.utf16.count + 1
        }
        storage.endEditing()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorTextView
        private var handledScroll: UUID?
        private var paintedKey = ""

        init(_ parent: EditorTextView, handledScroll: UUID?) {
            self.parent = parent
            self.handledScroll = handledScroll
        }

        private var isCompleting = false
        private var lastKind = 0
        private var lastWasSpace = false
        private var lastEdit = Date.distantPast

        /// Undo goes step by step: macOS merges a whole run of typing into one undo step, so a new step is started
        /// at every word, after a pause, when switching between typing and deleting, and for paste or Return.
        func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString: String?) -> Bool {
            let s = replacementString ?? ""
            let isSpace = s.utf16.count == 1 && s.rangeOfCharacter(from: .whitespaces) != nil
            // 1 typing one character, 2 deleting, 3 anything else (Return, paste, replacing a selection)
            let kind = s.isEmpty ? 2 : (s.utf16.count == 1 && !s.contains("\n") && range.length == 0 ? 1 : 3)
            let now = Date()
            if kind != lastKind || kind == 3 || (kind == 1 && lastWasSpace && !isSpace) || now.timeIntervalSince(lastEdit) > 1 {
                textView.breakUndoCoalescing()
            }
            lastKind = kind
            lastWasSpace = isSpace
            lastEdit = now
            return true
        }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            parent.text = view.string
            suggestTagIfTyping(in: view)
        }

        /// Typing `#` or `#wo` opens the list of known tags under the caret, like Apple Notes.
        private func suggestTagIfTyping(in view: NSTextView) {
            guard EditorView.isProse(parent.type), !isCompleting, view.selectedRange().length == 0,
                  let event = NSApp.currentEvent, event.type == .keyDown,
                  ![51, 117].contains(event.keyCode), event.characters?.isEmpty == false else { return }
            let ns = view.string as NSString
            var i = view.selectedRange().location
            while i > 0, Self.isTagChar(ns.character(at: i - 1)) { i -= 1 }
            guard i > 0, ns.character(at: i - 1) == 35 else { return }
            if i > 1, Self.isWordChar(ns.character(at: i - 2)) { return }
            isCompleting = true
            view.complete(nil)
            isCompleting = false
        }

        private static func isWordChar(_ c: unichar) -> Bool {
            // A lone surrogate is half of an emoji (or another astral character).
            guard let u = Unicode.Scalar(c) else { return true }
            return CharacterSet.alphanumerics.contains(u) || c == 95 || u.properties.isEmojiPresentation || c == 0x200D || c == 0xFE0F
        }
        private static func isTagChar(_ c: unichar) -> Bool { isWordChar(c) || c == 45 }

        func textView(_ textView: NSTextView, completions words: [String], forPartialWordRange charRange: NSRange,
                      indexOfSelectedItem index: UnsafeMutablePointer<Int>?) -> [String] {
            let ns = textView.string as NSString
            guard EditorView.isProse(parent.type), charRange.location > 0, ns.character(at: charRange.location - 1) == 35 else { return [] }
            let typed = ns.substring(with: charRange)
            let known = Set(AppState.shared.library.allTags + LibraryStore.extractTags(from: textView.string))
            return known
                .filter { $0.range(of: typed, options: [.caseInsensitive, .anchored]) != nil && $0.caseInsensitiveCompare(typed) != .orderedSame }
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        }

        /// Paints every hit of the find query (temporary attributes: they never become part of the text),
        /// marks the current one and scrolls to it when asked to.
        func applyFind(to view: NSTextView) {
            guard let layout = view.layoutManager else { return }
            let query = parent.find?.query ?? ""
            let text = view.string
            let current = parent.find?.current
            let key = "\(query)|\(current.map { "\($0.unit):\($0.occurrence)" } ?? "-")|\(text.hashValue)"

            if key != paintedKey {
                paintedKey = key
                let full = NSRange(location: 0, length: (text as NSString).length)
                layout.removeTemporaryAttribute(.backgroundColor, forCharacterRange: full)
                if !query.isEmpty {
                    let lines = text.components(separatedBy: "\n")
                    var offset = 0
                    for (i, line) in lines.enumerated() {
                        for (k, r) in Searcher.ranges(of: query, in: line).enumerated() {
                            let ns = NSRange(r, in: line)
                            let isCurrent = current == SearchMatch(unit: i, occurrence: k)
                            layout.addTemporaryAttribute(
                                .backgroundColor,
                                value: NSColor(isCurrent ? parent.theme.currentMatch : parent.theme.match),
                                forCharacterRange: NSRange(location: offset + ns.location, length: ns.length))
                        }
                        offset += line.utf16.count + 1
                    }
                }
            }

            if let target = parent.scrollTarget, target.id != handledScroll {
                handledScroll = target.id
                if let current, let range = Self.range(of: current, query: query, in: text) {
                    view.scrollRangeToVisible(range)
                    view.showFindIndicator(for: range)
                }
            }
        }

        static func range(of match: SearchMatch, query: String, in text: String) -> NSRange? {
            let lines = text.components(separatedBy: "\n")
            guard lines.indices.contains(match.unit) else { return nil }
            let found = Searcher.ranges(of: query, in: lines[match.unit])
            guard found.indices.contains(match.occurrence) else { return nil }
            let ns = NSRange(found[match.occurrence], in: lines[match.unit])
            let offset = lines[..<match.unit].reduce(0) { $0 + $1.utf16.count + 1 }
            return NSRange(location: offset + ns.location, length: ns.length)
        }
    }
}
