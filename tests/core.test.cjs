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
const api = vm.runInContext(`${src}\n({ fileTypeOf, baseName, MarkdownParser, CSV, makeDocument, plain, Syntax, fenceType })`, ctx);

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
