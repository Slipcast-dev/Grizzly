import SwiftUI

/// The file changed on disk while it had unsaved edits: shows the differences and offers to merge, keep or take the disk copy.
struct MergeView: View {
    let model: AppState.MergeModel
    @EnvironmentObject private var state: AppState
    @Environment(\.theme) private var theme

    private var changes: Int { model.rows.filter { $0.op != .equal }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Файл «%@» изменён на диске", model.name)).font(AppFont.headline)
            Text("Красным — строки, которые есть только на диске; зелёным — только в вашем тексте.")
                .font(AppFont.callout).foregroundColor(theme.secondary)

            ScrollView([.vertical, .horizontal]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(model.rows.enumerated()), id: \.offset) { _, row in
                        if row.op != .equal || model.rows.count < 400 {
                            Text(prefix(row.op) + row.text)
                                .font(.system(.callout, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 6)
                                .background(color(row.op))
                        }
                    }
                }
            }
            .frame(minHeight: 260)
            .background(theme.codeBackground.opacity(0.5))
            .cornerRadius(6)

            if model.merged.conflicts > 0 {
                Label(L("При объединении будет конфликтов: %d. Они отмечаются как <<<<<<< / ======= / >>>>>>>.", model.merged.conflicts),
                      systemImage: "exclamationmark.triangle.fill")
                    .font(AppFont.callout).foregroundColor(theme.warning)
            }

            HStack {
                Button("Взять с диска") { state.merge = nil; state.reload(model.id) }
                Button("Оставить мой текст") { state.merge = nil; state.ignoreChange(model.id) }
                Spacer()
                Button("Отмена") { state.merge = nil }
                Button("Объединить") { state.applyMerge(model) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 720, height: 460)
    }

    private func prefix(_ op: LineDiff.Op) -> String { op == .insert ? "+ " : op == .delete ? "− " : "  " }

    // The diff runs from my text to the disk copy: an "insert" is a line only the disk has.
    private func color(_ op: LineDiff.Op) -> Color {
        switch op {
        case .equal: return .clear
        case .insert: return Color.red.opacity(0.18)
        case .delete: return Color.green.opacity(0.18)
        }
    }
}
