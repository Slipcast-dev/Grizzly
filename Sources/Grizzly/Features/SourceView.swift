import SwiftUI

/// Raw text with a line-number gutter. Clicking a number toggles a bookmark on that line.
struct SourceView: View {
    let document: Document
    let size: CGFloat
    let highlight: SearchHighlight?
    /// True when this pane is the one that should react to scroll requests.
    let isScrollTarget: Bool

    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var prefs: Preferences
    @Environment(\.theme) private var theme

    var body: some View {
        let bookmarked = Set(library.bookmarks(for: document.libraryID))

        ScrollViewReader { proxy in
            ScrollView([.vertical]) {
                RowStack(lazy: document.lines.count > RowStackLimit.rows) {
                    ForEach(Array(document.lines.enumerated()), id: \.offset) { index, line in
                        HStack(alignment: .top, spacing: 0) {
                            if prefs.showLineNumbers {
                                gutter(number: index + 1, isBookmarked: bookmarked.contains(index + 1))
                            }
                            Text(Syntax.highlight(line.isEmpty ? " " : line, type: document.type, theme: theme, state: document.syntaxStates.isEmpty ? 0 : document.syntaxStates[index])
                                    .highlighted(highlight, unit: index, offset: 0, theme: theme))
                                .font(.system(size: size, design: .monospaced))
                                .foregroundColor(color(for: line))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.trailing, 20)
                                .padding(.leading, prefs.showLineNumbers ? 0 : 20)
                        }
                        .padding(.vertical, 1)
                    }
                }
                .padding(.vertical, 12)
                .textSelection(.enabled)
            }
            .onChange(of: state.scrollTarget) { target in
                guard isScrollTarget, let target else { return }
                withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(target.unit, anchor: .center) }
            }
        }
    }

    private func gutter(number: Int, isBookmarked: Bool) -> some View {
        ZStack(alignment: .trailing) {
            if isBookmarked {
                Circle()
                    .fill(theme.bookmark)
                    .frame(width: 7, height: 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 8)
            }
            Text("\(number)")
                .font(.system(size: size * 0.8, design: .monospaced))
                .foregroundColor(isBookmarked ? theme.bookmark : theme.gutter)
        }
        .frame(width: 46)
        .padding(.trailing, 12)
        .padding(.top, 2)
        .contentShape(Rectangle())
        .onTapGesture { library.toggleBookmark(document.libraryID, line: number) }
        .help(LocalizedStringKey(isBookmarked ? "Убрать закладку" : "Поставить закладку"))
    }

    private func color(for line: String) -> Color {
        document.type == .markdown && line.hasPrefix("#") ? theme.heading : theme.text
    }
}

/// Vertical stack of text rows. A plain stack lets one drag (or Select All) select across every row; a lazy stack
/// only builds the visible rows, so it is used just for very long documents, where building everything would be slow.
enum RowStackLimit { static let rows = 4000 }

struct RowStack<Content: View>: View {
    let lazy: Bool
    var spacing: CGFloat = 0
    @ViewBuilder let content: () -> Content

    var body: some View {
        if lazy {
            LazyVStack(alignment: .leading, spacing: spacing, content: content)
        } else {
            VStack(alignment: .leading, spacing: spacing, content: content)
        }
    }
}
