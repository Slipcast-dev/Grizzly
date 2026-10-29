import SwiftUI

func inlineMarkdown(_ s: String) -> AttributedString {
    let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    return (try? AttributedString(markdown: s, options: options)) ?? AttributedString(s)
}

struct MarkdownView: View {
    let blocks: [MDBlock]
    let size: CGFloat
    let highlight: SearchHighlight?
    @EnvironmentObject private var prefs: Preferences
    @Environment(\.theme) private var theme

    var body: some View {
        LazyVStack(alignment: .leading, spacing: size * 0.9) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                view(for: block, unit: index)
            }
        }
        .textSelection(.enabled)
    }

    private func text(_ s: String, unit: Int, offset: Int) -> Text {
        Text(inlineMarkdown(s).highlighted(highlight, unit: unit, offset: offset, theme: theme))
    }

    @ViewBuilder
    private func view(for block: MDBlock, unit: Int) -> some View {
        let offsets = Searcher.offsets(for: block, query: highlight?.query ?? "")

        switch block {
        case .heading(let level, let t):
            let scale: [CGFloat] = [1.9, 1.55, 1.3, 1.15, 1.05, 1.0]
            text(t, unit: unit, offset: offsets[0])
                .font(prefs.font(size: size * scale[level - 1], weight: .semibold))
                .foregroundColor(theme.heading)
                .padding(.top, size * (level <= 2 ? 0.5 : 0.25) * CGFloat(prefs.headingSpacing))
                .padding(.bottom, size * 0.15 * CGFloat(prefs.headingSpacing))

        case .paragraph(let t):
            text(t, unit: unit, offset: offsets[0])
                .font(prefs.font(size: size))
                .lineSpacing(size * 0.35)

        case .bullets(let items):
            VStack(alignment: .leading, spacing: size * 0.35) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundColor(theme.secondary)
                        text(item, unit: unit, offset: offsets[i]).lineSpacing(size * 0.3)
                    }
                }
            }
            .font(.system(size: size))

        case .numbered(let items):
            VStack(alignment: .leading, spacing: size * 0.35) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(i + 1).").foregroundColor(theme.secondary).monospacedDigit()
                        text(item, unit: unit, offset: offsets[i]).lineSpacing(size * 0.3)
                    }
                }
            }
            .font(.system(size: size))

        case .code(let lang, let code):
            ScrollView(.horizontal, showsIndicators: false) {
                Text((FileType.fromFenceTag(lang).map { Syntax.highlightBlock(code.isEmpty ? " " : code, type: $0, theme: theme) }
                        ?? AttributedString(code.isEmpty ? " " : code))
                        .highlighted(highlight, unit: unit, offset: offsets[0], theme: theme))
                    .font(.system(size: size * 0.9, design: .monospaced))
                    .foregroundColor(theme.codeText)
                    .padding(12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.codeBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))

        case .quote(let t):
            HStack(alignment: .top, spacing: 12) {
                Rectangle().fill(theme.rule).frame(width: 3)
                text(t, unit: unit, offset: offsets[0])
                    .font(.system(size: size))
                    .foregroundColor(theme.secondary)
                    .lineSpacing(size * 0.3)
            }

        case .rule:
            Divider().background(theme.rule)

        case .table(let header, let rows):
            // Cell order matches Searcher.segments: header first, then rows left to right.
            let rowStarts = rows.indices.map { r in header.count + rows[..<r].reduce(0) { $0 + $1.count } }
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 6) {
                GridRow {
                    ForEach(Array(header.enumerated()), id: \.offset) { c, cell in
                        text(cell, unit: unit, offset: offsets[c]).fontWeight(.semibold)
                    }
                }
                Divider().gridCellUnsizedAxes(.horizontal)
                ForEach(Array(rows.enumerated()), id: \.offset) { r, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { c, cell in
                            text(cell, unit: unit, offset: offsets[rowStarts[r] + c])
                        }
                    }
                }
            }
            .font(.system(size: size * 0.95))
        }
    }
}
