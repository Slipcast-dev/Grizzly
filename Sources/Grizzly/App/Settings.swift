import SwiftUI

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return L("Как в системе")
        case .light: return L("Светлая")
        case .dark: return L("Тёмная")
        }
    }
}

/// Interface language. `auto` follows the system: Russian on a Russian system, English otherwise.
enum AppLanguage: String, CaseIterable, Identifiable {
    case auto, ru, en
    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: return L("Как в системе")
        case .ru: return "Русский"
        case .en: return "English"
        }
    }

    /// The choice in effect, read from the app's own defaults domain (before the first change it is `auto`).
    static var saved: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "language") ?? "") ?? .auto
    }

    /// macOS picks the bundle language from `AppleLanguages` at launch, so the choice takes effect after a restart.
    func apply() {
        let d = UserDefaults.standard
        d.set(rawValue, forKey: "language")
        if self == .auto { d.removeObject(forKey: "AppleLanguages") } else { d.set([rawValue], forKey: "AppleLanguages") }
    }
}

/// User preferences, saved to UserDefaults on every change.
final class Preferences: ObservableObject {
    static let shared = Preferences()

    static let systemFont = "Системный"
    static let fonts = [systemFont, "Georgia", "Palatino", "Times New Roman", "Helvetica Neue", "Avenir Next", "Menlo"]

    private let defaults = UserDefaults.standard

    @Published var appearance: Appearance { didSet { defaults.set(appearance.rawValue, forKey: "appearance") } }
    @Published var themeID: String { didSet { defaults.set(themeID, forKey: "themeID") } }
    @Published var fontName: String { didSet { defaults.set(fontName, forKey: "fontName") } }
    @Published var fontSize: Double { didSet { defaults.set(fontSize, forKey: "fontSize") } }
    /// Multiplier for the space around Markdown headings.
    @Published var headingSpacing: Double { didSet { defaults.set(headingSpacing, forKey: "headingSpacing") } }
    @Published var showLineNumbers: Bool { didSet { defaults.set(showLineNumbers, forKey: "showLineNumbers") } }
    @Published var autoReload: Bool { didSet { defaults.set(autoReload, forKey: "autoReload") } }
    /// Syntax coloring: a master switch plus a list of file types that are switched off individually.
    @Published var syntaxEnabled: Bool { didSet { defaults.set(syntaxEnabled, forKey: "syntaxEnabled") } }
    @Published var syntaxOff: Set<String> { didSet { defaults.set(syntaxOff.sorted(), forKey: "syntaxOff") } }
    @Published var language: AppLanguage { didSet { language.apply() } }
    @Published private(set) var systemIsDark: Bool

    private init() {
        let d = UserDefaults.standard
        appearance = Appearance(rawValue: d.string(forKey: "appearance") ?? "") ?? .system
        themeID = d.string(forKey: "themeID") ?? "xcode"
        fontName = d.string(forKey: "fontName") ?? Preferences.systemFont
        fontSize = d.object(forKey: "fontSize") as? Double ?? 15
        headingSpacing = d.object(forKey: "headingSpacing") as? Double ?? 1
        showLineNumbers = d.object(forKey: "showLineNumbers") as? Bool ?? true
        autoReload = d.object(forKey: "autoReload") as? Bool ?? false
        syntaxEnabled = d.object(forKey: "syntaxEnabled") as? Bool ?? true
        syntaxOff = Set(d.stringArray(forKey: "syntaxOff") ?? [])
        language = AppLanguage.saved
        systemIsDark = Preferences.readSystemDark()

        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"), object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self?.systemIsDark = Preferences.readSystemDark() }
        }
    }

    private static func readSystemDark() -> Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    var wantsDark: Bool {
        switch appearance {
        case .system: return systemIsDark
        case .light: return false
        case .dark: return true
        }
    }

    func highlights(_ type: FileType) -> Bool { syntaxEnabled && !syntaxOff.contains(type.rawValue) }

    func setHighlight(_ type: FileType, _ on: Bool) {
        if on { syntaxOff.remove(type.rawValue) } else { syntaxOff.insert(type.rawValue) }
    }

    var theme: Theme { ThemeSet.find(themeID).variant(dark: wantsDark) }

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        fontName == Preferences.systemFont ? .system(size: size, weight: weight) : .custom(fontName, size: size).weight(weight)
    }

    func resizeFont(by delta: Double) { fontSize = min(28, max(10, fontSize + delta)) }
}
