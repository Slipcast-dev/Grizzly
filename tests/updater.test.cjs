// Update check logic (electron/updater.js): version order, release parsing, checksums, trusted hosts.
const test = require('node:test');
const assert = require('node:assert');
const u = require('../electron/updater.js');

test('newer versions are detected numerically', () => {
  assert.ok(u.isNewer('1.2.0', '1.1.0'));
  assert.ok(u.isNewer('v1.10.0', '1.9.9'));
  assert.ok(u.isNewer('2.0', '1.99.9'));
  assert.ok(!u.isNewer('1.1.0', '1.1.0'));
  assert.ok(!u.isNewer('1.1', '1.1.0'));
  assert.ok(!u.isNewer('1.0.9', '1.1.0'));
});

test('checksum is read from the line that names the file', () => {
  const notes = `## SHA-256\n\`${'A'.repeat(64)}\`  Grizzly-1.2.0-portable.exe\n${'b'.repeat(64)} Grizzly-1.2.0-arm64.dmg`;
  assert.strictEqual(u.checksumInNotes(notes, 'Grizzly-1.2.0-portable.exe'), 'a'.repeat(64));
  assert.strictEqual(u.checksumInNotes(notes, 'Grizzly-1.2.0-arm64.dmg'), 'b'.repeat(64));
  assert.strictEqual(u.checksumInNotes(notes, 'other.exe'), null);
});

test('release JSON: version and the Windows asset', () => {
  const base = 'https://github.com/Slipcast-dev/Grizzly/releases/download/v1.2.0/';
  const json = { tag_name: 'v1.2.0', body: 'notes', assets: [
    { name: 'Grizzly-1.2.0-arm64.dmg', browser_download_url: base + 'Grizzly-1.2.0-arm64.dmg' },
    { name: 'Grizzly-1.2.0-portable.exe', browser_download_url: base + 'Grizzly-1.2.0-portable.exe' },
  ] };
  const r = u.parseRelease(json);
  assert.strictEqual(r.version, '1.2.0');
  assert.strictEqual(r.assetName, 'Grizzly-1.2.0-portable.exe');
  assert.strictEqual(u.parseRelease({ tag_name: 'v1', assets: [] }), null);
  assert.throws(() => u.parseRelease({}));
});

test('downloads are limited to GitHub over HTTPS', () => {
  assert.ok(u.isTrustedDownload('https://github.com/a/b.exe'));
  assert.ok(u.isTrustedDownload('https://objects.githubusercontent.com/a.exe'));
  assert.ok(!u.isTrustedDownload('http://github.com/a.exe'));
  assert.ok(!u.isTrustedDownload('https://evil.example/a.exe'));
  assert.ok(!u.isTrustedDownload('https://github.com.evil.example/a.exe'));
  assert.ok(!u.isTrustedDownload('not a url'));
});
