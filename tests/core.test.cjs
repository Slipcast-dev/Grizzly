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
const api = vm.runInContext(`${src}\n({ fileTypeOf, baseName, MarkdownParser, CSV, makeDocument, plain })`, ctx);

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
