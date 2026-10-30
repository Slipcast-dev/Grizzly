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

// History survives removing the file from the library
let histFile = dir.appendingPathComponent("h.md")
try "# hi".write(to: histFile, atomically: true, encoding: .utf8)
let lib = LibraryStore(storeURL: dir.appendingPathComponent("lib.json"))
let entry = lib.add(url: histFile)
lib.recordOpened(histFile)
check(lib.recents.count == 1, "opened file is in history")
lib.remove(entry.id)
check(lib.recents.count == 1 && lib.file(atPath: histFile.standardizedFileURL.path) == nil, "history keeps a file removed from the library")
lib.recordOpened(histFile)
check(lib.recents.count == 1, "history has no duplicates")
check(LibraryStore(storeURL: dir.appendingPathComponent("lib.json")).recents.count == 1, "history is saved to disk")
lib.clearRecents()
check(lib.recents.isEmpty, "clear empties history")

// Syntax highlighting of programming languages
func roles(_ line: String, _ type: FileType, state: Int = 0) -> [(String, SyntaxRole)] {
    let ns = line as NSString
    return SyntaxEngine.spans(line, type: type, state: state).spans.map { (ns.substring(with: $0.range), $0.role) }
}
func has(_ list: [(String, SyntaxRole)], _ text: String, _ role: SyntaxRole) -> Bool { list.contains { $0.0.trimmingCharacters(in: .whitespaces) == text && $0.1 == role } }

check(FileType(url: URL(fileURLWithPath: "/a/x.py")) == .python && FileType(url: URL(fileURLWithPath: "/a/x.hpp")) == .cpp
      && FileType(url: URL(fileURLWithPath: "/a/x.tsx")) == .typescript && FileType(url: URL(fileURLWithPath: "/a/x.cs")) == .csharp, "code extensions map to types")
let py = roles("def run(x): # go", .python)
check(has(py, "def", .keyword) && has(py, "# go", .comment), "python keyword and comment")
check(SyntaxEngine.states(["x = \"\"\"doc", "more", "end\"\"\"", "y = 1"], type: .python) == [0, 1, 1, 0], "python triple-quoted string spans lines")
check(SyntaxEngine.states(["a /* b", "c */ d", "e"], type: .cpp) == [0, 1, 0], "C block comment spans lines")
check(has(roles("c */ d", .cpp, state: 1), "c */", .comment), "closing line of a block comment is colored")
check(has(roles("#include <vector>", .cpp), "#include", .keyword) && has(roles("int x = 0x1F;", .cpp), "0x1F", .number), "C++ preprocessor and hex number")
check(has(roles("let s = \"a // b\" // c", .swift), "\"a // b\"", .string) && has(roles("let s = \"a // b\" // c", .swift), "// c", .comment), "comment marker inside a string is not a comment")
check(has(roles("public class Foo : Bar", .csharp), "class", .keyword) && has(roles("public class Foo : Bar", .csharp), "Foo", .key), "C# keyword and type")
check(SyntaxEngine.states(["const a = `x", "y`;", "z"], type: .javascript) == [0, 1, 0], "JS template literal spans lines")
check(has(roles("const n = null;", .typescript), "null", .number) && has(roles("interface A {}", .typescript), "interface", .keyword), "TypeScript literals and keywords")
check(has(roles("  color: #fff;", .css), "color", .key) && has(roles("  color: #fff;", .css), "#fff", .number), "CSS property and color")
check(!has(roles("a:hover {", .css), "a", .key), "CSS selector with pseudo-class is not a property")
check(has(roles("$x = 1; // c", .php), "$x", .key) && has(roles("$x = 1; // c", .php), "// c", .comment), "PHP variable and comment")
check(SyntaxEngine.states(["a", "b"], type: .json).isEmpty, "stateless formats carry no state")
check(FileType.fromFenceTag("Python title=x") == .python && FileType.fromFenceTag("c++") == .cpp && FileType.fromFenceTag("nope") == nil, "fenced code language tags")
check(FileType.template(forExtension: "json") == "{\n  \n}\n" && FileType.template(forExtension: "xyz") == "", "new file templates")

// Tags
let tagFile = lib.add(url: histFile)
check(lib.createTag("#Работа") == "Работа" && lib.createTag("работа") == "Работа" && lib.createTag("  ") == nil, "tags are cleaned and not duplicated")
lib.toggleTag(tagFile.id, "Работа")
check(lib.files(withTag: "работа").count == 1 && lib.hasTag(tagFile.id, "РАБОТА"), "files are found by tag, case-insensitively")
check(LibraryStore(storeURL: dir.appendingPathComponent("lib.json")).files(withTag: "Работа").count == 1, "tags are saved to disk")
lib.renameTag("Работа", to: "Дом")
check(lib.files(withTag: "Дом").count == 1 && lib.files(withTag: "Работа").isEmpty, "renaming a tag moves its files")
lib.deleteTag("Дом")
check(lib.allTags.isEmpty && lib.files(withTag: "Дом").isEmpty, "deleting a tag removes it from files")

check(LibraryStore.extractTags(from: "# Title\n#12 and #работа, #Work-1 and #work. See a#b, http://x.y/#frag, &#39; #")
      == ["12", "работа", "Work-1", "work"], "hashtags are read from text, headings and fragments are not tags")
let textTagFile = lib.add(url: histFile)
lib.setInlineTags(textTagFile.id, ["идея"])
check(lib.files(withTag: "Идея").count == 1 && lib.allTags.contains("идея") && lib.hasTag(textTagFile.id, "идея"), "tags written in the text are tags of the file")

check(LibraryStore.replaceTag("work", with: "дом", in: "#Work and #workshop, a#work, #work.\n#WORK") == "#дом and #workshop, a#work, #дом.\n#дом", "renaming a tag changes only whole #tags")
check(LibraryStore.replaceTag("work", with: nil, in: "x #work y, #work") == "x y, ", "deleting a tag removes it with the following space")
check(LibraryStore.countTag("work", in: "#work #Work #works") == 2, "tag occurrences are counted")
let tm = LibraryStore.tagMatches(in: "a #one-, #два")
check(tm.map(\.tag) == ["one", "два"] && (("a #one-, #два" as NSString).substring(with: tm[0].range) == "#one"), "tag ranges exclude trailing dashes")
let f2 = lib.add(url: dir.appendingPathComponent("second.md"))
lib.setInlineTags(f2.id, ["идея", "план"]); lib.setInlineTags(textTagFile.id, ["идея"])
check(lib.files(withAllTags: ["идея"]).count == 2 && lib.files(withAllTags: ["идея", "план"]).map(\.id) == [f2.id] && lib.files(withAllTags: []).isEmpty, "several tags narrow the list down")

// Updates
check(UpdateCheck.isNewer("1.2.0", than: "1.1.0") && UpdateCheck.isNewer("v1.10.0", than: "1.9.9") && UpdateCheck.isNewer("2.0", than: "1.99.9"), "newer versions are detected")
check(!UpdateCheck.isNewer("1.1.0", than: "1.1.0") && !UpdateCheck.isNewer("1.1", than: "1.1.0") && !UpdateCheck.isNewer("1.0.9", than: "1.1.0"), "same or older versions are not updates")
let notes = "## SHA-256\n`\(String(repeating: "A", count: 64))`  Grizzly-1.2.0-arm64.dmg\n\(String(repeating: "b", count: 64)) Grizzly-1.2.0-x64.dmg"
check(UpdateCheck.checksum(in: notes, for: "Grizzly-1.2.0-arm64.dmg") == String(repeating: "a", count: 64)
      && UpdateCheck.checksum(in: notes, for: "Grizzly-1.2.0-x64.dmg") == String(repeating: "b", count: 64)
      && UpdateCheck.checksum(in: notes, for: "other.dmg") == nil, "checksum is read from the release notes")
let base = "https://github.com/Slipcast-dev/Grizzly/releases/download/v1.2.0/"
let release = "{\"tag_name\":\"v1.2.0\",\"body\":\"notes\",\"assets\":[{\"name\":\"Grizzly-1.2.0-x64.dmg\",\"browser_download_url\":\"\(base)Grizzly-1.2.0-x64.dmg\"},{\"name\":\"Grizzly-1.2.0-arm64.dmg\",\"browser_download_url\":\"\(base)Grizzly-1.2.0-arm64.dmg\"}]}"
let parsed = try UpdateCheck.parse(Data(release.utf8), assetSuffix: "-arm64.dmg")
check(parsed?.version == "1.2.0" && parsed?.assetName == "Grizzly-1.2.0-arm64.dmg", "release JSON: version and the asset for this architecture")
check(try UpdateCheck.parse(Data(release.utf8), assetSuffix: "-win.exe") == nil, "release without a matching asset is ignored")
check(!UpdateCheck.isTrustedDownload(URL(string: "https://evil.example/a.dmg")!) && !UpdateCheck.isTrustedDownload(URL(string: "http://github.com/a.dmg")!)
      && UpdateCheck.isTrustedDownload(URL(string: "https://objects.githubusercontent.com/a.dmg")!), "downloads are limited to GitHub over HTTPS")

try? FileManager.default.removeItem(at: dir)
exit(failures == 0 ? 0 : 1)
