import SwiftUI

/// One reading pane. In split view there are two, each with its own document.
struct PaneView: View {
    let pane: Pane
    let fontSize: CGFloat
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var prefs: Preferences
    @Environment(\.theme) private var theme

    var body: some View {
        let doc = state.doc(in: pane)

        VStack(spacing: 0) {
            if state.isSplit { header(doc) }
            if let doc {
                if state.changedOnDisk.contains(doc.id) { changedBanner(doc) }
                content(for: doc)
                StatusBar(document: doc)
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
        .simultaneousGesture(TapGesture().onEnded { state.focus(pane) })
    }

    // MARK: Header (split view only)

    private func header(_ doc: Document?) -> some View {
        HStack(spacing: 6) {
            Menu {
                ForEach(state.documents) { d in
                    Button { state.assign(d.id, to: pane) } label: {
                        Label(d.name, systemImage: d.type.symbol)
                    }
                }
                Divider()
                Button("Открыть файл…") {
                    state.focus(pane)
                    state.presentOpenPanel()
                }
            } label: {
                Label(doc?.name ?? L("Выберите файл"), systemImage: doc?.type.symbol ?? "doc")
                    .lineLimit(1)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            if pane == .right {
                Button { state.toggleSplit() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .foregroundColor(theme.secondary)
                    .help("Закрыть правую панель")
            }
        }
        .font(.callout)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(theme.codeBackground.opacity(0.5))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(state.focusedPane == pane ? theme.accent : theme.rule.opacity(0.5))
                .frame(height: state.focusedPane == pane ? 2 : 0.5)
        }
    }

    private func changedBanner(_ doc: Document) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath").foregroundColor(theme.warning)
            Text("Файл изменён на диске.")
            Spacer()
            Button("Обновить  ⌘R") { state.refresh(doc.id) }
            Button("Не сейчас") { state.ignoreChange(doc.id) }
        }
        .font(.callout)
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.warning.opacity(0.18))
        .overlay(alignment: .bottom) { Divider() }
    }

    private var placeholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.righthalf.inset.filled")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(theme.secondary)
            Text("Выберите файл для этой панели")
                .foregroundColor(theme.secondary)
            Text("Откройте его из списка слева с зажатым ⌥ или выберите во вкладках.")
                .font(.caption)
                .foregroundColor(theme.secondary)
                .multilineTextAlignment(.center)
            Button("Открыть файл…") {
                state.focus(pane)
                state.presentOpenPanel()
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Content

    /// Every pane paints the query; only the focused one marks the current hit and scrolls to it.
    private var isTargetPane: Bool { !state.isSplit || state.focusedPane == pane }

    private var highlight: SearchHighlight? {
        guard state.isFindVisible, !state.findQuery.isEmpty else { return nil }
        return SearchHighlight(query: state.findQuery, current: isTargetPane ? state.currentMatch : nil)
    }

    @ViewBuilder
    private func content(for doc: Document) -> some View {
        if state.mode == .edit {
            EditorView(document: doc, size: fontSize - 2)
        } else if state.mode == .source {
            SourceView(document: doc, size: fontSize - 2, highlight: highlight, isScrollTarget: isTargetPane)
        } else if let table = doc.csv {
            CSVTableView(table: table, size: fontSize - 1, highlight: highlight, isScrollTarget: isTargetPane)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    Group {
                        if doc.type == .markdown {
                            MarkdownView(blocks: doc.blocks, size: fontSize, highlight: highlight)
                        } else {
                            plainText(doc)
                        }
                    }
                    .frame(maxWidth: 760, alignment: .leading)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: state.scrollTarget) { target in
                    guard isTargetPane, let target else { return }
                    withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(target.unit, anchor: .center) }
                }
            }
        }
    }

    /// One row per line, so search hits can be scrolled to.
    private func plainText(_ doc: Document) -> some View {
        RowStack(lazy: doc.lines.count > RowStackLimit.rows) {
            ForEach(Array(doc.lines.enumerated()), id: \.offset) { index, line in
                Text(Syntax.highlight(line.isEmpty ? " " : line, type: doc.type, theme: theme, state: doc.syntaxStates.isEmpty ? 0 : doc.syntaxStates[index])
                        .highlighted(highlight, unit: index, offset: 0, theme: theme))
                    .font(Syntax.hasHighlighting(doc.type) ? .system(size: fontSize, design: .monospaced) : prefs.font(size: fontSize))
                    .lineSpacing(fontSize * 0.3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .textSelection(.enabled)
    }
}

struct StatusBar: View {
    let document: Document
    @Environment(\.theme) private var theme

    var body: some View {
        HStack {
            Text("\(document.type.title) · \(document.encoding)")
            Spacer()
            Text("\(document.lines.count) строк · \(document.wordCount) слов")
        }
        .font(.caption)
        .foregroundColor(theme.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .overlay(alignment: .top) { Divider() }
    }
}
