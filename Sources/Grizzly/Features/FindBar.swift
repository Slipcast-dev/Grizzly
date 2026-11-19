import SwiftUI

struct FindBar: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.theme) private var theme
    @FocusState private var focused: Bool

    private var invalid: Bool { !TextSearch.isValid(state.findQuery, state.findOptions) }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button { state.isReplaceVisible.toggle() } label: {
                    Image(systemName: state.isReplaceVisible ? "chevron.down" : "chevron.right")
                }
                .help("Заменить")
                Image(systemName: "magnifyingglass").foregroundColor(theme.secondary)

                TextField("Найти в документе", text: $state.findQuery)
                    .textFieldStyle(.plain)
                    .foregroundColor(invalid ? .red : theme.text)
                    .focused($focused)
                    .onSubmit { state.stepMatch(NSEvent.modifierFlags.contains(.shift) ? -1 : 1) }
                    .onExitCommand { state.hideFind() }

                toggle("textformat", on: $state.findOptions.caseSensitive, help: "Учитывать регистр")
                toggle("text.word.spacing", on: $state.findOptions.wholeWord, help: "Слово целиком")
                toggle("asterisk", on: $state.findOptions.regex, help: "Регулярное выражение")

                Text(countLabel)
                    .font(AppFont.caption)
                    .foregroundColor(invalid ? .red : theme.secondary)
                    .monospacedDigit()

                Button { state.stepMatch(-1) } label: { Image(systemName: "chevron.up") }
                    .help("Предыдущее совпадение (⌘⇧G)")
                Button { state.stepMatch(1) } label: { Image(systemName: "chevron.down") }
                    .help("Следующее совпадение (⌘G)")
                Button("Готово") { state.hideFind() }
                    .buttonStyle(.hoverText)
            }
            if state.isReplaceVisible {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left.arrow.right").foregroundColor(theme.secondary)
                    TextField("Заменить на", text: $state.replaceText)
                        .textFieldStyle(.plain)
                        .onSubmit { state.replaceCurrent() }
                        .onExitCommand { state.hideFind() }
                    Button("Заменить") { state.replaceCurrent() }
                        .disabled(state.currentMatch == nil)
                    Button("Заменить все") { state.replaceAll() }
                        .disabled(state.matches.isEmpty)
                }
            }
        }
        .buttonStyle(.hover)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.codeBackground.opacity(0.6))
        .overlay(alignment: .bottom) { Divider() }
        .onAppear { focused = true }
        .onChange(of: state.findFocusToken) { _ in focused = true }
    }

    private func toggle(_ symbol: String, on: Binding<Bool>, help: LocalizedStringKey) -> some View {
        Button { on.wrappedValue.toggle() } label: {
            Image(systemName: symbol)
                .padding(3)
                .background(RoundedRectangle(cornerRadius: 4).fill(on.wrappedValue ? theme.match : .clear))
        }
        .help(help)
    }

    private var countLabel: String {
        if state.findQuery.isEmpty { return "" }
        if invalid { return L("Неверное выражение") }
        if state.matches.isEmpty { return L("Нет совпадений") }
        return L("%d из %d", state.matchIndex + 1, state.matches.count)
    }
}

struct BookmarksButton: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.theme) private var theme
    @State private var shown = false

    private var lines: [Int] { library.bookmarks(for: state.current?.libraryID) }

    var body: some View {
        Button { shown.toggle() } label: {
            Image(systemName: lines.isEmpty ? "bookmark" : "bookmark.fill")
        }
        .buttonStyle(.hover)
        .help("Закладки")
        .disabled(state.current == nil)
        .popover(isPresented: $shown, arrowEdge: .bottom) { list }
    }

    @ViewBuilder
    private var list: some View {
        let doc = state.current
        VStack(alignment: .leading, spacing: 6) {
            Text("Закладки").font(AppFont.headline)
            if lines.isEmpty {
                Text("Пока нет закладок. В режиме «Исходник» нажмите на номер строки, чтобы поставить закладку.")
                    .font(AppFont.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(lines, id: \.self) { line in
                            row(line, doc: doc)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private func row(_ line: Int, doc: Document?) -> some View {
        let preview = doc.flatMap { $0.lines.indices.contains(line - 1) ? $0.lines[line - 1] : nil } ?? ""
        return HStack(spacing: 8) {
            Button {
                shown = false
                state.goToLine(line - 1)
            } label: {
                HStack(spacing: 8) {
                    Text("\(line)")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundColor(theme.bookmark)
                        .frame(width: 36, alignment: .trailing)
                    Text(preview.trimmingCharacters(in: .whitespaces).isEmpty ? L("(пустая строка)") : preview)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button { library.toggleBookmark(doc?.libraryID, line: line) } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Убрать закладку")
        }
        .padding(.vertical, 3)
    }
}

/// Headings of the open document; a click scrolls the editor to the heading.
struct OutlineButton: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.theme) private var theme
    @State private var shown = false

    private var headings: [(line: Int, level: Int, title: String)] {
        guard let doc = state.current else { return [] }
        return Outline.items(state.text(for: doc), type: doc.type).map { ($0.line, $0.level, $0.title) }
    }

    var body: some View {
        Button { shown.toggle() } label: { Image(systemName: "list.bullet.indent") }
            .buttonStyle(.hover)
            .help("Оглавление")
            .disabled(headings.isEmpty)
            .popover(isPresented: $shown, arrowEdge: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(headings, id: \.line) { h in
                            Button {
                                shown = false
                                state.scrollTarget = ScrollTarget(unit: h.line)
                            } label: {
                                Text(h.title)
                                    .lineLimit(1)
                                    .padding(.leading, CGFloat(h.level - 1) * 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 3)
                        }
                    }
                    .padding(14)
                }
                .frame(width: 300)
                .frame(maxHeight: 360)
            }
    }
}
