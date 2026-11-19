// Unit tests for the Electron port's parsers (electron/renderer/core.js). Run: node --test tests/
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const src = fs.readFileSync(path.join(__dirname, '..', 'electron', 'renderer', 'core.js'), 'utf8');
const ctx = { crypto: { randomUUID: () => 'id' }, console };
vm.createContext(ctx);
// Top-level const/function declarations are exposed through a trailing expression.
const api = vm.runInContext(`${src}\n({ fileTypeOf, baseName, MarkdownParser, CSV, makeDocument, plain, Syntax, fenceType, Searcher, LineEndings, TextSearch, Outline, LineDiff })`, ctx);

test('file types by extension', () => {
  assert.strictEqual(api.fileTypeOf('a/b/Notes.MD'), 'markdown');
  assert.strictEqual(api.fileTypeOf('x.yml'), 'yaml');
  assert.strictEqual(api.fileTypeOf('x.tsv'), 'csv');
  assert.strictEqual(api.fileTypeOf('x.unknown'), 'text');
  assert.strictEqual(api.baseName('C:\\dir\\file.txt'), 'file.txt');
});

test('markdown blocks', () => {
  const blocks = api.MarkdownParser.parse(['# Title', '', '- a', '- b', '', '```js', 'x < 1', '```', '', '---']);
  const kinds = blocks.map((b) => b.type || b.kind);
  assert.ok(blocks.length >= 4, JSON.stringify(kinds));
  assert.ok(JSON.stringify(blocks).includes('Title'));
  assert.ok(JSON.stringify(blocks).includes('x < 1'));
});

test('csv delimiter detection and quoted cells', () => {
  const lines = ['id;name;note', '1;Anna;"a;b"', '2;Boris;ok'];
  const delim = api.CSV.detectDelimiter('x.csv', lines);
  assert.strictEqual(delim, ';');
  const table = api.CSV.parse(lines, delim);
  assert.ok(JSON.stringify(table).includes('a;b'));
});

test('document keeps CRLF text but splits lines', () => {
  const doc = api.makeDocument('/tmp/a.md', { text: 'a\r\nb', encoding: 'UTF-8', mtimeMs: 1 });
  assert.deepStrictEqual(Array.from(doc.lines), ['a', 'b']);
  assert.ok(doc.text.includes('\r\n'));
});

// Syntax highlighting of programming languages (mirrors tests/swift/main.swift)
const roles = (line, type, state = 0) => api.Syntax.spans(line, type, state).map((s) => [line.slice(s.start, s.end).trim(), s.role]);
const has = (list, text, role) => list.some(([t, r]) => t === text && r === role);
const states = (lines, type) => Array.from(api.Syntax.states(lines, type));

test('code extensions map to types', () => {
  assert.strictEqual(api.fileTypeOf('x.py'), 'python');
  assert.strictEqual(api.fileTypeOf('x.hpp'), 'cpp');
  assert.strictEqual(api.fileTypeOf('x.tsx'), 'typescript');
  assert.strictEqual(api.fileTypeOf('x.cs'), 'csharp');
});

test('python keyword, comment and multi-line string', () => {
  const py = roles('def run(x): # go', 'python');
  assert.ok(has(py, 'def', 'keyword') && has(py, '# go', 'comment'));
  assert.deepStrictEqual(states(['x = """doc', 'more', 'end"""', 'y = 1'], 'python'), [0, 1, 1, 0]);
});

test('C-style block comments span lines', () => {
  assert.deepStrictEqual(states(['a /* b', 'c */ d', 'e'], 'cpp'), [0, 1, 0]);
  assert.ok(has(roles('c */ d', 'cpp', 1), 'c */', 'comment'));
  assert.ok(has(roles('#include <vector>', 'cpp'), '#include', 'keyword'));
  assert.ok(has(roles('int x = 0x1F;', 'cpp'), '0x1F', 'number'));
});

test('comment marker inside a string is not a comment', () => {
  const r = roles('let s = "a // b" // c', 'swift');
  assert.ok(has(r, '"a // b"', 'string') && has(r, '// c', 'comment'));
});

test('C#, JS/TS, CSS and PHP basics', () => {
  const cs = roles('public class Foo : Bar', 'csharp');
  assert.ok(has(cs, 'class', 'keyword') && has(cs, 'Foo', 'key'));
  assert.deepStrictEqual(states(['const a = `x', 'y`;', 'z'], 'javascript'), [0, 1, 0]);
  assert.ok(has(roles('const n = null;', 'typescript'), 'null', 'number') && has(roles('interface A {}', 'typescript'), 'interface', 'keyword'));
  assert.ok(has(roles('  color: #fff;', 'css'), 'color', 'key') && has(roles('  color: #fff;', 'css'), '#fff', 'number'));
  assert.ok(!has(roles('a:hover {', 'css'), 'a', 'key'));
  assert.ok(has(roles('$x = 1; // c', 'php'), '$x', 'key') && has(roles('$x = 1; // c', 'php'), '// c', 'comment'));
});

test('stateless formats carry no state; fence tags resolve', () => {
  assert.strictEqual(states(['a', 'b'], 'json').length, 0);
  assert.strictEqual(api.fenceType('Python title=x'), 'python');
  assert.strictEqual(api.fenceType('c++'), 'cpp');
  assert.strictEqual(api.fenceType('nope'), null);
  const doc = api.makeDocument('/tmp/a.cpp', { text: '/* a\nb */', encoding: 'UTF-8', mtimeMs: 1 });
  assert.deepStrictEqual(Array.from(doc.syntaxStates), [0, 1]);
});

test('highlighting can be switched off, altogether or per language', () => {
  assert.ok(api.Syntax.spans('def x(): pass', 'python').length > 0);
  ctx.Prefs = { values: { syntaxOn: true, syntaxOff: ['python'] } };
  assert.strictEqual(api.Syntax.spans('def x(): pass', 'python').length, 0);
  assert.ok(api.Syntax.spans('const a = 1;', 'javascript').length > 0);
  ctx.Prefs = { values: { syntaxOn: false, syntaxOff: [] } };
  assert.strictEqual(api.Syntax.spans('const a = 1;', 'javascript').length, 0);
  delete ctx.Prefs;
});

test('file search matches the beginning of the name or of any word', () => {
  const m = api.Searcher.nameMatches;
  assert.ok(m('Read Me.md', 'read') && m('Read Me.md', 'me') && m('Read Me.md', 'read m') && m('Гризли заметки.md', 'гриз'));
  assert.ok(m('Гризли заметки.md', 'ЗАМ') && m('notes', ''));
  assert.ok(!m('Read Me.md', 'ead') && !m('Read Me.md', 'xyz'));
});

test('find in edited text counts hits per line', () => {
  const hits = api.Searcher.matchesInText('ab', 'ab AB\nx\ncab');
  assert.deepStrictEqual(JSON.parse(JSON.stringify(hits)), [{ unit: 0, occurrence: 0 }, { unit: 0, occurrence: 1 }, { unit: 2, occurrence: 0 }]);
});

test('tags: create, assign, rename, delete', () => {
  const stateSrc = fs.readFileSync(path.join(__dirname, '..', 'electron', 'renderer', 'state.js'), 'utf8');
  const c = { crypto: { randomUUID: (() => { let n = 0; return () => 'id' + ++n; })() }, window: { api: { saveLibrary() {}, mtimes: async () => ({}), loadLibrary: async () => null } },
    console, setTimeout, clearTimeout, baseName: (p) => p.split('/').pop(), Intl };
  vm.createContext(c);
  const lib = vm.runInContext(`${stateSrc}\nLibrary`, c);
  const file = lib.add('/a/x.md');
  assert.strictEqual(lib.createTag('#Работа'), 'Работа');
  assert.strictEqual(lib.createTag('работа'), 'Работа');
  assert.strictEqual(lib.createTag('  '), null);
  lib.toggleTag(file.id, 'Работа');
  assert.strictEqual(lib.filesWithTag('РАБОТА').length, 1);
  lib.renameTag('Работа', 'Дом');
  assert.strictEqual(lib.filesWithTag('Дом').length, 1);
  assert.strictEqual(lib.filesWithTag('Работа').length, 0);
  assert.deepStrictEqual(Array.from(lib.extractTags('# T\n#12 и #работа, #Work-1 a#b http://x/#frag')), ['12', 'работа', 'Work-1']);
  assert.deepStrictEqual(Array.from(lib.extractTags('#🍕 и #идея💡 и #a_b, 😀#x')), ['🍕', 'идея💡', 'a_b', 'x']);
  assert.strictEqual(lib.replaceTag('🍕', 'пицца', 'ем #🍕 и #🍕х'), 'ем #пицца и #🍕х');
  lib.setInlineTags(file.id, ['идея']);
  assert.strictEqual(lib.filesWithTag('Идея').length, 1);
  assert.strictEqual(lib.replaceTag('work', 'дом', '#Work and #workshop, a#work, #work.\n#WORK'), '#дом and #workshop, a#work, #дом.\n#дом');
  assert.strictEqual(lib.replaceTag('work', null, 'x #work y, #work'), 'x y, ');
  assert.strictEqual(lib.countTag('work', '#work #Work #works'), 2);
  assert.deepStrictEqual(JSON.parse(JSON.stringify(lib.tagMatches('a #one-, #два'))), [{ index: 2, length: 4, tag: 'one' }, { index: 9, length: 4, tag: 'два' }]);
  const f2 = lib.add('/a/y.md'); lib.setInlineTags(f2.id, ['идея', 'план']); lib.setInlineTags(file.id, ['идея']);
  assert.strictEqual(lib.filesWithAllTags(['идея']).length, 2);
  assert.strictEqual(lib.filesWithAllTags(['идея', 'план']).length, 1);
  assert.strictEqual(lib.filesWithAllTags([]).length, 0);
  lib.setInlineTags(f2.id, []);
  lib.setInlineTags(file.id, []);
  lib.deleteTag('Дом');
  assert.strictEqual(lib.allTags.length, 0);
  assert.strictEqual(lib.filesWithTag('Дом').length, 0);
});

// Arrays made inside the vm context have another prototype: compare by value.
const same = (a, b) => assert.strictEqual(JSON.stringify(a), JSON.stringify(b));

test('line endings: mixed endings survive an open and save', () => {
  for (const raw of ['a\r\nb\nc\rd', 'a\r\nb\r\n', 'a\nb\n', 'a\rb\r', '\r\n\r\n', 'no break', 'a\n\rb']) {
    const p = api.LineEndings.parse(raw);
    assert.ok(!p.normalized.includes('\r'), JSON.stringify(raw));
    assert.strictEqual(api.LineEndings.apply(p.normalized, p.endings), raw, JSON.stringify(raw));
  }
  const p = api.LineEndings.parse('a\r\nb\r\nc\n');
  assert.strictEqual(api.LineEndings.apply('a\nb\nc\nNEW\n', p.endings), 'a\r\nb\r\nc\nNEW\r\n');
});

test('document records its line endings', () => {
  const doc = api.makeDocument('/tmp/a.txt', { text: 'a\r\nb\r\n', encoding: 'UTF-8', mtimeMs: 1 });
  same(Array.from(doc.lines), ['a', 'b', '']);
  assert.strictEqual(api.LineEndings.apply(doc.lines.join('\n'), doc.endings), 'a\r\nb\r\n');
});

test('search options, regular expressions and multi-line hits', () => {
  const T = api.TextSearch;
  const hello = 'Hello hello HELLO world';
  const o = (x) => Object.assign({ caseSensitive: false, wholeWord: false, regex: false }, x);
  assert.strictEqual(T.matches('hello', hello, o()).length, 3);
  assert.strictEqual(T.matches('hello', hello, o({ caseSensitive: true })).length, 1);
  assert.strictEqual(T.matches('wor', hello, o({ wholeWord: true })).length, 0);
  assert.strictEqual(T.matches('world', hello, o({ wholeWord: true })).length, 1);
  assert.strictEqual(T.matches('h.llo', hello, o({ regex: true })).length, 3);
  assert.ok(!T.isValid('(', o({ regex: true })) && T.isValid('(', o()));
  assert.strictEqual(T.matches('x*', 'abc', o({ regex: true })).length, 0);
  const multi = 'one\ntwo\nthree\ntwo';
  same(T.locate('two', multi, o()).map((h) => h.unit), [1, 3]);
  assert.strictEqual(T.locate('one\\ntwo', multi, o({ regex: true })).length, 1);
  assert.strictEqual(T.locate('^t', multi, o({ regex: true })).length, 3);
  assert.strictEqual(T.apply(T.edits('one\\ntwo', 'X', multi, o({ regex: true })), multi), 'X\nthree\ntwo');
  assert.strictEqual(T.apply(T.edits('(\\w+) (\\w+)', '$2 $1', 'ab cd', o({ regex: true })), 'ab cd'), 'cd ab');
  assert.strictEqual(T.apply(T.edits('hello', 'X', hello, o(), 1), hello), 'Hello X HELLO world');
});

test('outline of different file types', () => {
  const t = (text, type) => api.Outline.items(text, type).map((i) => i.title);
  same(t('# A\n```\n# no\n```\n## B', 'markdown'), ['A', 'B']);
  same(t('class A:\n    def f(self):\n        pass\ndef g(): pass', 'python'), ['class A', 'def f', 'def g']);
  same(t('struct S {\n  func go() {}\n}', 'swift'), ['struct S', 'func go']);
  same(t('function a() {}\nconst b = (x) => 1', 'javascript'), ['function a', 'b()']);
  same(t('[main]\nk=v\n[other]', 'config'), ['main', 'other']);
  same(t('\\section{Intro}\n\\subsection{More}', 'tex'), ['Intro', 'More']);
  same(t('func main() {}\ntype T struct{}', 'go'), ['func main', 'type T']);
  same(t('a: 1\nb:\n  c: 2', 'yaml'), ['a', 'b']);
  same(t('int main(int argc) {\n  if (x) {}\n}', 'cpp'), ['main()']);
});

test('diff and three-way merge', () => {
  const D = api.LineDiff;
  const base = ['a', 'b', 'c', 'd'];
  same(D.merge(base, ['a', 'B', 'c', 'd'], ['a', 'b', 'c', 'D']).lines, ['a', 'B', 'c', 'D']);
  const clash = D.merge(base, ['a', 'mine', 'c', 'd'], ['a', 'disk', 'c', 'd']);
  assert.strictEqual(clash.conflicts, 1);
  assert.ok(clash.lines.includes('<<<<<<< mine') && clash.lines.includes('>>>>>>> disk'));
  assert.strictEqual(D.merge(base, ['a', 'x', 'c', 'd'], ['a', 'x', 'c', 'd']).conflicts, 0);
  same(D.merge(base, base, ['z']).lines, ['z']);
  same(D.diff(['a', 'b'], ['a', 'c', 'b']).map((r) => r.op), ['equal', 'insert', 'equal']);
  same(D.diff([], []), []);
});

test('new languages: extensions and coloring', () => {
  assert.strictEqual(api.fileTypeOf('main.go'), 'go');
  assert.strictEqual(api.fileTypeOf('a.rs'), 'rust');
  assert.strictEqual(api.fileTypeOf('a.sh'), 'shell');
  assert.strictEqual(api.fileTypeOf('a.kts'), 'kotlin');
  const has = (line, type, word, role) => api.Syntax.spans(line, type).some((s) => line.slice(s.start, s.end) === word && s.role === role);
  assert.ok(has('func main() {}', 'go', 'func', 'keyword'));
  assert.ok(has('let x = 1; // c', 'rust', '// c', 'comment') && has('println!("a");', 'rust', 'println!', 'key'));
  assert.ok(has('select * from t', 'sql', 'select', 'keyword') && has('SELECT 1 -- c', 'sql', '-- c', 'comment'));
  assert.ok(has('echo $HOME # c', 'shell', '$HOME', 'key') && has('echo $HOME # c', 'shell', '# c', 'comment'));
  assert.ok(has('def f; end', 'ruby', 'def', 'keyword') && has('@a = :b', 'ruby', '@a', 'key'));
  assert.ok(has('public class A {}', 'java', 'class', 'keyword') && has('fun f() = null', 'kotlin', 'fun', 'keyword'));
});

test('fuzzing: parsers survive random and hostile input', () => {
  const alphabet = [...'#*_`[]()<>!|-+=~\\/"\' \n\t\r0123456789abcXYZ{};:.,$@%&?áю😀'];
  const rnd = (n) => Math.floor(Math.random() * n);
  const started = Date.now();
  const types = ['markdown', 'text', 'json', 'yaml', 'csv', 'log', 'xml', 'html', 'config', 'tex', 'python', 'swift', 'cpp', 'csharp', 'javascript', 'typescript', 'css', 'php', 'go', 'rust', 'java', 'kotlin', 'sql', 'shell', 'ruby'];
  for (let k = 0; k < 400; k++) {
    const text = Array.from({ length: rnd(600) }, () => alphabet[rnd(alphabet.length)]).join('');
    const lines = text.split('\n');
    api.MarkdownParser.parse(lines);
    api.CSV.parse(lines, ',');
    api.Outline.items(text, types[rnd(types.length)]);
    for (const type of types) { api.Syntax.states(lines, type); for (const l of lines.slice(0, 3)) api.Syntax.spans(l, type); }
    const p = api.LineEndings.parse(text);
    assert.strictEqual(api.LineEndings.apply(p.normalized, p.endings), text);
  }
  const evil = ['*'.repeat(5000), '['.repeat(3000), '`a'.repeat(3000), 'a'.repeat(100000), '<!--'.repeat(2000), '| ' + 'x | '.repeat(2000)];
  for (const line of evil) {
    api.MarkdownParser.parse([line]);
    for (const type of types) api.Syntax.spans(line, type);
  }
  assert.ok(Date.now() - started < 60000, 'bounded time');
});
