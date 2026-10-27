import SwiftUI

/// Preferences window (⌘,).
struct SettingsView: View {
    @EnvironmentObject private var settings: Preferences

    var body: some View {
        let theme = settings.theme

        VStack(alignment: .leading, spacing: 18) {
            section("Оформление") {
                Picker("", selection: $settings.appearance) {
                    ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(ThemeSet.all) { set in tile(set) }
                }
                Text("Dracula и Monokai всегда тёмные.")
                    .font(.caption).foregroundColor(.secondary)
            }

            section("Текст") {
                row("Шрифт") {
                    Picker("", selection: $settings.fontName) {
                        ForEach(Preferences.fonts, id: \.self) { Text(LocalizedStringKey($0)).tag($0) }
                    }
                    .labelsHidden().frame(width: 180)
                }
                row("Размер") {
                    Slider(value: $settings.fontSize, in: 10...28, step: 1)
                    Text("\(Int(settings.fontSize)) pt").monospacedDigit().frame(width: 48, alignment: .trailing)
                }
                row("Отступы заголовков") {
                    Slider(value: $settings.headingSpacing, in: 0.5...2.5, step: 0.1)
                    Text(String(format: "×%.1f", settings.headingSpacing)).monospacedDigit().frame(width: 48, alignment: .trailing)
                }
                Toggle("Показывать номера строк", isOn: $settings.showLineNumbers)
            }

            section("Файлы") {
                Toggle("Обновлять файл автоматически, когда он изменился на диске", isOn: $settings.autoReload)
            }

            preview(theme)
        }
        .padding(22)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func section<C: View>(_ title: LocalizedStringKey, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
    }

    private func row<C: View>(_ label: LocalizedStringKey, @ViewBuilder _ content: () -> C) -> some View {
        HStack {
            Text(label).frame(width: 150, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
    }

    private func tile(_ set: ThemeSet) -> some View {
        let t = set.variant(dark: settings.wantsDark)
        let selected = settings.themeID == set.id
        return Button { settings.themeID = set.id } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 3) {
                    ForEach([t.heading, t.key, t.string, t.keyword], id: \.self) { c in
                        Circle().fill(c).frame(width: 8, height: 8)
                    }
                }
                Text(set.name).font(.callout.weight(.medium)).foregroundColor(t.text).lineLimit(1)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(t.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(selected ? Color.accentColor : Color.gray.opacity(0.35), lineWidth: selected ? 2.5 : 1))
        }
        .buttonStyle(.plain)
    }

    private func preview(_ t: Theme) -> some View {
        let size = CGFloat(settings.fontSize)
        let h = CGFloat(settings.headingSpacing)
        return VStack(alignment: .leading, spacing: 0) {
            Text("Заголовок").font(settings.font(size: size * 1.5, weight: .semibold)).foregroundColor(t.heading)
                .padding(.top, size * 0.3 * h).padding(.bottom, size * 0.2 * h)
            Text("Так будет выглядеть обычный текст документа.").font(settings.font(size: size)).foregroundColor(t.text)
            HStack(spacing: 8) {
                if settings.showLineNumbers { Text("1").foregroundColor(t.gutter) }
                Text("\"key\": ").foregroundColor(t.key) + Text("\"value\"").foregroundColor(t.string)
            }
            .font(.system(size: size * 0.85, design: .monospaced))
            .padding(.top, 8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.35)))
    }
}
