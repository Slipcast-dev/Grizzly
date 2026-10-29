import SwiftUI
import AppKit

/// Plain-text editor for the open file. The draft lives in `AppState.drafts`, so switching tabs or modes keeps it.
struct EditorView: View {
    let document: Document
    let size: CGFloat

    @EnvironmentObject private var state: AppState
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            bar
            EditorTextView(
                text: Binding(
                    get: { state.text(for: document) },
                    set: { state.setDraft($0, for: document) }),
                font: .monospacedSystemFont(ofSize: size, weight: .regular),
                textColor: NSColor(theme.text),
                type: document.type,
                theme: theme,
                background: NSColor(theme.background))
                .id(document.id)
        }
    }

    private var bar: some View {
        let dirty = state.isDirty(document.id)
        return HStack(spacing: 10) {
            Text(dirty ? (document.type == .rtf ? "Есть несохранённые изменения. Форматирование RTF при сохранении будет потеряно." : "Есть несохранённые изменения.") : "Изменений нет.")
            Spacer()
            Button("Отменить изменения") { state.discardDraft(document.id) }
            Button("Сохранить  ⌘S") { state.save(document.id) }
                .font(.callout.weight(.semibold))
        }
        .font(.callout)
        .buttonStyle(.borderless)
        .disabled(!dirty)
        .foregroundColor(dirty ? theme.text : theme.secondary)
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
    let theme: Theme
    let background: NSColor

    func makeCoordinator() -> Coordinator { Coordinator(self) }

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
        view.isContinuousSpellCheckingEnabled = false
        view.textContainerInset = NSSize(width: 14, height: 12)
        view.string = text
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
    }

    private func style(_ view: NSTextView, _ scroll: NSScrollView) {
        view.font = font
        view.textColor = textColor
        view.insertionPointColor = textColor
        view.backgroundColor = background
        scroll.backgroundColor = background
        scroll.drawsBackground = true
        colorize(view)
    }

    /// Syntax colors for the whole text (skipped for very large files, where rescanning on every key would lag).
    private func colorize(_ view: NSTextView) {
        guard SyntaxEngine.hasHighlighting(type), let storage = view.textStorage else { return }
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
        init(_ parent: EditorTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            parent.text = view.string
        }
    }
}
