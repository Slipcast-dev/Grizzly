import AppKit
import SwiftUI

/// A one-line text question (tag name) as a system alert. Nil when cancelled or left empty.
enum TextPrompt {
    static func ask(title: String, message: String = "", initial: String = "", confirm: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: confirm)
        alert.addButton(withTitle: L("Отмена"))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = initial
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

/// Chips that wrap onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, width: proposal.width ?? 220).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(subviews, width: bounds.width)
        for (i, origin) in result.origins.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> (origins: [CGPoint], size: CGSize) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (origins, CGSize(width: maxX, height: y + rowHeight))
    }
}

/// Bottom of the sidebar: every tag as a chip. A click shows the files that carry the tag, a second click leaves the filter.
struct TagPanel: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.theme) private var theme
    @Binding var selected: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Теги", systemImage: "tag").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                Spacer()
                Button { create() } label: { Image(systemName: "plus") }
                    .buttonStyle(HoverButtonStyle(size: .compact))
                    .help("Новый тег")
            }
            if library.allTags.isEmpty {
                Text("Создайте тег кнопкой + или через контекстное меню файла.")
                    .font(.caption).foregroundColor(.secondary)
            } else {
                ScrollView {
                    FlowLayout(spacing: 6) {
                        ForEach(library.allTags, id: \.self) { tag in chip(tag) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 96)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(alignment: .top) { Divider() }
    }

    private func chip(_ tag: String) -> some View {
        let on = selected?.caseInsensitiveCompare(tag) == .orderedSame
        let count = library.files(withTag: tag).count
        return Button { selected = on ? nil : tag } label: {
            HStack(spacing: 4) {
                Text("#\(tag)").lineLimit(1)
                Text("\(count)").font(.caption2).opacity(0.7)
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundColor(on ? .white : .primary)
            .background(Capsule().fill(on ? theme.accent : Color.primary.opacity(0.09)))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Переименовать…") { rename(tag) }
            Button("Удалить тег", role: .destructive) {
                if on { selected = nil }
                library.deleteTag(tag)
            }
        }
    }

    private func create() {
        guard let name = TextPrompt.ask(title: L("Новый тег"), confirm: L("Создать")),
              let tag = library.createTag(name) else { return }
        selected = tag
    }

    private func rename(_ tag: String) {
        guard let name = TextPrompt.ask(title: L("Переименовать тег"), initial: tag, confirm: L("Переименовать")) else { return }
        let wasSelected = selected?.caseInsensitiveCompare(tag) == .orderedSame
        library.renameTag(tag, to: name)
        if wasSelected { selected = LibraryStore.cleanTag(name) }
    }
}
