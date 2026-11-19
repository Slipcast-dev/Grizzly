// Tests the file helpers of the Electron port: encodings, safe saving and crash recovery.
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const io = require('../electron/fileio');

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'grizzly-io-'));
test.after(() => fs.rmSync(tmp, { recursive: true, force: true }));

test('8-bit Cyrillic encodings are told apart and round-trip', () => {
  const text = 'Привет, мир! Это обычный русский текст для проверки кодировки.';
  for (const name of ['Windows-1251', 'KOI8-R', 'CP866']) {
    const found = io.detectCyrillic(io.encode8(text, name));
    assert.ok(found, name);
    assert.strictEqual(found.encoding, name);
    assert.strictEqual(found.text, text);
  }
  assert.strictEqual(io.detectCyrillic(Buffer.from('plain ascii', 'latin1')), null);
  assert.throws(() => io.encode8('日本', 'KOI8-R'), /unmappable/);
  assert.throws(() => io.encodeLatin1('Привет'), /unmappable/);
  assert.strictEqual(io.encodeLatin1('café').toString('latin1'), 'café');
});

test('saving replaces the file safely and keeps permissions and symlinks', { skip: process.platform === 'win32' }, () => {
  const real = path.join(tmp, 'real.txt');
  const link = path.join(tmp, 'link.txt');
  fs.writeFileSync(real, 'one');
  fs.chmodSync(real, 0o640);
  fs.symlinkSync(real, link);
  io.replaceFile(link, Buffer.from('two'));
  assert.ok(fs.lstatSync(link).isSymbolicLink(), 'the link is still a link');
  assert.strictEqual(fs.readFileSync(real, 'utf8'), 'two');
  assert.strictEqual(fs.statSync(real).mode & 0o777, 0o640);
  assert.deepStrictEqual(fs.readdirSync(tmp).filter((n) => n.endsWith('.tmp')), [], 'no temporary file is left behind');
});

test('saving a new file just writes it', () => {
  const file = path.join(tmp, 'new.txt');
  io.replaceFile(file, Buffer.from('hello'));
  assert.strictEqual(fs.readFileSync(file, 'utf8'), 'hello');
});

test('recovery store keeps, lists and removes drafts', () => {
  const store = new io.RecoveryStore(path.join(tmp, 'recovery'));
  assert.deepStrictEqual(store.list(), []);
  store.save('/a/b.md', 'draft');
  store.save('/a/c.md', 'other');
  assert.deepStrictEqual(store.list().map((e) => e.text).sort(), ['draft', 'other']);
  store.remove('/a/b.md');
  assert.deepStrictEqual(store.list().map((e) => e.path), ['/a/c.md']);
  fs.writeFileSync(path.join(tmp, 'recovery', 'broken.json'), '{nope');
  assert.strictEqual(store.list().length, 1, 'a damaged entry is skipped');
});
