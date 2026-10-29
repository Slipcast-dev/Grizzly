// Plain executable test (XCTest needs full Xcode). Run: ./scripts/test.sh
import Foundation

var failures = 0
func check(_ ok: Bool, _ what: String) {
    if !ok { failures += 1; print("FAIL: \(what)") } else { print("ok: \(what)") }
}

// Quick Look HTML: links and quotes
let evil = HTMLRenderer.markdown(["[x](a\"onmouseover=\"alert(1))", "[js](javascript:alert(1))", "[ok](https://example.com)"])
check(!evil.contains("\"onmouseover"), "quote in link target cannot open an attribute")
check(!evil.contains("javascript:alert(1)\">"), "javascript: link is not an anchor")
check(evil.contains("<a href=\"https://example.com\">ok</a>"), "https link stays clickable")
check(HTMLRenderer.escape("<a href=\"x\">&'") == "&lt;a href=&quot;x&quot;&gt;&amp;&#39;", "escape covers < > & quotes")

// Encodings
let dir = FileManager.default.temporaryDirectory.appendingPathComponent("grizzly-test-\(getpid())")
try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
for (enc, text) in [("UTF-8", "Привет"), ("UTF-16", "Привет"), ("Windows-1251", "Привет")] {
    let url = dir.appendingPathComponent("t.txt")
    try FileLoader.write(text, to: url, encoding: enc)
    let back = try FileLoader.read(url)
    check(back.text == text && back.encoding == enc, "\(enc) round trip")
}
do { try FileLoader.write("日本", to: dir.appendingPathComponent("x.txt"), encoding: "Windows-1251"); check(false, "unmappable text throws") }
catch { check(true, "unmappable text throws") }

// File types and CSV
check(FileType(url: URL(fileURLWithPath: "/a/B.MD")) == .markdown, "md type")
check(FileType(url: URL(fileURLWithPath: "/a/b.xyz")) == .text, "unknown ext is text")
let table = CSVTable(lines: ["a;b", "1;\"x;y\""], delimiter: CSVTable.detectDelimiter(url: URL(fileURLWithPath: "/a.csv"), lines: ["a;b", "1;\"x;y\""]))
check(table.rows.count == 2 && table.rows[1].cells.contains("x;y"), "csv quoted cell with delimiter")
check(!MarkdownParser.parse(["# T", "", "- a", "- b"]).isEmpty, "markdown parses")

try? FileManager.default.removeItem(at: dir)
exit(failures == 0 ? 0 : 1)
