const { app, BrowserWindow, Menu, dialog, ipcMain, shell, nativeTheme } = require('electron');
const fs = require('fs');
const path = require('path');

const EXTENSIONS = ['md', 'markdown', 'mdown', 'txt', 'text', 'json', 'yaml', 'yml', 'csv', 'tsv', 'log',
  'xml', 'html', 'htm', 'ini', 'conf', 'toml', 'tex', 'rtf'];

// Portable build: keep settings and the library next to the .exe when that folder is writable.
// The app used to be called MD Reader: its data folders are renamed once so settings and the library carry over.
function migrate(from, to) {
  try { if (fs.existsSync(from) && !fs.existsSync(to)) fs.renameSync(from, to); } catch { /* start fresh */ }
}

(function pickDataDir() {
  const dir = process.env.PORTABLE_EXECUTABLE_DIR;
  if (!dir) {
    migrate(path.join(app.getPath('appData'), 'MD Reader'), path.join(app.getPath('appData'), 'Grizzly'));
    return;
  }
  migrate(path.join(dir, 'MDReaderData'), path.join(dir, 'GrizzlyData'));
  const data = path.join(dir, 'GrizzlyData');
  try {
    fs.mkdirSync(data, { recursive: true });
    fs.accessSync(data, fs.constants.W_OK);
    app.setPath('userData', data);
  } catch { /* read-only location: fall back to %APPDATA% */ }
})();

let STRINGS_EN = {};
try { STRINGS_EN = require('./strings-en.json'); } catch { /* English table is optional */ }
const T = (key) => (app.getLocale().toLowerCase().startsWith('ru') ? key : (STRINGS_EN[key] || key));

let win = null;
let rendererReady = false;
let pendingFiles = [];

function filesFromArgv(argv) {
  const args = process.defaultApp ? argv.slice(2) : argv.slice(1);
  return args
    .filter((a) => !a.startsWith('-'))
    .map((a) => path.resolve(a))
    .filter((p) => { try { return fs.statSync(p).isFile(); } catch { return false; } });
}

function deliver(paths) {
  if (!paths.length) return;
  if (win && rendererReady) win.webContents.send('open-files', paths);
  else pendingFiles.push(...paths);
}

const statePath = () => path.join(app.getPath('userData'), 'window.json');

function loadBounds() {
  try { return JSON.parse(fs.readFileSync(statePath(), 'utf8')); } catch { return {}; }
}

function createWindow() {
  const saved = loadBounds();
  win = new BrowserWindow({
    width: saved.width || 1100,
    height: saved.height || 720,
    x: saved.x,
    y: saved.y,
    minWidth: 720,
    minHeight: 460,
    show: false,
    title: 'Grizzly',
    icon: path.join(__dirname, 'assets', 'icon.png'),
    backgroundColor: nativeTheme.shouldUseDarkColors ? '#1e1f22' : '#ffffff',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      sandbox: true,
      nodeIntegration: false,
    },
  });
  if (saved.maximized) win.maximize();
  win.once('ready-to-show', () => win.show());
  win.loadFile(path.join(__dirname, 'renderer', 'index.html'));

  win.webContents.setWindowOpenHandler(({ url }) => { openExternal(url); return { action: 'deny' }; });
  win.webContents.on('will-navigate', (e, url) => {
    if (!url.startsWith('file://')) { e.preventDefault(); openExternal(url); }
  });

  const saveBounds = () => {
    if (!win || win.isDestroyed()) return;
    const maximized = win.isMaximized();
    const b = maximized ? (saved.rect || win.getNormalBounds()) : win.getBounds();
    saved.rect = b;
    try { fs.writeFileSync(statePath(), JSON.stringify({ ...b, maximized })); } catch { /* ignore */ }
  };
  win.on('close', (e) => {
    if (hasUnsaved) {
      const choice = dialog.showMessageBoxSync(win, {
        type: 'warning',
        message: T('Есть несохранённые изменения.'),
        detail: T('Изменения будут потеряны, если их не сохранить.'),
        buttons: [T('Закрыть без сохранения'), T('Отмена')],
        defaultId: 1,
        cancelId: 1,
        noLink: true,
      });
      if (choice !== 0) { e.preventDefault(); return; }
    }
    saveBounds();
  });
  win.on('closed', () => { win = null; rendererReady = false; });
}

function openExternal(url) {
  if (/^(https?:|mailto:)/i.test(url)) shell.openExternal(url);
}

function send(action) {
  if (win) win.webContents.send('menu', action);
}

function buildMenu() {
  const item = (label, action, accelerator, extra = {}) => ({
    label: T(label), accelerator, click: () => send(action), ...extra,
  });
  // Hidden twins give a second shortcut for the same command.
  const alias = (action, accelerator) => ({ label: action, accelerator, visible: false, click: () => send(action) });

  const template = [
    {
      label: T('Файл'),
      submenu: [
        item('Открыть…', 'open', 'CmdOrCtrl+O'),
        item('Сохранить', 'save', 'CmdOrCtrl+S'),
        item('Закрыть вкладку', 'closeTab', 'CmdOrCtrl+W'),
        { type: 'separator' },
        item('Настройки…', 'settings', 'CmdOrCtrl+,'),
        { type: 'separator' },
        { label: T('Выход'), role: 'quit' },
      ],
    },
    {
      label: T('Правка'),
      submenu: [
        { role: 'undo' }, { role: 'redo' }, { type: 'separator' },
        { role: 'cut' }, { role: 'copy' }, { role: 'paste' }, { role: 'selectAll' },
      ],
    },
    {
      label: T('Поиск'),
      submenu: [
        item('Найти…', 'find', 'CmdOrCtrl+F'),
        item('Найти далее', 'findNext', 'CmdOrCtrl+G'),
        item('Найти ранее', 'findPrev', 'CmdOrCtrl+Shift+G'),
        alias('findNext', 'F3'),
        alias('findPrev', 'Shift+F3'),
      ],
    },
    {
      label: T('Вкладки'),
      submenu: [
        item('Следующая вкладка', 'nextTab', 'CmdOrCtrl+Shift+]'),
        item('Предыдущая вкладка', 'prevTab', 'CmdOrCtrl+Shift+['),
        alias('nextTab', 'Ctrl+Tab'),
        alias('prevTab', 'Ctrl+Shift+Tab'),
        { type: 'separator' },
        item('Два файла рядом', 'split', 'CmdOrCtrl+\\'),
      ],
    },
    {
      label: T('Вид'),
      submenu: [
        item('Режим чтения', 'modeReading', 'CmdOrCtrl+Alt+1'),
        item('Исходник', 'modeSource', 'CmdOrCtrl+Alt+2'),
        item('Правка', 'modeEdit', 'CmdOrCtrl+Alt+3'),
        { type: 'separator' },
        item('Обновить файл', 'reload', 'CmdOrCtrl+R'),
        item('Крупнее', 'fontUp', 'CmdOrCtrl+Plus'),
        item('Мельче', 'fontDown', 'CmdOrCtrl+-'),
        alias('fontUp', 'CmdOrCtrl+='),
        { type: 'separator' },
        { role: 'togglefullscreen' },
        { label: 'DevTools', accelerator: 'CmdOrCtrl+Shift+I', visible: false, role: 'toggleDevTools' },
      ],
    },
  ];
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

// ---- IPC ----------------------------------------------------------------

const decode = (buf, label) => new TextDecoder(label).decode(buf);

function rtfToText(src) {
  // Minimal RTF reader: keeps text, paragraphs, \'hh and \uN escapes, drops control words and hidden groups.
  const skip = new Set(['fonttbl', 'colortbl', 'stylesheet', 'info', 'pict', 'header', 'footer', 'object', 'themedata',
    'colorschememapping', 'latentstyles', 'datastore', 'listtable', 'listoverridetable', 'rsidtbl', 'generator']);
  const cp = /\\ansicpg(\d+)/.exec(src);
  const codepage = cp ? 'windows-' + cp[1] : 'windows-1252';
  // One entry per open group: whether its text is ignored, and the \uc value in force.
  const stack = [{ ignored: false, uc: 1 }];
  let out = '';
  let i = 0;
  const hexBytes = [];
  const flushHex = () => {
    if (!hexBytes.length) return;
    try { out += decode(Uint8Array.from(hexBytes), codepage); } catch { out += decode(Uint8Array.from(hexBytes), 'windows-1252'); }
    hexBytes.length = 0;
  };
  while (i < src.length) {
    const c = src[i];
    const top = stack[stack.length - 1];
    if (c === '{') {
      flushHex();
      // {\*\dest ...} and known destinations are ignored as a whole.
      const rest = src.slice(i + 1, i + 40);
      const dest = /^\\([a-z]+)/.exec(rest);
      stack.push({ ignored: top.ignored || rest.startsWith('\\*') || !!(dest && skip.has(dest[1])), uc: top.uc });
      i++;
    } else if (c === '}') {
      flushHex();
      if (stack.length > 1) stack.pop();
      i++;
    } else if (c === '\\') {
      const n = src[i + 1];
      if (n === "'") {
        const byte = parseInt(src.substr(i + 2, 2), 16);
        if (!top.ignored && !Number.isNaN(byte)) hexBytes.push(byte);
        i += 4;
        continue;
      }
      flushHex();
      if (n === '\\' || n === '{' || n === '}') { if (!top.ignored) out += n; i += 2; continue; }
      if (n === '~') { if (!top.ignored) out += ' '; i += 2; continue; }
      if (n === '-' || n === '_' || n === '*') { i += 2; continue; }
      const m = /^\\([a-zA-Z]+)(-?\d+)? ?/.exec(src.slice(i, i + 40));
      if (!m) { i += 2; continue; }
      const word = m[1];
      const arg = m[2] === undefined ? undefined : parseInt(m[2], 10);
      i += m[0].length;
      if (top.ignored) continue;
      if (word === 'par' || word === 'line') out += '\n';
      else if (word === 'tab') out += '\t';
      else if (word === 'emdash') out += '—';
      else if (word === 'endash') out += '–';
      else if (word === 'bullet') out += '•';
      else if (word === 'lquote') out += '‘';
      else if (word === 'rquote') out += '’';
      else if (word === 'ldblquote') out += '“';
      else if (word === 'rdblquote') out += '”';
      else if (word === 'uc' && arg !== undefined) top.uc = arg;
      else if (word === 'u' && arg !== undefined) {
        out += String.fromCharCode(arg < 0 ? arg + 65536 : arg);
        i += top.uc; // skip the ANSI fallback characters
      }
    } else if (c === '\r' || c === '\n') {
      i++;
    } else {
      flushHex();
      if (!top.ignored) out += c;
      i++;
    }
  }
  flushHex();
  return out.replace(/\n{3,}/g, '\n\n').trim() + '\n';
}

/** Reads a file and decodes it: UTF-8 (BOM), UTF-16 (BOM), UTF-8, then Windows-1251. */
function readText(file) {
  const buf = fs.readFileSync(file);
  if (path.extname(file).toLowerCase() === '.rtf') {
    return { text: rtfToText(buf.toString('latin1')), encoding: 'RTF' };
  }
  if (buf.length >= 3 && buf[0] === 0xef && buf[1] === 0xbb && buf[2] === 0xbf) {
    return { text: decode(buf.subarray(3), 'utf-8'), encoding: 'UTF-8' };
  }
  if (buf.length >= 2 && buf[0] === 0xff && buf[1] === 0xfe) return { text: decode(buf.subarray(2), 'utf-16le'), encoding: 'UTF-16' };
  if (buf.length >= 2 && buf[0] === 0xfe && buf[1] === 0xff) return { text: decode(buf.subarray(2), 'utf-16be'), encoding: 'UTF-16' };
  try {
    return { text: new TextDecoder('utf-8', { fatal: true }).decode(buf), encoding: 'UTF-8' };
  } catch { /* not UTF-8 */ }
  return { text: decode(buf, 'windows-1251'), encoding: 'Windows-1251' };
}

ipcMain.handle('app:info', () => ({
  platform: process.platform,
  locale: app.getLocale(),
  version: app.getVersion(),
  dataDir: app.getPath('userData'),
}));

ipcMain.on('renderer:ready', () => {
  rendererReady = true;
  if (pendingFiles.length) { win.webContents.send('open-files', pendingFiles); pendingFiles = []; }
});

ipcMain.handle('dialog:open', async () => {
  const result = await dialog.showOpenDialog(win, {
    properties: ['openFile', 'multiSelections'],
    filters: [
      { name: T('Файлы Grizzly'), extensions: EXTENSIONS },
      { name: T('Все файлы'), extensions: ['*'] },
    ],
  });
  return result.canceled ? [] : result.filePaths;
});

ipcMain.handle('file:read', (_e, file) => {
  try {
    const { text, encoding } = readText(file);
    return { ok: true, text, encoding, mtimeMs: fs.statSync(file).mtimeMs };
  } catch (err) {
    return { ok: false, code: err.code || 'EREAD' };
  }
});

/** Plain text as a minimal RTF document (the original formatting is not kept). */
function textToRtf(text) {
  let out = '{\\rtf1\\ansi\\ansicpg1252\\deff0{\\fonttbl{\\f0\\fswiss Helvetica;}}\\f0\\fs24 ';
  for (const ch of text) {
    if (ch === '\\' || ch === '{' || ch === '}') out += '\\' + ch;
    else if (ch === '\n') out += '\\par\n';
    else if (ch === '\t') out += '\\tab ';
    else if (ch === '\r') continue;
    else if (ch.codePointAt(0) < 128) out += ch;
    else for (let i = 0; i < ch.length; i++) { const u = ch.charCodeAt(i); out += '\\u' + (u > 32767 ? u - 65536 : u) + '?'; }
  }
  return out + '}';
}

let cp1251 = null;
function encodeCp1251(text) {
  if (!cp1251) {
    cp1251 = new Map();
    const dec = new TextDecoder('windows-1251');
    for (let b = 0x80; b < 256; b++) cp1251.set(dec.decode(Uint8Array.of(b)), b);
  }
  const out = [];
  for (const ch of text) {
    const code = ch.codePointAt(0);
    const byte = code < 0x80 ? code : cp1251.get(ch);
    if (byte === undefined) throw Object.assign(new Error('unmappable character'), { code: 'EENCODE' });
    out.push(byte);
  }
  return Buffer.from(out);
}

/** Inverse of readText: writes the text back in the encoding the file was read with (a UTF-8 BOM is kept). */
function encodeText(text, encoding, file) {
  switch (encoding) {
    case 'UTF-16': return Buffer.concat([Buffer.from([0xff, 0xfe]), Buffer.from(text, 'utf16le')]);
    case 'Windows-1251': return encodeCp1251(text);
    case 'RTF': return Buffer.from(textToRtf(text), 'latin1');
    case 'UTF-8': {
      let bom = false;
      try {
        const head = Buffer.alloc(3);
        const fd = fs.openSync(file, 'r');
        try { bom = fs.readSync(fd, head, 0, 3, 0) === 3 && head[0] === 0xef && head[1] === 0xbb && head[2] === 0xbf; } finally { fs.closeSync(fd); }
      } catch { /* a new or unreadable file has no BOM */ }
      return Buffer.concat([bom ? Buffer.from([0xef, 0xbb, 0xbf]) : Buffer.alloc(0), Buffer.from(text, 'utf8')]);
    }
  }
  throw Object.assign(new Error('unsupported encoding'), { code: 'EENCODE' });
}

ipcMain.handle('file:write', (_e, file, text, encoding) => {
  try {
    fs.writeFileSync(file, encodeText(String(text), encoding, file));
    return { ok: true, mtimeMs: fs.statSync(file).mtimeMs };
  } catch (err) {
    return { ok: false, code: err.code || 'EWRITE' };
  }
});

ipcMain.handle('dialog:confirmSave', async (_e, name) => {
  const { response } = await dialog.showMessageBox(win, {
    type: 'warning',
    message: T('Сохранить изменения в «%@»?').replace('%@', name),
    detail: T('Изменения будут потеряны, если их не сохранить.'),
    buttons: [T('Сохранить'), T('Не сохранять'), T('Отмена')],
    defaultId: 0,
    cancelId: 2,
    noLink: true,
  });
  return ['save', 'discard', 'cancel'][response];
});

let hasUnsaved = false;
ipcMain.on('app:dirty', (_e, dirty) => { hasUnsaved = !!dirty; });

ipcMain.handle('file:mtimes', (_e, files) => {
  const out = {};
  for (const f of files) {
    try { out[f] = fs.statSync(f).mtimeMs; } catch { out[f] = null; }
  }
  return out;
});

ipcMain.handle('shell:reveal', (_e, file) => { shell.showItemInFolder(file); });
ipcMain.handle('shell:external', (_e, url) => { openExternal(String(url)); });

const libraryPath = () => path.join(app.getPath('userData'), 'library.json');

ipcMain.handle('library:load', () => {
  try { return fs.readFileSync(libraryPath(), 'utf8'); } catch { return null; }
});

ipcMain.handle('library:save', (_e, json) => {
  const tmp = libraryPath() + '.tmp';
  try {
    fs.writeFileSync(tmp, json);
    fs.renameSync(tmp, libraryPath());
    return true;
  } catch { return false; }
});

// ---- Lifecycle ----------------------------------------------------------

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on('second-instance', (_e, argv) => {
    if (win) {
      if (win.isMinimized()) win.restore();
      win.focus();
    }
    deliver(filesFromArgv(argv));
  });

  app.whenReady().then(() => {
    pendingFiles = filesFromArgv(process.argv);
    buildMenu();
    createWindow();
    app.on('activate', () => { if (!BrowserWindow.getAllWindows().length) createWindow(); });
  });

  app.on('window-all-closed', () => app.quit());
}
