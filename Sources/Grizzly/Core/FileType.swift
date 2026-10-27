import Foundation

enum FileType: String, CaseIterable {
    case markdown, text, json, yaml, csv, log, xml, html, config, tex, rtf

    static let extensions: [String: FileType] = [
        "md": .markdown, "markdown": .markdown, "mdown": .markdown,
        "txt": .text, "text": .text,
        "json": .json,
        "yaml": .yaml, "yml": .yaml,
        "csv": .csv, "tsv": .csv,
        "log": .log,
        "xml": .xml,
        "html": .html, "htm": .html,
        "ini": .config, "conf": .config, "toml": .config,
        "tex": .tex,
        "rtf": .rtf,
    ]

    static var allExtensions: [String] { Array(extensions.keys).sorted() }

    init(url: URL) {
        self = FileType.extensions[url.pathExtension.lowercased()] ?? .text
    }

    var title: String {
        switch self {
        case .markdown: return "Markdown"
        case .text: return "Text"
        case .json: return "JSON"
        case .yaml: return "YAML"
        case .csv: return "CSV"
        case .log: return "Log"
        case .xml: return "XML"
        case .html: return "HTML"
        case .config: return "Config"
        case .tex: return "TeX"
        case .rtf: return "RTF"
        }
    }

    var symbol: String {
        switch self {
        case .markdown, .rtf: return "doc.richtext"
        case .json: return "curlybraces"
        case .yaml, .config, .xml, .html, .tex: return "doc.text"
        case .csv: return "tablecells"
        case .log: return "list.bullet.rectangle"
        case .text: return "doc.plaintext"
        }
    }
}
