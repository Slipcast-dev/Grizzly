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

/// Bottom of the sidebar, like the tag browser in Apple Notes: "All Tags" plus a chip per tag. Chips toggle, and
/// several selected tags show the files that carry all of them. Tags are the #words written in the files.
struct TagPanel: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.theme) private var theme

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
                Text("Напишите #тег в тексте файла, и он появится здесь. Или создайте тег кнопкой +.")
                    .font(.caption).foregroundColor(.secondary)
            } else {
                ScrollView {
                    FlowLayout(spacing: 6) {
                        chip(title: L("Все теги"), on: state.selectedTags.isEmpty, count: nil) { state.selectedTags = [] }
                        ForEach(library.allTags, id: \.self) { tag in
                            chip(title: "#\(tag)", on: state.isTagSelected(tag), count: library.files(withTag: tag).count) {
                                state.toggleTagSelection(tag)
                            }
                            .contextMenu {
                                Button("Переименовать…") { rename(tag) }
                                Button("Удалить тег", role: .destructive) { state.deleteTag(tag) }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 110)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(alignment: .top) { Divider() }
    }

    private func chip(title: String, on: Bool, count: Int?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title).lineLimit(1)
                if let count { Text("\(count)").font(.caption2).opacity(0.7) }
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundColor(on ? .white : .primary)
            .background(Capsule().fill(on ? theme.accent : Color.primary.opacity(0.09)))
        }
        .buttonStyle(.plain)
    }

    private func create() {
        guard let name = TextPrompt.ask(title: L("Новый тег"), confirm: L("Создать")),
              let tag = library.createTag(name) else { return }
        state.selectedTags = [tag]
    }

    private func rename(_ tag: String) {
        guard let name = TextPrompt.ask(title: L("Переименовать тег"), initial: tag, confirm: L("Переименовать")) else { return }
        state.renameTag(tag, to: name)
    }
}
