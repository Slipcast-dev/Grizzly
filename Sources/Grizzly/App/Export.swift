import AppKit
import WebKit
import PDFKit

/// Export of the open document to HTML and PDF. The HTML is the same one Quick Look shows.
enum DocumentExport {
    static func html(title: String, url: URL, type: FileType, text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        let body: String
        switch type {
        case .markdown: body = HTMLRenderer.markdown(lines)
        case .csv: body = HTMLRenderer.csv(url: url, lines: lines)
        default: body = HTMLRenderer.code(lines)
        }
        return HTMLRenderer.page(title: title, body: body)
    }
}

/// Draws an HTML page into a paginated A4 PDF with a web view that is never shown.
final class PDFExporter: NSObject, WKNavigationDelegate {
    private static var running: Set<PDFExporter> = []
    private var web: WKWebView?
    private var done: ((Data?) -> Void)?
    private let pageSize = CGSize(width: 595, height: 842)

    static func export(html: String, completion: @escaping (Data?) -> Void) {
        let exporter = PDFExporter()
        running.insert(exporter)
        exporter.done = { data in
            running.remove(exporter)
            completion(data)
        }
        // Printing is always light, whatever the app looks like.
        let light = html.replacingOccurrences(of: "</head>", with: "<style>:root{color-scheme:light} body{margin:36px 40px;font-size:12px}</style></head>")
        let web = WKWebView(frame: CGRect(origin: .zero, size: exporter.pageSize))
        web.navigationDelegate = exporter
        exporter.web = web
        web.loadHTMLString(light, baseURL: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.documentElement.scrollHeight") { [weak self] value, _ in
            guard let self else { return }
            let height = (value as? Double).map { CGFloat($0) } ?? self.pageSize.height
            self.render(pages: max(1, min(2000, Int((height / self.pageSize.height).rounded(.up)))), merged: PDFDocument(), index: 0)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { done?(nil) }

    private func render(pages: Int, merged: PDFDocument, index: Int) {
        guard let web else { done?(nil); return }
        guard index < pages else { done?(merged.dataRepresentation()); return }
        let config = WKPDFConfiguration()
        config.rect = CGRect(x: 0, y: CGFloat(index) * pageSize.height, width: pageSize.width, height: pageSize.height)
        web.createPDF(configuration: config) { [weak self] result in
            guard let self else { return }
            if case .success(let data) = result, let page = PDFDocument(data: data)?.page(at: 0) {
                merged.insert(page, at: merged.pageCount)
                self.render(pages: pages, merged: merged, index: index + 1)
            } else {
                self.done?(nil)
            }
        }
    }
}

extension AppState {
    private func exportPanel(for doc: Document, ext: String) -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = doc.url.deletingPathExtension().lastPathComponent + "." + ext
        panel.directoryURL = doc.url.deletingLastPathComponent()
        return panel.runModal() == .OK ? panel.url : nil
    }

    func exportHTML() {
        guard let doc = current, let url = exportPanel(for: doc, ext: "html") else { return }
        let page = DocumentExport.html(title: doc.name, url: doc.url, type: doc.type, text: text(for: doc))
        do {
            try Data(page.utf8).write(to: url, options: .atomic)
            notify(L("Экспортировано: %@", url.lastPathComponent), symbol: "square.and.arrow.up")
        } catch {
            errorMessage = L("Не удалось сохранить «%@».", url.lastPathComponent)
        }
    }

    func exportPDF() {
        guard let doc = current, let url = exportPanel(for: doc, ext: "pdf") else { return }
        let page = DocumentExport.html(title: doc.name, url: doc.url, type: doc.type, text: text(for: doc))
        PDFExporter.export(html: page) { [weak self] data in
            guard let data, (try? data.write(to: url, options: .atomic)) != nil else {
                self?.errorMessage = L("Не удалось сохранить «%@».", url.lastPathComponent)
                return
            }
            self?.notify(L("Экспортировано: %@", url.lastPathComponent), symbol: "square.and.arrow.up")
        }
    }
}
