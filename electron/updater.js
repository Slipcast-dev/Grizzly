// Update check against GitHub releases, shared by the main process and the tests (no Electron imports here).
const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');

const REPOSITORY = 'Slipcast-dev/Grizzly';
const LATEST_URL = `https://api.github.com/repos/${REPOSITORY}/releases/latest`;
const ASSET_SUFFIX = '-portable.exe';

const normalize = (tag) => String(tag || '').trim().replace(/^v/i, '');

function parts(version) {
  return normalize(version).split('.').map((p) => parseInt(p, 10) || 0);
}

/** Numeric comparison of dotted versions: 1.10.0 is newer than 1.9.0, 1.2 equals 1.2.0. */
function isNewer(candidate, current) {
  const a = parts(candidate);
  const b = parts(current);
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    const x = a[i] || 0;
    const y = b[i] || 0;
    if (x !== y) return x > y;
  }
  return false;
}

/** Downloads only come from GitHub itself, over HTTPS. */
function isTrustedDownload(url) {
  try {
    const u = new URL(url);
    return u.protocol === 'https:' && (u.hostname === 'github.com' || u.hostname.endsWith('.githubusercontent.com'));
  } catch { return false; }
}

/** Finds a 64-digit hex string on the line of the release notes that names the asset. */
function checksumInNotes(notes, assetName) {
  for (const line of String(notes || '').split(/\r?\n/)) {
    if (!line.includes(assetName)) continue;
    const m = /(?<![0-9a-fA-F])[0-9a-fA-F]{64}(?![0-9a-fA-F])/.exec(line);
    if (m) return m[0].toLowerCase();
  }
  return null;
}

/** Reads the `releases/latest` answer. Returns null when the release has no file for this app. */
function parseRelease(json, suffix = ASSET_SUFFIX) {
  if (!json || typeof json.tag_name !== 'string') throw new Error('unexpected release data');
  const notes = typeof json.body === 'string' ? json.body : '';
  for (const asset of Array.isArray(json.assets) ? json.assets : []) {
    if (typeof asset.name !== 'string' || !asset.name.endsWith(suffix)) continue;
    if (!isTrustedDownload(asset.browser_download_url)) continue;
    return {
      version: normalize(json.tag_name), notes, assetName: asset.name, assetURL: asset.browser_download_url,
      sha256: checksumInNotes(notes, asset.name),
    };
  }
  return null;
}

async function fetchLatest(currentVersion) {
  const res = await fetch(LATEST_URL, {
    headers: { Accept: 'application/vnd.github+json', 'User-Agent': `Grizzly/${currentVersion}` },
    signal: AbortSignal.timeout(15000),
  });
  if (!res.ok) throw new Error(`GitHub answered ${res.status}`);
  return parseRelease(await res.json());
}

/** Streams the release file into a temporary folder, reporting progress, and checks its SHA-256 when one is published. */
async function download(release, currentVersion, onProgress) {
  if (!isTrustedDownload(release.assetURL)) throw new Error('untrusted download address');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'grizzly-update-'));
  const file = path.join(dir, release.assetName);
  const res = await fetch(release.assetURL, { headers: { 'User-Agent': `Grizzly/${currentVersion}` }, redirect: 'follow' });
  if (!res.ok || !res.body) throw new Error(`download failed (${res.status})`);
  const total = Number(res.headers.get('content-length')) || 0;
  const hash = crypto.createHash('sha256');
  const out = fs.createWriteStream(file);
  let received = 0;
  try {
    for await (const chunk of res.body) {
      hash.update(chunk);
      received += chunk.length;
      if (!out.write(chunk)) await new Promise((r) => out.once('drain', r));
      if (total) onProgress(received / total);
    }
    await new Promise((resolve, reject) => { out.end((err) => (err ? reject(err) : resolve())); });
  } catch (err) {
    out.destroy();
    fs.rmSync(dir, { recursive: true, force: true });
    throw err;
  }
  if (release.sha256 && hash.digest('hex') !== release.sha256) {
    fs.rmSync(dir, { recursive: true, force: true });
    throw Object.assign(new Error('checksum mismatch'), { code: 'ECHECKSUM' });
  }
  return file;
}

/** Windows batch script: waits until the running exe can be replaced (it is locked while the app runs), swaps it, starts it. */
const REPLACE_SCRIPT = [
  '@echo off',
  'set "SRC=%~1"',
  'set "DST=%~2"',
  'set /a n=0',
  ':retry',
  'move /Y "%SRC%" "%DST%" >nul 2>&1',
  'if not errorlevel 1 goto done',
  'set /a n+=1',
  'if %n% GEQ 90 exit /b 1',
  'timeout /t 1 /nobreak >nul',
  'goto retry',
  ':done',
  'start "" "%DST%"',
  '(goto) 2>nul & del "%~f0"',
  '',
].join('\r\n');

module.exports = { REPOSITORY, ASSET_SUFFIX, normalize, isNewer, isTrustedDownload, checksumInNotes, parseRelease, fetchLatest, download, REPLACE_SCRIPT };
