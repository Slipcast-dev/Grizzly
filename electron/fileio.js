// File helpers shared by the main process and the tests (no Electron imports here).
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

/** 8-bit Cyrillic encodings: [name shown in the app, WHATWG label]. */
const EIGHT_BIT = [['Windows-1251', 'windows-1251'], ['KOI8-R', 'koi8-r'], ['CP866', 'ibm866']];

/** Windows-1251, KOI8-R and CP866 decode almost any bytes, so the right one is the reading that looks most like
 *  Russian: many lowercase letters, few capitals and no box-drawing characters.
 *  Returns null when no reading has Cyrillic letters (the caller then falls back to ISO-8859-1). */
function detectCyrillic(buf) {
  let best = null;
  for (const [name, label] of EIGHT_BIT) {
    const text = new TextDecoder(label).decode(buf);
    let score = 0;
    for (let i = 0; i < text.length; i++) {
      const c = text.charCodeAt(i);
      if ((c >= 0x430 && c <= 0x44f) || c === 0x451) score += 2;
      else if ((c >= 0x410 && c <= 0x42f) || c === 0x401) score -= 1;
      else if (c >= 0x2500 && c <= 0x259f) score -= 6;
    }
    if (!best || score > best.score) best = { text, encoding: name, score };
  }
  return best && best.score > 0 ? { text: best.text, encoding: best.encoding } : null;
}

const tables = new Map();
/** Encodes text in an 8-bit encoding; throws EENCODE for a character the encoding cannot hold. */
function encode8(text, name) {
  const entry = EIGHT_BIT.find(([n]) => n === name);
  if (!entry) throw Object.assign(new Error('unsupported encoding'), { code: 'EENCODE' });
  let table = tables.get(name);
  if (!table) {
    table = new Map();
    const dec = new TextDecoder(entry[1]);
    for (let b = 0x80; b < 256; b++) table.set(dec.decode(Uint8Array.of(b)), b);
    tables.set(name, table);
  }
  const out = [];
  for (const ch of text) {
    const code = ch.codePointAt(0);
    const byte = code < 0x80 ? code : table.get(ch);
    if (byte === undefined) throw Object.assign(new Error('unmappable character'), { code: 'EENCODE' });
    out.push(byte);
  }
  return Buffer.from(out);
}

/** ISO-8859-1: every byte is the character with the same number. */
function encodeLatin1(text) {
  for (let i = 0; i < text.length; i++) {
    if (text.charCodeAt(i) > 255) throw Object.assign(new Error('unmappable character'), { code: 'EENCODE' });
  }
  return Buffer.from(text, 'latin1');
}

/** Writes the data so that a crash never leaves half a file, and the file stays the same file: a symbolic link keeps
 *  pointing where it did and the permissions stay. Falls back to writing in place when the folder does not allow
 *  new files or the file is held open by another program. */
function replaceFile(file, data) {
  let target = file;
  try { target = fs.realpathSync(file); } catch { /* a new file */ }
  if (!fs.existsSync(target)) { fs.writeFileSync(target, data); return; }
  const mode = fs.statSync(target).mode & 0o7777;
  const temp = path.join(path.dirname(target), `.grizzly-${crypto.randomUUID()}.tmp`);
  try {
    fs.writeFileSync(temp, data, { mode });
    fs.chmodSync(temp, mode);
    fs.renameSync(temp, target);
  } catch {
    try { fs.rmSync(temp, { force: true }); } catch { /* ignore */ }
    fs.writeFileSync(target, data);
  }
}

/** Crash recovery: unsaved text is copied to disk a moment after it is typed, one small JSON file per document,
 *  and removed as soon as the text is saved or discarded. */
class RecoveryStore {
  constructor(dir) { this.dir = dir; }

  fileFor(p) { return path.join(this.dir, crypto.createHash('sha256').update(p).digest('hex') + '.json'); }

  save(p, text) {
    fs.mkdirSync(this.dir, { recursive: true });
    const target = this.fileFor(p);
    const tmp = target + '.tmp';
    fs.writeFileSync(tmp, JSON.stringify({ path: p, text, date: Date.now() }));
    fs.renameSync(tmp, target);
  }

  remove(p) { try { fs.rmSync(this.fileFor(p), { force: true }); } catch { /* ignore */ } }

  list() {
    let names = [];
    try { names = fs.readdirSync(this.dir).filter((n) => n.endsWith('.json')); } catch { return []; }
    const out = [];
    for (const n of names) {
      try {
        const e = JSON.parse(fs.readFileSync(path.join(this.dir, n), 'utf8'));
        if (typeof e.path === 'string' && typeof e.text === 'string') out.push(e);
      } catch { /* a damaged entry is skipped */ }
    }
    return out.sort((a, b) => a.date - b.date);
  }
}

module.exports = { EIGHT_BIT, detectCyrillic, encode8, encodeLatin1, replaceFile, RecoveryStore };
