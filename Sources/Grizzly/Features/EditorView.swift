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

    private func bar(_ document: Document) -> some View {
        let dirty = state.isDirty(document.id)
        return HStack(spacing: 10) {
            Text(dirty ? (document.type == .rtf ? "Есть несохранённые изменения. Форматирование RTF при сохранении будет потеряно." : "Есть несохранённые изменения.") : "Изменений нет.")
                .foregroundColor(dirty ? theme.text : theme.secondary)
            Spacer()
            Button { NSApp.orderFrontCharacterPalette(nil) } label: { Text("😀") }
                .help("Эмодзи и символы (⌃⌘Пробел)")
            Group {
                Button("Отменить изменения") { state.discardDraft(document.id) }
                Button("Сохранить  ⌘S") { state.save(document.id) }
                    .font(.callout.weight(.semibold))
            }
            .disabled(!dirty)
            .foregroundColor(dirty ? theme.text : theme.secondary)
        }
        .font(.callout)
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(dirty ? theme.warning.opacity(0.18) : Color.clear)
        .overlay(alignment: .bottom) { Divider() }
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

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            parent.text = view.string
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
