import SwiftUI

/// Raw text with a line-number gutter. Clicking a number toggles a bookmark on that line.
/// One selectable text view: a drag (or ⌘A) selects across lines and ⌘C copies it.
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
        let key = ["src", document.id.uuidString, "\(document.modified?.timeIntervalSince1970 ?? 0)", "\(size)", prefs.themeID,
                   "\(prefs.wantsDark)", "\(prefs.syntaxEnabled)", prefs.syntaxOff.sorted().joined(separator: ",")].joined(separator: "|")
        ReadOnlyTextView(
            contentKey: key,
            build: { TextBuilder.lines(document, size: size, theme: theme, prefs: prefs, monospaced: true) },
            theme: theme,
            find: highlight,
            scrollTarget: isScrollTarget ? state.scrollTarget : nil,
            initialScrollID: state.scrollTarget?.id,
            grabFocus: isScrollTarget,
            numbers: prefs.showLineNumbers
                ? .init(size: size, bookmarks: bookmarked, toggle: { line in
                    library.toggleBookmark(document.libraryID, line: line)
                    state.notify(bookmarked.contains(line) ? L("Закладка убрана.") : L("Закладка добавлена: строка %lld.", line), symbol: "bookmark.fill")
                })
                : nil)
            .id("\(document.id)-\(prefs.showLineNumbers)")
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
