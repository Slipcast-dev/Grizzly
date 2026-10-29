// Builds the English string table from the macOS app's en.lproj/Localizable.strings.
// Keys are the Russian source strings. Run: npm run strings
const fs = require('fs');
const path = require('path');

const src = path.join(__dirname, '..', '..', 'resources', 'en.lproj', 'Localizable.strings');
const table = {};
for (const line of fs.readFileSync(src, 'utf8').split('\n')) {
  const m = /^"(.*)" = "(.*)";$/.exec(line);
  if (!m) continue;
  table[JSON.parse('"' + m[1] + '"')] = JSON.parse('"' + m[2] + '"');
}

// Strings that exist only in the Windows port.
Object.assign(table, {
  'Файл': 'File',
  'Показать в проводнике': 'Show in Explorer',
  'Правка': 'Edit',
  'Настройки': 'Settings',
  'Настройки…': 'Settings…',
  'Выход': 'Exit',
  'Боковая панель': 'Sidebar',
  'Показать в проводнике': 'Show in Explorer',
  'Файлы Grizzly': 'Grizzly files',
  'Все файлы': 'All files',
  'Готово.': 'Done.',
  'Сохранить как… (Ctrl+Shift+S)': 'Save As… (Ctrl+Shift+S)',
});

const root = path.join(__dirname, '..');
fs.writeFileSync(path.join(root, 'strings-en.json'), JSON.stringify(table, null, 1));
fs.writeFileSync(path.join(root, 'renderer', 'strings-en.js'), 'window.STRINGS_EN = ' + JSON.stringify(table, null, 1) + ';\n');
console.log(Object.keys(table).length + ' strings');
