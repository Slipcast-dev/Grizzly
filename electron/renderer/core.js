/* Document model: file types, Markdown / CSV parsing, syntax rules and search.
   A direct port of Core/*.swift from the macOS app. */

// ---- File types ------------------------------------------------------------

const EXTENSION_TYPES = {
  md: 'markdown', markdown: 'markdown', mdown: 'markdown',
  txt: 'text', text: 'text',
  json: 'json',
  yaml: 'yaml', yml: 'yaml',
  csv: 'csv', tsv: 'csv',
  log: 'log',
  xml: 'xml',
  html: 'html', htm: 'html',
  ini: 'config', conf: 'config', toml: 'config',
  tex: 'tex',
  rtf: 'rtf',
  py: 'python', pyw: 'python',
  swift: 'swift',
  c: 'cpp', h: 'cpp', cpp: 'cpp', cc: 'cpp', cxx: 'cpp', hpp: 'cpp', hh: 'cpp', hxx: 'cpp',
  cs: 'csharp',
  js: 'javascript', mjs: 'javascript', cjs: 'javascript', jsx: 'javascript',
  ts: 'typescript', tsx: 'typescript',
  css: 'css', scss: 'css',
  php: 'php',
  go: 'go', rs: 'rust', java: 'java', kt: 'kotlin', kts: 'kotlin', sql: 'sql',
  sh: 'shell', bash: 'shell', zsh: 'shell', rb: 'ruby',
};

/** Language names after the opening ``` of a Markdown code block. */
const FENCE_TAGS = {
  python: 'python', py: 'python', python3: 'python', swift: 'swift',
  c: 'cpp', h: 'cpp', cpp: 'cpp', 'c++': 'cpp', cc: 'cpp', cxx: 'cpp', hpp: 'cpp',
  cs: 'csharp', csharp: 'csharp', 'c#': 'csharp',
  js: 'javascript', javascript: 'javascript', jsx: 'javascript', mjs: 'javascript', node: 'javascript',
  ts: 'typescript', typescript: 'typescript', tsx: 'typescript',
  css: 'css', scss: 'css', php: 'php',
  go: 'go', golang: 'go', rust: 'rust', rs: 'rust', java: 'java', kotlin: 'kotlin', kt: 'kotlin',
  sql: 'sql', sh: 'shell', bash: 'shell', shell: 'shell', zsh: 'shell', ruby: 'ruby', rb: 'ruby',
  json: 'json', yaml: 'yaml', yml: 'yaml', xml: 'xml', html: 'html', htm: 'html',
  ini: 'config', toml: 'config', tex: 'tex', latex: 'tex', log: 'log',
};
const fenceType = (tag) => FENCE_TAGS[(String(tag || '').split(/[\s{]/)[0] || '').toLowerCase()] || null;

const TYPE_TITLES = {
  markdown: 'Markdown', text: 'Text', json: 'JSON', yaml: 'YAML', csv: 'CSV', log: 'Log',
  xml: 'XML', html: 'HTML', config: 'INI / TOML', tex: 'TeX', rtf: 'RTF',
  python: 'Python', swift: 'Swift', cpp: 'C / C++', csharp: 'C#', javascript: 'JavaScript', typescript: 'TypeScript', css: 'CSS', php: 'PHP',
  go: 'Go', rust: 'Rust', java: 'Java', kotlin: 'Kotlin', sql: 'SQL', shell: 'Shell', ruby: 'Ruby',
};

const TYPE_ICONS = {
  markdown: 'docRich', rtf: 'docRich', json: 'braces', yaml: 'doc', config: 'doc', xml: 'doc',
  html: 'doc', tex: 'doc', csv: 'table', log: 'list', text: 'docPlain',
  python: 'code', swift: 'code', cpp: 'code', csharp: 'code', javascript: 'code', typescript: 'code', css: 'code', php: 'code',
  go: 'code', rust: 'code', java: 'code', kotlin: 'code', sql: 'code', shell: 'code', ruby: 'code',
};

const baseName = (p) => p.split(/[\\/]/).pop();
const extOf = (p) => { const m = /\.([^.\\/]+)$/.exec(p); return m ? m[1].toLowerCase() : ''; };
const fileTypeOf = (p) => EXTENSION_TYPES[extOf(p)] || 'text';

// ---- Inline Markdown -------------------------------------------------------

/** Parses inline Markdown into a small tree: text, code, strong, em, del, link. */
function parseInline(s) {
  const out = [];
  let buf = '';
  let i = 0;
  const n = s.length;
  const flush = () => { if (buf) { out.push({ t: 'text', v: buf }); buf = ''; } };
  const isAlnum = (ch) => !!ch && /[\p{L}\p{N}]/u.test(ch);

  while (i < n) {
    const c = s[i];

    if (c === '\\' && i + 1 < n && /[\\`*_{}[\]()#+\-.!|~<>]/.test(s[i + 1])) {
      buf += s[i + 1]; i += 2; continue;
    }

    if (c === '`') {
      let run = 1;
      while (s[i + run] === '`') run++;
      const fence = '`'.repeat(run);
      const close = s.indexOf(fence, i + run);
      if (close > i + run) {
        flush();
        out.push({ t: 'code', v: s.slice(i + run, close).replace(/^ (.*) $/, '$1') });
        i = close + run;
        continue;
      }
      buf += fence; i += run; continue;
    }

    if (c === '*' || c === '_') {
      const prev = s[i - 1];
      const intraword = c === '_' && isAlnum(prev);
      if (!intraword) {
        const dbl = c + c;
        if (s.startsWith(dbl, i) && !/\s/.test(s[i + 2] || ' ')) {
          let close = s.indexOf(dbl, i + 2);
          while (close > 0 && /\s/.test(s[close - 1])) close = s.indexOf(dbl, close + 1);
          if (close > 0 && s[close + 2] === c) close++; // ***both*** closes the inner run first
          if (close > i + 2) {
            flush();
            out.push({ t: 'strong', c: parseInline(s.slice(i + 2, close)) });
            i = close + 2;
            continue;
          }
        } else if (!/\s/.test(s[i + 1] || ' ')) {
          let close = i + 1;
          for (;;) {
            close = s.indexOf(c, close);
            if (close < 0) break;
            const bad = /\s/.test(s[close - 1]) || s[close + 1] === c || (c === '_' && isAlnum(s[close + 1]));
            if (!bad && close > i + 1) break;
            close++;
          }
          if (close > i + 1) {
            flush();
            out.push({ t: 'em', c: parseInline(s.slice(i + 1, close)) });
            i = close + 1;
            continue;
          }
        }
      }
      buf += c; i++; continue;
    }

    if (c === '~' && s[i + 1] === '~') {
      const close = s.indexOf('~~', i + 2);
      if (close > i + 2) {
        flush();
        out.push({ t: 'del', c: parseInline(s.slice(i + 2, close)) });
        i = close + 2;
        continue;
      }
    }

    if (c === '[' || (c === '!' && s[i + 1] === '[')) {
      const image = c === '!';
      const open = image ? i + 1 : i;
      let depth = 0;
      let close = -1;
      for (let k = open; k < n; k++) {
        if (s[k] === '\\') { k++; continue; }
        if (s[k] === '[') depth++;
        else if (s[k] === ']' && --depth === 0) { close = k; break; }
      }
      if (close > 0 && s[close + 1] === '(') {
        const end = s.indexOf(')', close + 2);
        if (end > 0) {
          flush();
          const url = s.slice(close + 2, end).trim().split(/\s+/)[0] || '';
          const inner = parseInline(s.slice(open + 1, close));
          out.push(image ? { t: 'em', c: inner } : { t: 'link', c: inner, url });
          i = end + 1;
          continue;
        }
      }
    }

    if (c === '<') {
      const m = /^<((?:https?:\/\/|mailto:)[^>\s]+)>/.exec(s.slice(i));
      if (m) {
        flush();
        out.push({ t: 'link', c: [{ t: 'text', v: m[1] }], url: m[1] });
        i += m[0].length;
        continue;
      }
    }

    buf += c; i++;
  }
  flush();
  return out;
}

function inlinePlain(nodes) {
  let s = '';
  for (const n of nodes) s += n.t === 'text' || n.t === 'code' ? n.v : inlinePlain(n.c);
  return s;
}

const plain = (s) => inlinePlain(parseInline(s));

function inlineToDom(nodes, parent) {
  for (const n of nodes) {
    let el;
    switch (n.t) {
      case 'text': parent.appendChild(document.createTextNode(n.v)); continue;
      case 'code': el = document.createElement('code'); el.textContent = n.v; break;
      case 'strong': el = document.createElement('strong'); inlineToDom(n.c, el); break;
      case 'em': el = document.createElement('em'); inlineToDom(n.c, el); break;
      case 'del': el = document.createElement('del'); inlineToDom(n.c, el); break;
      case 'link':
        el = document.createElement('a');
        el.dataset.url = n.url;
        el.title = n.url;
        inlineToDom(n.c, el);
        break;
    }
    parent.appendChild(el);
  }
  return parent;
}

// ---- Markdown blocks -------------------------------------------------------

const MarkdownParser = (() => {
  const heading = (s) => {
    let level = 0;
    while (s[level] === '#') level++;
    if (level < 1 || level > 6 || s[level] !== ' ') return null;
    return [level, s.slice(level).trim()];
  };

  const isRule = (s) => {
    const compact = s.replace(/ /g, '');
    if (compact.length < 3 || !'-*_'.includes(compact[0])) return false;
    return [...compact].every((ch) => ch === compact[0]);
  };

  const bullet = (s) => {
    if (s.length <= 2 || !'-*+'.includes(s[0]) || s[1] !== ' ') return null;
    let t = s.slice(2);
    if (t.startsWith('[ ] ')) t = '☐ ' + t.slice(4);
    else if (t.toLowerCase().startsWith('[x] ')) t = '☑ ' + t.slice(4);
    return t;
  };

  const numberedItem = (s) => {
    const dot = s.indexOf('.');
    if (dot <= 0 || !/^\p{N}+$/u.test(s.slice(0, dot)) || s[dot + 1] !== ' ') return null;
    return s.slice(dot + 2);
  };

  const isTableSeparator = (s) => {
    const t = s.trim();
    return t.includes('-') && t.includes('|') && /^[|\-: ]+$/.test(t);
  };

  const cells = (s) => {
    let t = s.trim();
    if (t.startsWith('|')) t = t.slice(1);
    if (t.endsWith('|')) t = t.slice(0, -1);
    return t.split('|').map((c) => c.trim());
  };

  function parse(lines) {
    const blocks = [];
    let i = 0;
    while (i < lines.length) {
      const trimmed = lines[i].trim();
      if (!trimmed) { i++; continue; }

      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        const fence = trimmed.slice(0, 3);
        const lang = trimmed.slice(3).trim();
        const body = [];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith(fence)) { body.push(lines[i]); i++; }
        i++;
        blocks.push({ type: 'code', lang, code: body.join('\n') });
        continue;
      }

      const h = heading(trimmed);
      if (h) { blocks.push({ type: 'heading', level: h[0], text: h[1] }); i++; continue; }

      if (isRule(trimmed)) { blocks.push({ type: 'rule' }); i++; continue; }

      if (trimmed.startsWith('>')) {
        const q = [];
        while (i < lines.length && lines[i].trim().startsWith('>')) {
          let t = lines[i].trim().slice(1);
          if (t.startsWith(' ')) t = t.slice(1);
          q.push(t); i++;
        }
        blocks.push({ type: 'quote', text: q.join('\n') });
        continue;
      }

      if (bullet(trimmed) !== null) {
        const items = [];
        for (let b; i < lines.length && (b = bullet(lines[i].trim())) !== null; i++) items.push(b);
        blocks.push({ type: 'bullets', items });
        continue;
      }

      if (numberedItem(trimmed) !== null) {
        const items = [];
        for (let b; i < lines.length && (b = numberedItem(lines[i].trim())) !== null; i++) items.push(b);
        blocks.push({ type: 'numbered', items });
        continue;
      }

      if (trimmed.includes('|') && i + 1 < lines.length && isTableSeparator(lines[i + 1])) {
        const header = cells(trimmed);
        const rows = [];
        i += 2;
        while (i < lines.length && lines[i].includes('|') && lines[i].trim()) { rows.push(cells(lines[i])); i++; }
        blocks.push({ type: 'table', header, rows });
        continue;
      }

      const para = [];
      while (i < lines.length) {
        const t = lines[i].trim();
        if (!t || t.startsWith('```') || t.startsWith('>') || heading(t) || bullet(t) !== null
          || numberedItem(t) !== null || isRule(t)) break;
        para.push(t); i++;
      }
      if (!para.length) i++;
      else blocks.push({ type: 'paragraph', text: para.join(' ') });
    }
    return blocks;
  }

  return { parse };
})();

// ---- CSV -------------------------------------------------------------------

const CSV = (() => {
  function parseLine(line, delimiter) {
    const cells = [];
    const starts = [];
    let current = '';
    let inQuotes = false;
    let cellStart = 0;
    const n = line.length;
    for (let i = 0; i < n; i++) {
      const c = line[i];
      if (inQuotes) {
        if (c === '"') {
          if (line[i + 1] === '"') { current += '"'; i++; } else inQuotes = false;
        } else current += c;
      } else if (c === '"' && current === '') {
        inQuotes = true;
      } else if (c === delimiter) {
        cells.push(current); starts.push(cellStart);
        current = ''; cellStart = i + 1;
      } else current += c;
    }
    cells.push(current); starts.push(cellStart);
    return { line, cells, starts };
  }

  function detectDelimiter(path, lines) {
    if (extOf(path) === 'tsv') return '\t';
    const sample = lines.slice(0, 5).join('\n');
    const count = (d) => sample.split(d).length - 1;
    return [',', ';', '\t', '|'].reduce((best, d) => (count(d) > count(best) ? d : best), ',');
  }

  /** Row i is line i of the document, so search and scrolling keep using line numbers. */
  function parse(lines, delimiter) {
    let end = lines.length;
    while (end > 1 && !lines[end - 1].trim()) end--;
    const rows = lines.slice(0, end).map((l) => parseLine(l, delimiter));
    const columns = Math.max(0, ...rows.map((r) => r.cells.length));
    const widths = new Array(columns).fill(3);
    for (const row of rows.slice(0, 500)) {
      row.cells.forEach((cell, i) => { widths[i] = Math.min(40, Math.max(widths[i], cell.length)); });
    }
    return { rows, widths };
  }

  return { parse, detectDelimiter };
})();

// ---- Document --------------------------------------------------------------

const HIGHLIGHT_LIMIT = 2 * 1024 * 1024;

function makeDocument(path, loaded) {
  const type = fileTypeOf(path);
  const parsed = LineEndings.parse(loaded.text);
  const lines = parsed.normalized.split('\n');
  // Syntax colors are skipped for very large files: they would freeze the view.
  const large = loaded.text.length > HIGHLIGHT_LIMIT;
  return {
    id: crypto.randomUUID(),
    libraryID: null,
    path,
    name: baseName(path),
    type,
    encoding: loaded.encoding,
    text: loaded.text,
    lines,
    endings: parsed.endings, // how the file ended its lines; LineEndings.apply restores it on save
    large,
    syntaxStates: large ? [] : Syntax.states(lines, type),
    blocks: type === 'markdown' ? MarkdownParser.parse(lines) : [],
    csv: type === 'csv' ? CSV.parse(lines, CSV.detectDelimiter(path, lines)) : null,
    modified: loaded.mtimeMs,
    wordCount: loaded.text.split(/\s+/).filter(Boolean).length,
  };
}

// ---- Syntax coloring -------------------------------------------------------

const Syntax = (() => {
  // \w is ASCII-only in JavaScript; the macOS rules (ICU) treat Cyrillic letters as word characters.
  const WORD = '\\p{L}\\p{N}_';
  const unicodeWord = (pattern) => {
    let out = '';
    let inClass = false;
    for (let i = 0; i < pattern.length; i++) {
      const c = pattern[i];
      if (c === '\\') {
        const n = pattern[++i];
        out += n === 'w' ? (inClass ? WORD : '[' + WORD + ']') : '\\' + n;
      } else {
        if (c === '[') inClass = true;
        else if (c === ']') inClass = false;
        out += c;
      }
    }
    return out;
  };
  const rule = (pattern, role, flags = '') => ({ re: new RegExp(unicodeWord(pattern), 'gu' + flags), role });

  const stringRule = rule('"(?:[^"\\\\]|\\\\.)*"|\'[^\']*\'', 'string');
  const numberRule = rule('(?<![\\w.])-?\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?(?![\\w.])', 'number');

  const markup = [
    rule('<!--.*?-->|<!--.*$|^.*?-->', 'comment'),
    rule('"[^"]*"|\'[^\']*\'', 'string'),
    rule('<[!?/]?[A-Za-z][\\w:\\-.]*|<[!?]\\w+', 'keyword'),
    rule('[\\w:\\-.]+(?==)', 'key'),
    rule('/?\\??>', 'keyword'),
    rule('&\\w+;|&#\\d+;', 'number'),
  ];

  const RULES = {
    json: [
      rule('"(?:[^"\\\\]|\\\\.)*"(?=\\s*:)', 'key'),
      stringRule, numberRule,
      rule('\\b(?:true|false|null)\\b', 'keyword'),
    ],
    yaml: [
      rule('(?:^|\\s)#.*$', 'comment'),
      rule('^\\s*(?:-\\s+)?(?:"[^"]*"|\'[^\']*\'|[\\w.\\-/ ]+?)(?=:(?:\\s|$))', 'key'),
      stringRule, numberRule,
      rule('\\b(?:true|false|null|yes|no|on|off)\\b|(?<=\\s)~(?=\\s|$)', 'keyword'),
      rule('^(?:---|\\.\\.\\.)\\s*$', 'secondary'),
      rule('[&*]\\w+|![\\w!]+', 'keyword'),
    ],
    config: [
      rule('^\\s*[;#].*$', 'comment'),
      rule('^\\s*\\[[^\\]]*\\]', 'keyword'),
      rule('^\\s*[\\w.\\-"]+(?=\\s*[=:])', 'key'),
      stringRule, numberRule,
      rule('\\b(?:true|false)\\b', 'keyword'),
      rule('\\s[;#].*$', 'comment'),
    ],
    xml: markup,
    html: markup,
    tex: [
      rule('(?<!\\\\)%.*$', 'comment'),
      rule('\\$\\$?[^$]*\\$\\$?', 'string'),
      rule('\\\\(?:begin|end)\\{[^}]*\\}', 'keyword'),
      rule('\\\\[A-Za-z]+\\*?', 'key'),
      rule('[{}\\[\\]]', 'secondary'),
    ],
    log: [
      rule('\\d{4}-\\d{2}-\\d{2}[T ]\\d{2}:\\d{2}:\\d{2}(?:[.,]\\d+)?(?:Z|[+-]\\d{2}:?\\d{2})?', 'secondary'),
      rule('\\b\\d{2}:\\d{2}:\\d{2}(?:[.,]\\d+)?\\b', 'secondary'),
      rule('\\b(?:ERROR|ERR|FATAL|CRITICAL|SEVERE|PANIC|EXCEPTION|FAILED)\\b', 'error'),
      rule('\\b(?:WARN|WARNING)\\b', 'warning'),
      rule('\\b(?:INFO|NOTICE|SUCCESS|OK)\\b', 'success'),
      rule('\\b(?:DEBUG|TRACE|VERBOSE)\\b', 'secondary'),
      rule('\\[[^\\]\\n]{1,40}\\]', 'key'),
    ],
  };

  // ---- Programming languages: comments and strings are scanned first (they can span lines), then rules apply.
  const block = (open, close, role) => ({ open, close, role });
  const words = (list, role) => rule('\\b(?:' + list.split(' ').join('|') + ')\\b', role);
  const codeNumber = rule('\\b(?:0[xX][0-9A-Fa-f_]+|0[bB][01_]+|\\d[\\d_]*(?:\\.\\d+)?(?:[eE][+-]?\\d+)?)[uUlLfFdDmMzZ]*\\b', 'number');
  const typeName = rule('\\b[A-Z][A-Za-z0-9_]*\\b', 'key');
  const cBlock = block('/*', '*/', 'comment');
  const QUOTES = '"\'';

  const jsRules = (extra) => [
    rule('@\\w+', 'key'),
    words('async await break case catch class const continue debugger default delete do else export extends finally for from function get if import in instanceof let new of return set static super switch this throw try typeof var void while with yield ' + extra, 'keyword'),
    words('true false null undefined NaN Infinity', 'number'),
    codeNumber, typeName,
  ];

  const icWords = (list, role) => rule('\\b(?:' + list.split(' ').join('|') + ')\\b', role, 'i');
  const CODE = {
    go: {
      lineComments: ['//'], blocks: [block('`', '`', 'string'), cBlock], quotes: QUOTES,
      rules: [
        words('break case chan const continue default defer else fallthrough for func go goto if import interface map package range return select struct switch type var', 'keyword'),
        words('true false nil iota', 'number'),
        codeNumber, typeName,
      ],
    },
    rust: {
      lineComments: ['//'], blocks: [cBlock], quotes: '"',
      rules: [
        rule('#!?\\[[^\\]]*\\]', 'key'),
        rule('\\b[a-z_][a-z0-9_]*!', 'key'),
        words('as async await break const continue crate dyn else enum extern fn for if impl in let loop match mod move mut pub ref return self Self static struct super trait type unsafe use where while', 'keyword'),
        words('true false None Some Ok Err', 'number'),
        codeNumber, typeName,
      ],
    },
    java: {
      lineComments: ['//'], blocks: [block('"""', '"""', 'string'), cBlock], quotes: QUOTES,
      rules: [
        rule('@\\w+', 'key'),
        words('abstract assert boolean break byte case catch char class const continue default do double else enum extends final finally float for goto if implements import instanceof int interface long native new package private protected public record return short static strictfp super switch synchronized this throw throws transient try var void volatile while yield', 'keyword'),
        words('true false null', 'number'),
        codeNumber, typeName,
      ],
    },
    kotlin: {
      lineComments: ['//'], blocks: [block('"""', '"""', 'string'), cBlock], quotes: QUOTES,
      rules: [
        rule('@\\w+', 'key'),
        words('abstract actual annotation as break by catch class companion const constructor continue crossinline data delegate do dynamic else enum expect external final finally for fun get if import in infix init inline inner interface internal is lateinit noinline object open operator out override package private protected public reified return sealed set super suspend this throw try typealias typeof val value var vararg when where while', 'keyword'),
        words('true false null', 'number'),
        codeNumber, typeName,
      ],
    },
    sql: {
      lineComments: ['--'], blocks: [cBlock], quotes: QUOTES,
      rules: [
        icWords('add all alter and as asc begin between by case check column commit constraint create cross database default delete desc distinct drop else end exists foreign from full group having if in index inner insert into is join key left like limit not null offset on or order outer primary references right rollback select set table then top union unique update values view when where with', 'keyword'),
        icWords('true false', 'number'),
        icWords('int integer bigint smallint varchar char text boolean bool date datetime timestamp decimal numeric float double real blob json', 'key'),
        codeNumber,
      ],
    },
    shell: {
      lineComments: ['#'], blocks: [], quotes: QUOTES,
      rules: [
        rule('\\$\\{[^}]*\\}|\\$[A-Za-z_]\\w*|\\$[0-9@#?$!*]', 'key'),
        words('if then else elif fi for while until do done case esac in function select time return exit break continue local export readonly declare unset source alias echo cd set shift trap eval exec', 'keyword'),
        words('true false', 'number'),
        codeNumber,
      ],
    },
    ruby: {
      lineComments: ['#'], blocks: [], quotes: QUOTES,
      rules: [
        rule('@{1,2}\\w+|\\$\\w+', 'key'),
        rule('(?<![:\\w]):[A-Za-z_]\\w*[?!]?', 'number'),
        words('alias and begin break case class def defined do else elsif end ensure for if in module next nil not or redo rescue retry return self super then undef unless until when while yield require require_relative include extend attr_accessor attr_reader attr_writer private protected public', 'keyword'),
        words('true false nil', 'number'),
        codeNumber, typeName,
      ],
    },
    python: {
      lineComments: ['#'], blocks: [block('"""', '"""', 'string'), block("'''", "'''", 'string')], quotes: QUOTES,
      rules: [
        rule('^\\s*@[\\w.]+|(?<=\\s)@[\\w.]+$', 'key'),
        words('and as assert async await break class continue def del elif else except finally for from global if import in is lambda nonlocal not or pass raise return try while with yield match case', 'keyword'),
        words('True False None self cls', 'number'),
        codeNumber, typeName,
      ],
    },
    swift: {
      lineComments: ['//'], blocks: [block('"""', '"""', 'string'), cBlock], quotes: '"',
      rules: [
        rule('@\\w+|#\\w+', 'key'),
        words('actor associatedtype async await break case catch class continue default defer deinit do else enum extension fallthrough fileprivate final for func guard if import in indirect init inout internal is lazy let mutating nonisolated nonmutating open operator override private protocol public repeat rethrows return static struct subscript super switch throw throws try typealias var weak where while some any willSet didSet get set self Self', 'keyword'),
        words('true false nil', 'number'),
        codeNumber, typeName,
      ],
    },
    cpp: {
      lineComments: ['//'], blocks: [cBlock], quotes: QUOTES,
      rules: [
        rule('^\\s*#\\s*\\w+', 'keyword'),
        rule('(?<=include )<[^>]*>|(?<=include)<[^>]*>', 'string'),
        words('alignas alignof auto bool break case catch char class concept const consteval constexpr const_cast continue co_await co_return co_yield decltype default delete do double dynamic_cast else enum explicit extern final float for friend goto if inline int long mutable namespace new noexcept operator override private protected public register reinterpret_cast requires return short signed sizeof static static_assert static_cast struct switch template this thread_local throw try typedef typeid typename union unsigned using virtual void volatile while', 'keyword'),
        words('true false NULL nullptr', 'number'),
        codeNumber, typeName,
      ],
    },
    csharp: {
      lineComments: ['//'], blocks: [cBlock], quotes: QUOTES,
      rules: [
        rule('^\\s*#\\s*\\w+', 'keyword'),
        words('abstract as async await base bool break byte case catch char checked class const continue decimal default delegate do double dynamic else enum event explicit extern finally fixed float for foreach get goto if implicit in init int interface internal is lock long nameof namespace new object operator out override params partial private protected public readonly record ref required return sbyte sealed set short sizeof stackalloc static string struct switch this throw try typeof uint ulong unchecked unsafe ushort using var virtual void volatile when where while with yield', 'keyword'),
        words('true false null', 'number'),
        codeNumber, typeName,
      ],
    },
    javascript: { lineComments: ['//'], blocks: [block('`', '`', 'string'), cBlock], quotes: QUOTES, rules: jsRules('') },
    typescript: {
      lineComments: ['//'], blocks: [block('`', '`', 'string'), cBlock], quotes: QUOTES,
      rules: jsRules('abstract any as asserts bigint boolean declare enum implements infer interface is keyof module namespace never number object override private protected public readonly satisfies string symbol type unknown'),
    },
    css: {
      lineComments: [], blocks: [cBlock], quotes: QUOTES,
      rules: [
        rule('@[\\w-]+', 'keyword'),
        rule('!important', 'error'),
        rule('^\\s*[\\w-]+(?=\\s*:\\s*[^;{]*[;}]?\\s*$)', 'key'),
        rule('(?<=[:\\s,(])#[0-9a-fA-F]{3,8}\\b', 'number'),
        rule('(?<![\\w-])-?(?:\\d+\\.?\\d*|\\.\\d+)(?:px|em|rem|%|vh|vw|vmin|vmax|ch|ex|pt|cm|mm|in|s|ms|deg|rad|turn|fr)?(?![\\w-])', 'number'),
        rule('[\\w-]+(?=\\()', 'key'),
        rule('::?[a-zA-Z-]+(?![\\w-]*\\s*:\\s)', 'keyword'),
        rule('[.#][A-Za-z_][\\w-]*', 'keyword'),
      ],
    },
    php: {
      lineComments: ['//', '#'], blocks: [cBlock], quotes: QUOTES,
      rules: [
        rule('<\\?php|<\\?=|\\?>', 'keyword'),
        rule('\\$\\w+', 'key'),
        words('abstract and array as break callable case catch class clone const continue declare default do echo else elseif empty enddeclare endfor endforeach endif endswitch endwhile enum extends final finally fn for foreach function global goto if implements include include_once instanceof insteadof interface isset list match namespace new or print private protected public readonly require require_once return static switch throw trait try unset use var while xor yield', 'keyword'),
        rule('\\b(?:true|false|null|TRUE|FALSE|NULL)\\b', 'number'),
        codeNumber, typeName,
      ],
    },
  };

  /** Comments and strings of one line. `start` is the open block (index + 1) carried from the previous line. */
  function scan(line, lang, start) {
    const out = [];
    const n = line.length;
    let state = start;
    let i = 0;
    const find = (pat, from, escapes) => {
      for (let j = from; j + pat.length <= n; j++) {
        if (escapes && line[j] === '\\') { j++; continue; }
        if (line.startsWith(pat, j)) return j;
      }
      return -1;
    };
    const add = (from, to, role) => { if (to > from) out.push({ start: from, end: to, role }); };

    while (i < n) {
      if (state > 0) {
        const b = lang.blocks[state - 1];
        const e = find(b.close, i, b.role === 'string');
        if (e >= 0) { add(i, e + b.close.length, b.role); i = e + b.close.length; state = 0; } else { add(i, n, b.role); i = n; }
        continue;
      }
      const bi = lang.blocks.findIndex((b) => line.startsWith(b.open, i));
      if (bi >= 0) {
        const b = lang.blocks[bi];
        const from = i;
        i += b.open.length;
        const e = find(b.close, i, b.role === 'string');
        if (e >= 0) { i = e + b.close.length; add(from, i, b.role); } else { add(from, n, b.role); i = n; state = bi + 1; }
        continue;
      }
      if (lang.lineComments.some((c) => line.startsWith(c, i))) { add(i, n, 'comment'); break; }
      if (lang.quotes.includes(line[i])) {
        const q = line[i];
        let j = i + 1;
        while (j < n && line[j] !== q) j += line[j] === '\\' ? 2 : 1;
        const end = Math.min(j + 1, n);
        add(i, end, 'string');
        i = end;
        continue;
      }
      i++;
    }
    return { spans: out, next: state };
  }

  const MAX_LENGTH = 2000;

  const hasHighlighting = (type) => !!RULES[type] || !!CODE[type];

  /** Scanner state at the start of every line (0 = nothing open); empty for formats without carried state. */
  function states(lines, type) {
    const lang = CODE[type];
    if (!lang) return [];
    const out = [];
    let state = 0;
    for (const line of lines) {
      out.push(state);
      state = scan(line, lang, state).next;
    }
    return out;
  }

  /** Settings: highlighting can be switched off altogether or per language. */
  const isOn = (type) => typeof Prefs === 'undefined'
    || (Prefs.values.syntaxOn !== false && !(Prefs.values.syntaxOff || []).includes(type));

  /** Returns [{start, end, role}] for a single line. A character claimed by an earlier rule is never recolored. */
  function spans(line, type, state = 0) {
    if (!isOn(type)) return [];
    const lang = CODE[type];
    const rules = lang ? lang.rules : RULES[type];
    if (!rules || !line || line.length > MAX_LENGTH) return [];
    const claimed = new Array(line.length).fill(false);
    const out = [];
    if (lang) {
      for (const s of scan(line, lang, state).spans) {
        out.push(s);
        for (let k = s.start; k < s.end; k++) claimed[k] = true;
      }
    }
    for (const { re, role } of rules) {
      re.lastIndex = 0;
      for (const m of line.matchAll(re)) {
        if (!m[0].length) continue;
        const end = m.index + m[0].length;
        let runStart = -1;
        for (let i = m.index; i <= end; i++) {
          const free = i < end && !claimed[i];
          if (free && runStart < 0) runStart = i;
          if (!free && runStart >= 0) {
            out.push({ start: runStart, end: i, role });
            for (let k = runStart; k < i; k++) claimed[k] = true;
            runStart = -1;
          }
        }
      }
    }
    return out.sort((a, b) => a.start - b.start);
  }

  /** Fills `parent` with the line's text, colored with `tok-*` classes. */
  function render(line, type, parent, state = 0) {
    const list = spans(line, type, state);
    let pos = 0;
    for (const s of list) {
      if (s.start > pos) parent.appendChild(document.createTextNode(line.slice(pos, s.start)));
      const span = document.createElement('span');
      span.className = 'tok-' + s.role;
      span.textContent = line.slice(s.start, s.end);
      parent.appendChild(span);
      pos = s.end;
    }
    if (pos < line.length) parent.appendChild(document.createTextNode(line.slice(pos)));
    return parent;
  }

  /** A multi-line code block (Markdown fence) as colored rows joined by newlines. */
  function renderBlock(code, type, parent) {
    const lines = code.split('\n');
    const st = states(lines, type);
    lines.forEach((line, i) => {
      if (i > 0) parent.appendChild(document.createTextNode('\n'));
      render(line, type, parent, st.length ? st[i] : 0);
    });
    return parent;
  }

  return { hasHighlighting, isOn, render, renderBlock, states, spans };
})();

// ---- Search ----------------------------------------------------------------

const Searcher = (() => {
  /** Non-overlapping hits as [start, end) pairs, with the options of the Find bar (case, whole word, regular expression). */
  function ranges(query, text) {
    return TextSearch.matches(query, text, TextSearch.options).map((m) => [m.start, m.end]);
  }

  /** Markdown reading mode is searched per rendered block; every other view per line. */
  const usesBlocks = (doc, mode) => mode === 'reading' && doc.type === 'markdown';

  /** Visible text pieces of a block, in the order the reading view draws them. */
  function segments(block) {
    switch (block.type) {
      case 'heading': case 'paragraph': case 'quote': return [plain(block.text)];
      case 'bullets': case 'numbered': return block.items.map(plain);
      case 'code': return [block.code];
      case 'rule': return [];
      case 'table': return [...block.header, ...block.rows.flat()].map(plain);
    }
    return [];
  }

  /** Number of hits before each segment, so a segment knows its first occurrence index. */
  function offsets(block, query) {
    let running = 0;
    return segments(block).map((text) => {
      const before = running;
      running += ranges(query, text).length;
      return before;
    });
  }

  /** Hits in the text being edited: one unit per line (a hit that spans lines belongs to the line it starts in). */
  function matchesInText(query, text) {
    return TextSearch.locate(query, text, TextSearch.options).map((h) => ({ unit: h.unit, occurrence: h.occurrence }));
  }

  /**
   * File and folder names: every word typed has to be the beginning of the name or of one of its words,
   * so "гриз", "read me" and "me" all find "Read Me.md".
   */
  function nameMatches(name, query) {
    const typed = String(query).toLowerCase().split(/\s+/).filter(Boolean);
    if (!typed.length) return true;
    const low = String(name).toLowerCase();
    const words = low.split(/[^\p{L}\p{N}]+/u).filter(Boolean);
    return typed.every((q) => low.startsWith(q) || words.some((w) => w.startsWith(q)));
  }

  function matches(query, doc, mode) {
    if (!query) return [];
    const result = [];
    const collect = (unit, texts) => {
      let occurrence = 0;
      for (const text of texts) {
        for (let k = ranges(query, text).length; k > 0; k--) result.push({ unit, occurrence: occurrence++ });
      }
    };
    if (usesBlocks(doc, mode)) doc.blocks.forEach((b, i) => collect(i, segments(b)));
    else doc.lines.forEach((l, i) => collect(i, [l]));
    return result;
  }

  /**
   * Wraps the hits inside `el` in <mark>. `offset` is the index of the element's first hit within its unit;
   * the hit equal to `highlight.current` gets the "current" class.
   */
  function paint(el, highlight, unit, offset) {
    if (!highlight || !highlight.query) return;
        const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
    const nodes = [];
    let text = '';
    for (let n = walker.nextNode(); n; n = walker.nextNode()) {
      nodes.push({ node: n, start: text.length });
      text += n.nodeValue;
    }
    const found = ranges(highlight.query, text);
    const cur = highlight.current;
    for (let k = found.length - 1; k >= 0; k--) {
      const [from, to] = found[k];
      const isCurrent = !!cur && cur.unit === unit && cur.occurrence === offset + k;
      for (let j = nodes.length - 1; j >= 0; j--) {
        const { node, start } = nodes[j];
        const len = node.nodeValue.length;
        const a = Math.max(from - start, 0);
        const b = Math.min(to - start, len);
        if (a >= b || start >= to || start + len <= from) continue;
        const mid = node.splitText(a);
        mid.splitText(b - a);
        const mark = document.createElement('mark');
        if (isCurrent) mark.className = 'current';
        mid.parentNode.insertBefore(mark, mid);
        mark.appendChild(mid);
      }
    }
  }

  return { ranges, matches, matchesInText, nameMatches, offsets, usesBlocks, paint };
})();

// ---- Line endings ----------------------------------------------------------

/** The line endings of a file as they were read, so that saving does not rewrite them.
 *  The editor works with "\n" only; `apply` turns the text back into what the file used. */
const LineEndings = (() => {
  const LF = { dominant: '\n', sequence: null };

  /** Splits "\r\n", "\r" and "\n"; returns the text with "\n" only and the endings found. */
  function parse(text) {
    if (!text.includes('\r')) return { normalized: text, endings: LF };
    const seq = [];
    const counts = new Map();
    const note = (e) => { seq.push(e); counts.set(e, (counts.get(e) || 0) + 1); };
    let out = '';
    let from = 0;
    for (let i = 0; i < text.length; i++) {
      const c = text[i];
      if (c === '\n') { out += text.slice(from, i) + '\n'; from = i + 1; note('\n'); }
      else if (c === '\r') {
        out += text.slice(from, i) + '\n';
        if (text[i + 1] === '\n') { i++; note('\r\n'); } else note('\r');
        from = i + 1;
      }
    }
    out += text.slice(from);
    let dominant = '\n';
    let best = -1;
    for (const [e, n] of counts) if (n > best) { best = n; dominant = e; }
    return { normalized: out, endings: { dominant, sequence: counts.size > 1 ? seq : null } };
  }

  /** The n-th line break gets the n-th recorded ending; breaks added by editing use the dominant one. */
  function apply(text, endings) {
    if (!endings || (!endings.sequence && endings.dominant === '\n')) return text;
    let n = 0;
    return text.replace(/\n/g, () => {
      const e = endings.sequence && n < endings.sequence.length ? endings.sequence[n] : endings.dominant;
      n++;
      return e;
    });
  }

  return { parse, apply };
})();

// ---- Text search and replace -----------------------------------------------

/** Search with options (case, whole word, regular expression); the Find bar sets `TextSearch.options`. */
const TextSearch = (() => {
  const options = { caseSensitive: false, wholeWord: false, regex: false };
  const escape = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

  function expression(query, o) {
    let src = o.regex ? query : escape(query);
    if (o.wholeWord) src = '(?<![\\p{L}\\p{N}_])(?:' + src + ')(?![\\p{L}\\p{N}_])';
    try { return new RegExp(src, 'gum' + (o.caseSensitive ? '' : 'i')); } catch { return null; }
  }

  /** False when a regular expression is typed but cannot be compiled (the bar shows it in red). */
  function isValid(query, o = options) {
    if (!o.regex || !query) return true;
    try { new RegExp(query, 'u'); return true; } catch { return false; }
  }

  /** Hits as {start, end, m}; `m` is the regular expression match (null for a plain search). */
  function matches(query, text, o = options) {
    if (!query) return [];
    const out = [];
    if (o.regex || o.wholeWord || o.caseSensitive) {
      const re = expression(query, o);
      if (!re) return out;
      for (const m of text.matchAll(re)) {
        // An empty match (for example `x*`) cannot be highlighted or replaced meaningfully.
        if (m[0].length) out.push({ start: m.index, end: m.index + m[0].length, m });
      }
      return out;
    }
    const q = query.toLowerCase();
    const t = text.toLowerCase();
    let from = 0;
    while (from < t.length) {
      const i = t.indexOf(q, from);
      if (i < 0) break;
      out.push({ start: i, end: i + q.length, m: null });
      from = i + Math.max(q.length, 1);
    }
    return out;
  }

  /** Hits in a whole text: `unit` is the line the hit starts in, `occurrence` counts the hits that start in that line. */
  function locate(query, text, o = options) {
    const found = matches(query, text, o);
    const out = [];
    let line = 0;
    let occurrence = 0;
    let scanned = 0;
    for (const { start, end } of found) {
      for (let i = scanned; i < start; i++) if (text.charCodeAt(i) === 10) { line++; occurrence = 0; }
      scanned = start;
      out.push({ unit: line, occurrence: occurrence++, start, end });
    }
    return out;
  }

  /** `$1`, `$&`, `$$`, `$<name>` and `\n` `\t` `\\` in a replacement made for a regular expression. */
  function expand(template, m) {
    return template.replace(/\$(\$|&|\d{1,2}|<[^>]+>)|\\(n|t|\\)/g, (all, d, e) => {
      if (e) return e === 'n' ? '\n' : e === 't' ? '\t' : '\\';
      if (d === '$') return '$';
      if (d === '&') return m[0];
      if (d[0] === '<') return (m.groups && m.groups[d.slice(1, -1)]) || '';
      return m[Number(d)] || '';
    });
  }

  /** The edits that replace hits with `template`; with `only`, just the n-th hit. Ascending, never overlapping. */
  function edits(query, template, text, o = options, only = null) {
    const found = matches(query, text, o);
    const chosen = only === null ? found : (found[only] ? [found[only]] : []);
    return chosen.map((h) => ({ start: h.start, end: h.end, text: o.regex && h.m ? expand(template, h.m) : template }));
  }

  function apply(list, text) {
    let out = text;
    for (let i = list.length - 1; i >= 0; i--) out = out.slice(0, list[i].start) + list[i].text + out.slice(list[i].end);
    return out;
  }

  return { options, isValid, matches, locate, edits, apply };
})();

// ---- Outline ---------------------------------------------------------------

/** A table of contents for any file type: Markdown headings, TeX and INI sections, HTML headings,
 *  and the declarations (classes, functions) of source code. Items are {line, level, title}; line is 0-based. */
const Outline = (() => {
  const R = {
    python: /^(\s*)(?:async\s+)?(def|class)\s+(\w+)/,
    swift: /^(\s*)(?:(?:public|private|fileprivate|internal|open|final|static|class|override|mutating|indirect)\s+)*(func|class|struct|enum|protocol|extension|actor|init)\b\s*([\w<>.]*)/,
    js: /^(\s*)(?:export\s+)?(?:default\s+)?(?:async\s+)?(function\*?|class|interface|enum|type)\s+(\w+)/,
    jsConst: /^(\s*)(?:export\s+)?(?:const|let|var)\s+(\w+)\s*=\s*(?:async\s*)?(?:\([^)]*\)|\w+)\s*=>/,
    php: /^(\s*)(?:(?:public|private|protected|static|final|abstract)\s+)*(function|class|interface|trait|enum)\s+&?(\w+)/,
    csharp: /^(\s*)(?:(?:public|private|protected|internal|static|abstract|sealed|override|virtual|async|partial|readonly)\s+)*(class|struct|interface|enum|record|namespace)\s+([\w.]+)/,
    csMethod: /^(\s*)(?:(?:public|private|protected|internal|static|abstract|override|virtual|async|partial)\s+)+[\w<>[\],.?]+\s+(\w+)\s*\([^;]*$/,
    java: /^(\s*)(?:(?:public|private|protected|static|final|abstract|synchronized|default)\s+)*(class|interface|enum|record)\s+(\w+)/,
    javaMethod: /^(\s*)(?:(?:public|private|protected|static|final|abstract|synchronized)\s+)+[\w<>[\],.?]+\s+(\w+)\s*\([^;]*$/,
    cFunc: /^()[A-Za-z_][\w\s*&:<>,~]*?[\s*&]([A-Za-z_~][\w:~]*)\s*\([^;]*$/,
    cType: /^(\s*)(?:typedef\s+)?(class|struct|enum|namespace)\s+(\w+)/,
    go: /^()(func|type)\s+(?:\([^)]*\)\s*)?(\w+)/,
    rust: /^(\s*)(?:pub(?:\([^)]*\))?\s+)?(?:async\s+)?(?:unsafe\s+)?(fn|struct|enum|trait|impl|mod)\s+(\w+)/,
    kotlin: /^(\s*)(?:(?:public|private|protected|internal|open|abstract|override|suspend|data|sealed|inline)\s+)*(fun|class|object|interface)\s+(?:<[^>]*>\s*)?([\w.]+)/,
    sql: /^()\s*create\s+(?:or\s+replace\s+)?(table|view|function|procedure|index|trigger)\s+(?:if\s+not\s+exists\s+)?([\w."]+)/i,
    shell: /^()(?:function\s+)?(\w[\w-]*)\s*\(\)\s*\{?/,
    ruby: /^(\s*)(def|class|module)\s+([\w.:]+)/,
    css: /^([^\s@/}][^{;]*?)\s*\{\s*$/,
    cssAt: /^(@(?:media|keyframes|font-face|supports)[^{]*)\{/,
    yaml: /^([A-Za-z_][\w .-]*):(?:\s|$)/,
    ini: /^\s*\[+([^\]]+)\]+/,
    tex: /\\(chapter|section|subsection|subsubsection|part)\*?\{([^}]*)\}/,
    html: /<h([1-6])[^>]*>(.*?)<\/h[1-6]>/,
  };
  const CONTROL = new Set(['if', 'for', 'while', 'switch', 'return', 'sizeof']);
  const declaration = { python: R.python, ruby: R.ruby, swift: R.swift, php: R.php, go: R.go, rust: R.rust, kotlin: R.kotlin, java: R.java, csharp: R.csharp };

  function items(text, type) {
    const out = [];
    let inFence = false;
    const lines = text.split('\n');
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      if (line.length >= 400) continue;
      const indent = (m) => Math.min(4, Math.floor(m[1].length / 4) + 1);
      let m;
      if (type === 'markdown') {
        const t = line.trim();
        if (t.startsWith('```') || t.startsWith('~~~')) { inFence = !inFence; continue; }
        if (inFence || !t.startsWith('#')) continue;
        const level = t.match(/^#+/)[0].length;
        if (level > 6 || t[level] !== ' ') continue;
        const title = t.slice(level).trim();
        if (title) out.push({ line: i, level, title });
      } else if (type === 'tex') {
        if ((m = R.tex.exec(line))) out.push({ line: i, level: { part: 1, chapter: 1, section: 2, subsection: 3, subsubsection: 4 }[m[1]] || 2, title: m[2] });
      } else if (type === 'config') {
        if ((m = R.ini.exec(line))) out.push({ line: i, level: 1, title: m[1] });
      } else if (type === 'yaml') {
        if ((m = R.yaml.exec(line))) out.push({ line: i, level: 1, title: m[1] });
      } else if (type === 'html') {
        if ((m = R.html.exec(line))) out.push({ line: i, level: Number(m[1]), title: m[2].replace(/<[^>]+>/g, '') });
      } else if (type === 'css') {
        if ((m = R.cssAt.exec(line))) out.push({ line: i, level: 1, title: m[1].trim() });
        else if ((m = R.css.exec(line))) out.push({ line: i, level: 1, title: m[1] });
      } else if (declaration[type]) {
        if ((m = declaration[type].exec(line))) out.push({ line: i, level: indent(m), title: m[3] ? `${m[2]} ${m[3]}` : m[2] });
        else if (type === 'java' && (m = R.javaMethod.exec(line))) out.push({ line: i, level: indent(m) + 1, title: m[2] + '()' });
        else if (type === 'csharp' && (m = R.csMethod.exec(line))) out.push({ line: i, level: indent(m) + 1, title: m[2] + '()' });
      } else if (type === 'javascript' || type === 'typescript') {
        if ((m = R.js.exec(line))) out.push({ line: i, level: indent(m), title: `${m[2]} ${m[3]}` });
        else if ((m = R.jsConst.exec(line))) out.push({ line: i, level: indent(m), title: m[2] + '()' });
      } else if (type === 'cpp') {
        if ((m = R.cType.exec(line))) out.push({ line: i, level: indent(m), title: `${m[2]} ${m[3]}` });
        else if (!/^[ \t#]/.test(line) && !line.startsWith('//') && (m = R.cFunc.exec(line)) && !CONTROL.has(m[2])) out.push({ line: i, level: 1, title: m[2] + '()' });
      } else if (type === 'sql') {
        if ((m = R.sql.exec(line))) out.push({ line: i, level: 1, title: `${m[2].toLowerCase()} ${m[3]}` });
      } else if (type === 'shell') {
        if ((m = R.shell.exec(line))) out.push({ line: i, level: 1, title: m[2] + '()' });
      }
    }
    return out;
  }

  return { items };
})();

// ---- Diff and three-way merge ----------------------------------------------

/** Line diff and three-way merge, used when a file changes on disk while it has unsaved edits. */
const LineDiff = (() => {
  /** Rows {op: 'equal' | 'insert' | 'delete', text}. The common beginning and end are cut off first; a changed middle
   *  too large for the table is reported as one block of deletions followed by one of insertions. */
  function diff(a, b) {
    let lo = 0;
    while (lo < a.length && lo < b.length && a[lo] === b[lo]) lo++;
    let ea = a.length;
    let eb = b.length;
    while (ea > lo && eb > lo && a[ea - 1] === b[eb - 1]) { ea--; eb--; }
    const rows = a.slice(0, lo).map((text) => ({ op: 'equal', text }));
    const x = a.slice(lo, ea);
    const y = b.slice(lo, eb);
    if (!x.length || !y.length || x.length * y.length > 4_000_000) {
      for (const text of x) rows.push({ op: 'delete', text });
      for (const text of y) rows.push({ op: 'insert', text });
    } else {
      const w = y.length + 1;
      const lcs = new Int32Array((x.length + 1) * w);
      for (let i = x.length - 1; i >= 0; i--) {
        for (let j = y.length - 1; j >= 0; j--) {
          lcs[i * w + j] = x[i] === y[j] ? lcs[(i + 1) * w + j + 1] + 1 : Math.max(lcs[(i + 1) * w + j], lcs[i * w + j + 1]);
        }
      }
      let i = 0;
      let j = 0;
      while (i < x.length || j < y.length) {
        if (i < x.length && j < y.length && x[i] === y[j]) { rows.push({ op: 'equal', text: x[i] }); i++; j++; }
        else if (j < y.length && (i === x.length || lcs[i * w + j + 1] >= lcs[(i + 1) * w + j])) { rows.push({ op: 'insert', text: y[j] }); j++; }
        else { rows.push({ op: 'delete', text: x[i] }); i++; }
      }
    }
    for (let k = ea; k < a.length; k++) rows.push({ op: 'equal', text: a[k] });
    return rows;
  }

  /** The changed stretches of the base: lines start..end of the base became `lines`. */
  function hunks(base, other) {
    const result = [];
    let pos = 0;
    let cur = null;
    for (const row of diff(base, other)) {
      if (row.op === 'equal') { if (cur) { result.push(cur); cur = null; } pos++; }
      else if (row.op === 'delete') { cur = cur || { start: pos, end: pos, lines: [] }; cur.end++; pos++; }
      else { cur = cur || { start: pos, end: pos, lines: [] }; cur.lines.push(row.text); }
    }
    if (cur) result.push(cur);
    return result;
  }

  function applyHunks(hs, base, s, e) {
    const out = [];
    let pos = s;
    for (const h of hs) { out.push(...base.slice(pos, h.start), ...h.lines); pos = h.end; }
    out.push(...base.slice(pos, e));
    return out;
  }

  const same = (a, b) => a.length === b.length && a.every((v, i) => v === b[i]);

  /** `base` is the text the edits started from, `mine` the unsaved text, `theirs` what is on disk now. Changes that do not
   *  touch the same lines are combined; the rest is marked like git does (<<<<<<<, =======, >>>>>>>). */
  function merge(base, mine, theirs) {
    const mh = hunks(base, mine);
    const th = hunks(base, theirs);
    const overlaps = (a, b) => (a.start < b.end && b.start < a.end) || a.start === b.start;
    const out = [];
    let conflicts = 0;
    let i = 0;
    let j = 0;
    let pos = 0;
    while (i < mh.length || j < th.length) {
      const useMine = j >= th.length || (i < mh.length && mh[i].start <= th[j].start);
      const a = useMine ? mh[i] : th[j];
      const clash = useMine ? (j < th.length && overlaps(a, th[j])) : (i < mh.length && overlaps(a, mh[i]));
      out.push(...base.slice(pos, a.start));
      if (!clash) {
        out.push(...a.lines);
        pos = a.end;
        if (useMine) i++; else j++;
        continue;
      }
      const s = a.start;
      let e = a.end;
      let mi = i;
      let ti = j;
      for (let grew = true; grew;) {
        grew = false;
        while (mi < mh.length && (mh[mi].start < e || mh[mi].start === s)) { e = Math.max(e, mh[mi].end); mi++; grew = true; }
        while (ti < th.length && (th[ti].start < e || th[ti].start === s)) { e = Math.max(e, th[ti].end); ti++; grew = true; }
      }
      const m = applyHunks(mh.slice(i, mi), base, s, e);
      const t = applyHunks(th.slice(j, ti), base, s, e);
      if (same(m, t)) out.push(...m);
      else { conflicts++; out.push('<<<<<<< mine', ...m, '=======', ...t, '>>>>>>> disk'); }
      pos = e;
      i = mi;
      j = ti;
    }
    out.push(...base.slice(pos));
    return { lines: out, conflicts, text: out.join('\n') };
  }

  return { diff, merge };
})();
