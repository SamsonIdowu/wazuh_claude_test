#!/usr/bin/env python3
"""Check a Wazuh draft against the house writing rules before it goes to review.

Usage:
  stylecheck.py <file.md|.rst|.txt|.html|.json> [--stage=draft|final] [--type=blog|doc]
                [--wazuh=auto|4|5] [--allow=RULE,RULE] [--json]

Input is a markdown or RST draft, or a Google Docs HTML export (raw .html, or the JSON that
download_file_content writes, with base64 `content`). Errors exit 1; warnings never block.
Rules come from test/Language and formatting style guide for technical writing _ Wazuh.md
and from the open lessons in learning/lessons/. The rule table is in SKILL.md.
"""
import base64, html, json, os, re, sys
from html.parser import HTMLParser

HERE = os.path.dirname(os.path.abspath(__file__))
ERROR, WARN = 'error', 'warning'

# ---------------------------------------------------------------- word lists
def _load(name):
    path = os.path.join(HERE, name)
    if not os.path.exists(path):
        return []
    with open(path, encoding='utf-8') as f:
        return [l.strip() for l in f if l.strip() and not l.startswith('#')]

PROPER = _load('proper-nouns.txt')
FAMILIAR = set(_load('familiar-acronyms.txt'))
SHELL_LANGS = {'bash', 'sh', 'shell', 'console', 'zsh', 'powershell', 'ps1', 'pwsh', 'cmd', 'bat', 'text', ''}
XML_LANGS = {'xml', 'html'}
INVISIBLE = {' ': 'non-breaking space', '​': 'zero-width space', '‌': 'zero-width non-joiner',
             '‍': 'zero-width joiner', '⁠': 'word joiner', '﻿': 'byte order mark',
             '­': 'soft hyphen'}
CURLY = '‘’“”'
CAPS_WORDS = {'i', 'ok', 'a', 'no', 'not', 'only', 'all', 'any', 'and', 'or', 'never', 'must', 'one', 'two',
              'three', 'four', 'five', 'yes', 'do', 'dont', 'the', 'new', 'now', 'off', 'on', 'out', 'is', 'are',
              'every', 'before', 'after', 'first', 'last', 'none', 'both', 'each', 'real', 'this', 'that'}
GERUND_OK = {'during', 'nothing', 'something', 'anything', 'everything', 'string', 'bring', 'thing',
             'king', 'ring', 'spring', 'sibling', 'ceiling', 'morning', 'evening', 'pending', 'wing'}

# ---------------------------------------------------------------- document model
class Block:
    """One unit of the draft. kind: title | heading | prose | li | oli | table | code | comment."""
    def __init__(self, line, kind, text, level=0, lang='', raw=None, code_spans=None):
        self.line, self.kind, self.text, self.level, self.lang = line, kind, text, level, lang
        self.raw = raw if raw is not None else text      # unmasked text, for the character rules
        self.code_spans = code_spans or []                # inline code, for the character rules
        self.section = ''

INLINE_CODE = re.compile(r'(`+)(.+?)\1')
MD_LINK = re.compile(r'!?\[([^\]]*)\]\(([^)\s]+)(?:\s+"[^"]*")?\)')
BARE_URL = re.compile(r'https?://\S+')

def mask_md(text):
    """Return (masked prose, inline code spans). Code becomes `codespan`, URLs `urlref`."""
    spans = [m.group(2) for m in INLINE_CODE.finditer(text)]
    t = INLINE_CODE.sub('codespan', text)
    t = MD_LINK.sub(lambda m: m.group(1) or 'urlref', t)
    t = BARE_URL.sub('urlref', t)
    t = re.sub(r'<!--.*?-->', '', t)
    t = t.replace('**', '').replace('__', '')
    # a word in italics or quotes is being mentioned, not used (the guide's convention)
    t = re.sub(r'(?<![\w*])\*(?!\s)([^*]+?)\*(?!\w)', 'mention', t)
    t = re.sub(r'(?<![\w])_(?!\s)([^_]+?)_(?!\w)', 'mention', t)
    t = re.sub(r'"[^"\n]{1,80}"|\u201c[^\u201d]{1,80}\u201d', 'mention', t)
    return t, spans

def parse_md(src):
    blocks, lines = [], src.split('\n')
    i, para, para_start = 0, [], 0
    fence = None

    def flush():
        nonlocal para
        if para:
            raw = ' '.join(s.strip() for s in para)
            t, spans = mask_md(raw)
            blocks.append(Block(para_start, 'prose', t, raw=raw, code_spans=spans))
            para = []

    while i < len(lines):
        line = lines[i]
        m = re.match(r'^(\s*)(`{3,}|~{3,})\s*([\w+-]*)\s*(.*)$', line)
        if m:
            flush()
            indent, mark, lang, extra = m.groups()
            body, j = [], i + 1
            close = re.compile(r'^\s*' + re.escape(mark[0]) + '{' + str(len(mark)) + r',}\s*$')
            while j < len(lines) and not close.match(lines[j]):
                body.append(lines[j][len(indent):] if lines[j].startswith(indent) else lines[j])
                j += 1
            b = Block(i + 1, 'code', '\n'.join(body), lang=lang.lower())
            b.info = extra.lower()
            if j >= len(lines):
                b.unclosed = True
            blocks.append(b)
            i = j + 1
            continue
        if '<!--' in line:
            flush()
            start, chunk = i, line
            while '-->' not in chunk and i + 1 < len(lines):
                i += 1
                chunk += '\n' + lines[i]
            blocks.append(Block(start + 1, 'comment', chunk))
            rest = chunk.split('-->', 1)[1].strip() if '-->' in chunk else ''
            before = chunk.split('<!--', 1)[0].strip()
            for piece in (before, rest):
                if piece:
                    t, spans = mask_md(piece)
                    blocks.append(Block(start + 1, 'prose', t, raw=piece, code_spans=spans))
            i += 1
            continue
        h = re.match(r'^(#{1,6})\s+(.*?)\s*#*\s*$', line)
        if h:
            flush()
            t, spans = mask_md(h.group(2))
            blocks.append(Block(i + 1, 'heading', t, level=len(h.group(1)), raw=h.group(2), code_spans=spans))
            i += 1
            continue
        li = re.match(r'^(\s*)([-*+]|\d+[.)]|#\.)\s+(.*)$', line)
        if li:
            flush()
            item, j = [li.group(3)], i + 1
            while j < len(lines) and lines[j].strip() and not re.match(r'^\s*([-*+]|\d+[.)]|#\.)\s+|^\s*(`{3,}|~{3,})|^#', lines[j]):
                item.append(lines[j].strip())
                j += 1
            raw = ' '.join(item)
            t, spans = mask_md(raw)
            kind = 'li' if li.group(2) in '-*+' else 'oli'
            b = Block(i + 1, kind, t, level=len(li.group(1)), raw=raw, code_spans=spans)
            blocks.append(b)
            i = j
            continue
        if line.lstrip().startswith('|'):
            flush()
            cells = [c.strip() for c in line.strip().strip('|').split('|')]
            if not all(re.fullmatch(r':?-{2,}:?', c) for c in cells if c):
                raw = ' | '.join(cells)
                t, spans = mask_md(raw)
                blocks.append(Block(i + 1, 'table', t, raw=raw, code_spans=spans))
            i += 1
            continue
        if not line.strip():
            flush()
        else:
            if not para:
                para_start = i + 1
            para.append(line)
        i += 1
    flush()
    return blocks

RST_UNDER = re.compile(r'^([=\-~^"#*+`:.\'_])\1{2,}\s*$')

def parse_rst(src):
    """Enough RST for a style pass: headings, code-block directives, prose, bullets."""
    lines = src.split('\n')
    out, order, i = [], [], 0
    md_like = []
    while i < len(lines):
        line = lines[i]
        nxt = lines[i + 1] if i + 1 < len(lines) else ''
        if line.strip() and RST_UNDER.match(nxt) and len(nxt.strip()) >= len(line.strip()) - 1:
            ch = nxt.strip()[0]
            if ch not in order:
                order.append(ch)
            md_like.append('#' * min(order.index(ch) + 1, 6) + ' ' + line.strip())
            i += 2
            continue
        d = re.match(r'^(\s*)\.\.\s+code-block::\s*(\w*)', line)
        if d:
            base, lang, body, j = len(d.group(1)), d.group(2), [], i + 1
            while j < len(lines) and (not lines[j].strip() or len(lines[j]) - len(lines[j].lstrip()) > base):
                body.append(lines[j])
                j += 1
            while body and not body[-1].strip():
                body.pop()
            while body and not body[0].strip():
                body.pop(0)
            ind = min((len(b) - len(b.lstrip()) for b in body if b.strip()), default=0)
            md_like += ['```' + lang] + [b[ind:] for b in body] + ['```']
            i = j
            continue
        if re.match(r'^\s*\.\.\s+\w[\w-]*::', line):   # other directives: keep their body as prose
            i += 1
            continue
        md_like.append(re.sub(r'``(.+?)``', r'`\1`', line))
        i += 1
    return parse_md('\n'.join(md_like))

MONO = re.compile(r'font-family:\s*["\']?(courier new|consolas|roboto mono|source code pro|monospace)', re.I)

class _DocsHTML(HTMLParser):
    """Walk a Google Docs HTML export into Blocks. Code is recognised by its font, the only
    signal the export keeps; a run of monospace paragraphs is one code block."""
    BLOCKS = {'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li'}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.classes, self.in_style, self.css = {}, False, ''
        self.stack, self.cur, self.items = [], None, []
        self.depth_td, self.skip = 0, 0
        self.list_tags = []

    def _style(self, attrs):
        a = dict(attrs)
        s = a.get('style') or ''
        for c in (a.get('class') or '').split():
            s += ';' + self.classes.get(c, '')
        return a, s

    def handle_starttag(self, tag, attrs):
        if tag == 'style':
            self.in_style = True
            return
        a, style = self._style(attrs)
        if tag in ('ol', 'ul'):
            self.list_tags.append(tag)
        if tag == 'td':
            self.depth_td += 1
            self.items.append(('cellstart', None))
        aid = a.get('id') or ''
        if tag == 'a' and aid.startswith('cmnt') and not aid.startswith('cmnt_ref') and self.cur is not None:
            self.cur['comment'] = True   # a reviewer comment body at the end of the export
        if tag == 'sup' or (tag == 'a' and aid.startswith('cmnt')):
            self.skip += 1
        mono = bool(MONO.search(style))
        parent_mono = self.stack[-1][1] if self.stack else False
        self.stack.append((tag, mono or (parent_mono and tag not in self.BLOCKS)))
        if tag in self.BLOCKS:
            cls = (a.get('class') or '').split()
            kind = 'title' if 'title' in cls else ('heading' if tag[0] == 'h' else
                   ('oli' if tag == 'li' and self.list_tags and self.list_tags[-1] == 'ol' else
                    'li' if tag == 'li' else 'prose'))
            self.cur = {'kind': kind, 'level': int(tag[1]) if tag[0] == 'h' else 0,
                        'segs': [], 'in_td': self.depth_td > 0, 'bold': 'font-weight:700' in style}

    def handle_endtag(self, tag):
        if tag == 'style':
            self.in_style = False
            for sel, body in re.findall(r'\.([\w-]+)\s*\{([^}]*)\}', self.css):
                self.classes[sel] = self.classes.get(sel, '') + ';' + body
            return
        if tag in ('ol', 'ul') and self.list_tags:
            self.list_tags.pop()
        if tag == 'td':
            self.depth_td -= 1
            self.items.append(('cellend', None))
        if (tag == 'sup' or tag == 'a') and self.skip:
            self.skip -= 1
        while self.stack:
            t, _ = self.stack.pop()
            if t == tag:
                break
        if tag in self.BLOCKS and self.cur is not None:
            self.items.append(('block', self.cur))
            self.cur = None

    def handle_data(self, data):
        if self.in_style:
            self.css += data
            return
        if self.skip or self.cur is None:
            return
        mono = self.stack[-1][1] if self.stack else False
        self.cur['segs'].append((data, mono))

def parse_html(src):
    p = _DocsHTML()
    p.feed(src)
    blocks, code, code_line, n = [], [], 0, 0

    def flush_code():
        nonlocal code
        if code:
            blocks.append(Block(code_line, 'code', '\n'.join(code), lang=''))
            code = []

    for kind, item in p.items:
        if kind != 'block':
            flush_code()
            continue
        n += 1
        segs = item['segs']
        text = ''.join(s for s, _ in segs)
        if item.get('comment'):
            continue
        visible = [(s, m) for s, m in segs if s.strip()]
        lone_path = not item['in_td'] and re.fullmatch(r'\s*[\w./\\:~-]*[/\\.][\w./\\:~-]*:?\s*', text)
        if visible and all(m for _, m in visible) and item['kind'] in ('prose', 'li') and not lone_path:
            if not code:
                code_line = n
            code.append(text.replace(' ', ' '))
            continue
        flush_code()
        if not text.strip():
            continue
        spans = [s for s, m in segs if m and s.strip()]
        masked = ''.join('codespan' if m and s.strip() else s for s, m in segs)
        masked = BARE_URL.sub('urlref', masked)
        b = Block(n, item['kind'], masked.strip(), level=item['level'], raw=text.strip(), code_spans=spans)
        b.in_td = item['in_td']
        blocks.append(b)
    flush_code()
    return blocks

def load(path):
    with open(path, encoding='utf-8-sig' if not path.endswith('.json') else 'utf-8') as f:
        src = f.read()
    if path.endswith('.json'):
        src = base64.b64decode(json.loads(src)['content']).decode('utf-8')
        return parse_html(src), 'html', src
    src = src.replace('\r\n', '\n')
    if path.endswith(('.html', '.htm')):
        return parse_html(src), 'html', src
    if path.endswith('.rst'):
        return parse_rst(src), 'rst', src
    return parse_md(src), 'md', src

# ---------------------------------------------------------------- rules
class Report:
    def __init__(self, allow):
        self.findings, self.allow = [], allow

    def add(self, rule, sev, block, msg, snippet=''):
        if rule in self.allow and sev == ERROR:
            sev, msg = WARN, msg + ' (allowed by --allow)'
        self.findings.append({'rule': rule, 'severity': sev, 'line': block.line if block else 0,
                              'section': block.section if block else '', 'message': msg,
                              'snippet': snippet.replace('codespan', '`…`').replace('urlref', '<url>').replace('mention', '"…"')[:90]})

def sentences(text):
    return [s for s in re.split(r'(?<=[.!?])\s+(?=[A-Z("\'`“])', text) if s.strip()]

def words(s):
    return re.findall(r"[A-Za-z0-9][\w'’./-]*", s)

def heading_case(text):
    """Return the capitalised words that are neither proper nouns nor acronyms."""
    t = re.sub(r'^\s*(\d+[a-z]?|[A-Z]|[ivx]+)[.)]\s+', '', text)   # a numbered heading: 2a. The config
    for pn in sorted(PROPER, key=len, reverse=True):
        t = re.sub(r'(?<![\w-])' + re.escape(pn) + r'(?![\w-])', ' ', t)
    bad, prev = [], ''
    toks = re.findall(r"[\w'’&.-]+|[:—?!]", t)
    for k, w in enumerate(toks):
        if k == 0 or prev in (':', '—', '?', '!'):
            prev = w
            continue
        prev = w
        if not w[0].isupper() or w.isupper() or any(c.isdigit() for c in w):
            continue
        if re.search(r'[a-z][A-Z]', w) or '.' in w.strip('.'):
            continue
        bad.append(w)
    return bad

def check(blocks, fmt, src, stage, dtype, wazuh, allow):
    r = Report(allow)
    section = ''
    for b in blocks:
        if b.kind in ('title', 'heading'):
            section = b.raw.replace('`', '').replace('**', '')
        b.section = section
    prose_kinds = ('prose', 'li', 'oli', 'table')
    prose = [b for b in blocks if b.kind in prose_kinds]
    heads = [b for b in blocks if b.kind in ('title', 'heading')]
    codes = [b for b in blocks if b.kind == 'code']
    alltext = ' '.join(b.text for b in blocks if b.kind != 'code')

    if wazuh == 'auto':
        v5 = len(re.findall(r'\bWazuh\s+5\.\d', src)) + len(re.findall(r'/var/wazuh-manager', src))
        v4 = len(re.findall(r'\bWazuh\s+4\.\d', src))
        wazuh = '5' if v5 > v4 else '4'

    # -- characters, everywhere they can break a copied command ------------------------
    for b in codes:
        for n, ln in enumerate(b.text.split('\n')):
            ref = Block(b.line + n + 1 if fmt != 'html' else b.line, 'code', ln)
            ref.section = b.section
            for ch in CURLY:
                if ch in ln:
                    r.add('CURLY-QUOTE', ERROR, ref, 'Curly quote inside a code block; a pasted command breaks. Use straight quotes.', ln)
                    break
            if '—' in ln or '–' in ln:
                r.add('DASH-IN-CODE', ERROR, ref, 'Em or en dash inside a code block, usually autocorrected `--`. The command fails when pasted.', ln)
            for ch, name in INVISIBLE.items():
                if ch in ln and not (fmt == 'html' and ch == ' '):
                    r.add('INVISIBLE', ERROR, ref, f'{name} (U+{ord(ch):04X}) inside a code block.', ln)
    for b in blocks:
        if b.kind == 'code':
            continue
        for sp in b.code_spans:
            if any(c in sp for c in CURLY) or '—' in sp or '–' in sp:
                r.add('CURLY-QUOTE', ERROR, b, 'Curly quote or dash inside inline code; the value breaks when copied.', sp)
            if '://' in sp:
                r.add('URL-CODE-FONT', WARN, b, 'URL in code font. The guide puts URLs in ordinary font.', sp)
            if re.fullmatch(r'[A-Z][a-z]+(?: [A-Za-z][a-z]+)+', sp.strip()):
                r.add('PROSE-CODE-FONT', WARN, b, 'A UI label or title in code font. Use bold for UI elements, plain text for names.', sp)
        for ch, name in INVISIBLE.items():
            if ch in b.raw and fmt != 'html':
                sev = WARN if ch == ' ' else ERROR
                r.add('INVISIBLE', sev, b, f'{name} (U+{ord(ch):04X}) in text.', b.raw)
        if '—' in b.raw:
            r.add('EM-DASH', WARN, b, 'Em dash. Reviewer 2 reads it as an AI tell; use a period, colon, or comma.', b.raw)
        elif re.search(r'\s–\s', b.raw):
            r.add('EN-DASH', WARN, b, 'En dash used as a dash. Use a period, colon, or comma.', b.raw)

    # -- headings ------------------------------------------------------------------------
    last = 0
    for k, b in enumerate(heads):
        t = b.text.strip()
        bad = heading_case(t)
        if bad:
            r.add('HEADING-CASE', WARN, b, 'Sentence case: lowercase ' + ', '.join(bad[:5]) +
                  ' (or add the proper noun to proper-nouns.txt).', t)
        if re.match(r'^(A|An|The)\s', t):
            r.add('HEADING-FORM', WARN, b, 'Don\'t start a title with an article.', t)
        if re.match(r'^(Understanding|About|Working with)\b', t):
            r.add('HEADING-FORM', WARN, b, 'Don\'t start a concept title with Understanding, About, or Working with.', t)
        if t.endswith(':'):
            r.add('HEADING-FORM', WARN, b, 'No colon at the end of a title.', t)
        if '&' in t.replace('ATT&CK', ''):
            r.add('HEADING-FORM', WARN, b, 'No ampersand in a title; use "and".', t)
        if k == 0 and len(t) > 70:
            r.add('TITLE-LENGTH', WARN, b, f'Title is {len(t)} characters; the guide asks for 50-70.', t)
        lvl = 0 if b.kind == 'title' else b.level
        if last and lvl > last + 1:
            r.add('HEADING-SKIP', WARN, b, f'Heading jumps from level {last} to {lvl}.', t)
        last = lvl if lvl else 1

    # -- prose rules (code masked) ------------------------------------------------------
    defined = set(re.findall(r'\(([A-Z][A-Z0-9]{1,6})s?\)', alltext))
    seen_acr = set()
    for b in prose + heads:
        t = b.text
        is_head = b.kind in ('title', 'heading')
        def hit(rule, sev, pat, msg, flags=re.I):
            m = re.search(pat, t, flags)
            if m:
                r.add(rule, sev, b, msg, t[max(0, m.start() - 30):m.end() + 40])
            return m
        hit('MODAL', ERROR, r'\b(could|should|would)\b', 'No could, should, or would. Use must or can, or rewrite.')
        hit('MODAL', ERROR, r'\bmay\b(?!\s+\d)', 'No may. Use can for ability, might for possibility.')
        hit('LATIN-ABBR', ERROR, r'(?<!\w)(e\.g\.|i\.e\.|etc\b\.?|et al\.|viz\.|cf\.)', 'No Latin abbreviations. Use for example, that is, or such as.')
        if not is_head:
            hit('VS-IN-PROSE', WARN, r'\bvs\.?(?=\s)', 'vs. is allowed only in titles. Use versus or rewrite.')
        hit('VERSION-WORD', ERROR, r'\bWazuh\s+(version\s+\d|v\.?\s?\d)', 'Write "Wazuh 4.14.6", not "Wazuh version" or a v prefix.', 0)
        hit('POSSESSIVE', ERROR, r'\bWazuh[\'’]s\b', 'No possessive or contraction of Wazuh. Write "the Wazuh agent".', 0)
        hit('GENDERED', ERROR, r'\b(he|she|him|his|hers|himself|herself|s/he|he/she|his/her)\b', 'No gendered pronouns. Use you, the user, or they.')
        hit('BUTTON-PHRASE', ERROR, r'\bthe\s+(\*\*[^*]+\*\*|(?:[A-Z][\w-]*\s+){1,3})button\b', 'Write "Click **OK**", not "the OK button".', 0)
        hit('CHECKBOX', ERROR, r'\b(un)?check(ed|s)?\s+(the\s+)?([\w*-]+\s+){0,4}?(checkbox|check box)\b|\buncheck', 'Select or clear a checkbox; never check or uncheck it.')
        hit('PLEASE', WARN, r'\bplease\b', 'No please in instructions (only when quoting the interface).')
        hit('LOGIN', WARN, r'\blog\s?on\b|\blog\s+onto\b|\blog\s?off\b|\blogout\b|\blogin\s+(to|into)\b', 'Use log in (verb) and login (adjective). Log on, log off, and logout only when quoting the UI.')
        hit('INEXACT', WARN, r'\b(some|many|lots of|various)\b', 'Inexact word. State the number or the items, or use multiple.')
        hit('FUTURE', WARN, r'\bwill\b', 'Future tense. Use the simple present.')
        hit('IF-THEN', WARN, r'\bIf\b[^.]*?,\s*then\b', 'Drop then after an if clause.', 0)
        hit('WAZUH-CAN', WARN, r'\bWazuh\s+(can|is able to)\b', 'Write "Wazuh does X", not "Wazuh can do X".', 0)
        hit('CLICK-SELECT', WARN, r'\bclick(s|ing)?\s+on\b', 'Click, not click on.')
        hit('CLICK-SELECT', WARN, r'\bclick(s|ing)?\s+(the\s+)?(\S+\s+){0,4}?(menu|checkbox|drop-down|dropdown|list|option)\b', 'Select menus, lists, options, and checkboxes. Click buttons, tabs, and links.')
        hit('CLICK-SELECT', WARN, r'\bselect(s|ing)?\s+(the\s+)?(\S+\s+){0,3}?button\b', 'Click a button; select is for menus, lists, and options.')
        hit('ELLIPSIS-UI', WARN, r'\*\*[^*]+\.\.\.\*\*|\*\*[^*]+…\*\*', 'Drop the ellipsis from a UI label.', 0)
        hit('DEPRECATED-TERM', WARN, r'\b(OpenSCAP|Kibana|ElasticSearch|Elasticsearch|OpenSearch)\b', 'The guide says to always flag this term. Keep it only if the text is about that product itself.', 0)
        hit('ACTIVE-RESPONSE-CASE', WARN, r'\b(?!Active Response\b)[Aa]ctive [Rr]esponse\b', 'Capability name: write Active Response.', 0)
        hit('SCA-CASE', WARN, r'\b(?!Security Configuration Assessment\b)[Ss]ecurity [Cc]onfiguration [Aa]ssessment\b', 'Capability name: write Security Configuration Assessment.', 0)
        hit('CAPABILITY-CASE', WARN, r'(?<!^)(?<![.:]\s)\b(File Integrity Monitoring|Malware Detection|Log Data Collection|Vulnerability Detection|Command Monitoring|Container Security|System Inventory|Agentless Monitoring)\b', 'Capability names are sentence case in prose (File integrity monitoring). Title case only when it matches a UI label in bold.', 0)
        hit('DATE-FORMAT', WARN, r'\b\d{1,2}/\d{1,2}/\d{2,4}\b|\b20\d\d-\d\d-\d\d\b', 'Spell out the month: June 24, 2021.', 0)
        hit('MEASURE', WARN, r'\b\d+(KB|MB|GB|TB|KiB|MiB|GiB|ms|mm|cm)\b', 'Put a space between the amount and the unit: 35 mm.', 0)
        hit('KEY-COMBO', WARN, r'\*\*(Ctrl|Alt|Shift|Cmd)\s*[-+]', 'Key combinations: **Ctrl** + **C**, bold keys, spaced plain plus sign.', 0)
        for m in re.finditer(r'\b\w+, \w+, ((?:\w+ ){0,2}\w+) (and|or) \w+', t):
            if not re.search(r'\b(and|or)\b', m.group(1)):
                r.add('SERIAL-COMMA', WARN, b, 'Serial comma before the and or or in a list of three or more.', m.group(0))
                break
        hit('DOC-LINK', WARN, r'documentation\.wazuh\.com/(\d+\.\d+|\d\.x)/', 'Documentation links use /current/ unless the page is deliberately version-pinned.', 0)
        if dtype == 'doc' and b.kind == 'prose':
            hit('SHORT-DESC', WARN, r'^(This (section|document|page|guide|topic)|In this (section|document|page|guide))\b', 'Don\'t mention the section itself in a short description.')
        elif b.kind == 'prose':
            hit('SHORT-DESC', WARN, r'^This section (describes|explains|shows)\b', 'Don\'t mention the section itself.')

        if not is_head:
            for s in sentences(t):
                n = len(words(s))
                if n >= 26:
                    r.add('LONG-SENTENCE', WARN, b, f'{n} words; keep sentences under 26.', s)
                first = (re.match(r'[A-Za-z]+', s) or [''])[0]
                fragment = b.kind == 'li' and not s.rstrip().endswith('.')
                if not fragment and first.lower().endswith('ing') and first.lower() not in GERUND_OK and len(first) > 4:
                    r.add('GERUND-START', WARN, b, 'Sentence starts with a gerund. Lead with the subject.', s)
                if re.match(r'(This|That)\s+(is|was|means|makes|lets|allows|gives|shows|ensures|happens|helps|matters|works|causes|creates|results|keeps|prevents|way)\b', s):
                    r.add('STANDALONE-THIS', WARN, b, 'This or that as a pronoun. Name the thing it refers to.', s)
        for acr in re.findall(r'(?<![\w/.-])([A-Z][A-Z0-9]{1,6})s?(?![\w/.-])', t):
            if acr in FAMILIAR or acr in seen_acr or acr.lower() in CAPS_WORDS or re.fullmatch(r'[A-Z]\d+', acr):
                continue
            seen_acr.add(acr)
            if acr not in defined:
                r.add('ACRONYM', WARN, b, f'{acr} is never spelled out. Spell it out on first use: Term ({acr}).', t)
            elif not re.search(r'\(' + acr + r's?\)', t):
                r.add('ACRONYM', WARN, b, f'{acr} is used before it is spelled out.', t)

        if wazuh == '5':
            hit('V5-NUMERIC-RULE', WARN, r'\brule(\.id|\s+ID)?\s+\d{3,6}\b', 'Wazuh 5.0 has no numeric rule IDs. Name the rule by title, or say which release this applies to.')
            hit('V5-REMOVED', WARN, r'\b(agent_control|logall_json|ossec\.log)\b', 'Not on a 5.0 manager (no ossec.log, logall_json, or agent_control). Re-verify on 5.0.', 0)
        if b.kind in ('li', 'oli') and re.search(r'[;,]$|^and\s', b.raw.strip()):
            r.add('LIST-PUNCT', WARN, b, 'No semicolons or commas at the end of list items, and no "and" before the last one.', b.raw)
        if b.kind == 'oli' and len(sentences(t)) > 1:
            r.add('STEP-ONE-SENTENCE', WARN, b, 'Limit a step to one sentence; move the rest into prose or the next step.', t)

    # -- list shape --------------------------------------------------------------------
    run, steps, sec = [], 0, None
    def close_run():
        ends = {bool(re.search(r'[.!?]$', x.raw.strip())) for x in run}
        if len(run) > 1 and len(ends) == 2:
            r.add('LIST-PARALLEL', WARN, run[0], 'Bullet list mixes sentences and fragments. Make every item one or the other.', run[0].raw)
    for b in blocks:
        if b.kind == 'li':
            run.append(b)
            continue
        if run:
            close_run()
            run = []
        if b.kind in ('title', 'heading'):
            if steps > 10:
                r.add('STEP-COUNT', WARN, sec, f'{steps} numbered steps in one task; the guide asks for 7-10. Split the task.')
            steps, sec = 0, b
        elif b.kind == 'oli':
            steps += 1
    if run:
        close_run()
    if steps > 10:
        r.add('STEP-COUNT', WARN, sec, f'{steps} numbered steps in one task; the guide asks for 7-10. Split the task.')
    for k, b in enumerate(blocks[:-1]):
        nx = blocks[k + 1]
        if b.kind == 'prose' and b.raw.rstrip().endswith(':') and (nx.kind == 'table' or nx.raw.lstrip().startswith('(image')):
            r.add('COLON-INTRO', WARN, b, 'No colon to introduce an image or a table.', b.raw)

    # -- code blocks ---------------------------------------------------------------------
    rule_ids, desc_by_id = {}, {}
    for b in codes:
        if getattr(b, 'unclosed', False):
            r.add('UNCLOSED-FENCE', ERROR, b, 'Code fence is never closed; everything after it reads as code.')
        if fmt == 'md' and not b.lang:
            r.add('FENCE-NO-LANG', WARN, b, 'Code fence without a language. The renderer needs it to decide shell prompts.')
        body = b.text
        if re.search(r'\n\s*\n\s*\n', body):
            r.add('CODE-BLANK-LINES', WARN, b, 'Two or more blank lines in a row inside a code block, often left by a deleted comment.')
        for m in re.finditer(r'<rule\b([^>]*)>', body):
            attrs = m.group(1)
            idm = re.search(r'\bid="(\d+)"', attrs)
            if not idm:
                continue
            rid = int(idm.group(1))
            lvl = re.search(r'\blevel="(\d+)"', attrs)
            if 'overwrite="yes"' not in attrs and not 100000 <= rid <= 120000:
                r.add('RULE-ID-RANGE', ERROR, b, f'Custom rule {rid} is outside 100000-120000 (the guide\'s range). Built-in overrides need overwrite="yes".')
            if rid in rule_ids and rule_ids[rid] is not b:
                r.add('DUP-RULE-ID', ERROR, b, f'Rule {rid} is defined twice.')
            rule_ids[rid] = b
            tail = body[m.end():]
            end = tail.find('</rule>')
            dm = re.search(r'<description>(.*?)</description>', tail[:end if end >= 0 else None], re.S)
            if dm:
                desc_by_id[rid] = (dm.group(1), lvl.group(1) if lvl else '')
        if b.lang in SHELL_LANGS - {'text', ''} or (fmt != 'md' and not b.lang):
            for ln in body.split('\n'):
                for v in re.findall(r'<([A-Za-z][\w -]*)>', ln):
                    if re.search(r'[a-z]', v) and re.search(r'your|[ _-]', v, re.I):
                        r.add('VARIABLE-CASE', WARN, b, f'Placeholder <{v}>: write <{v.upper().replace(" ", "_").replace("-", "_")}>.', ln)
        if b.lang not in XML_LANGS:
            for ln in body.split('\n'):
                if wazuh == '5' and re.search(r'/var/ossec/(logs/(alerts|archives)|etc/(rules|decoders|ossec\.conf)|bin/(agent_control|wazuh-control))', ln):
                    r.add('V5-MANAGER-PATH', WARN, b, 'On a 5.0 manager this lives under /var/wazuh-manager/. /var/ossec/ on 5.0 is the agent.', ln)
    for rid, (desc, lvl) in desc_by_id.items():
        if re.search(r'\b(inferred?|confirm|verify that|may|might|probably|likely|should)\b', desc, re.I):
            r.add('RULE-DESC-HEDGE', WARN, rule_ids[rid], f'Rule {rid} description hedges. Say what happened, with fields; put caveats in the prose.', desc)
    prose_raw = ' '.join(b.raw + ' ' + ' '.join(b.code_spans) for b in blocks if b.kind != 'code')
    for rid, (desc, lvl) in desc_by_id.items():
        if lvl != '0' and not re.search(r'\b' + str(rid) + r'\b', prose_raw):
            r.add('RULE-NO-TEST', WARN, rule_ids[rid], f'Rule {rid} is never named outside its code block. Map it to the test step that triggers it, or cut it.')

    # -- whole-piece rules ---------------------------------------------------------------
    if not re.search(r'\bWazuh\s+\d+\.\d+', src):
        r.add('NO-VERSION', ERROR if dtype == 'blog' else WARN, None,
              'The piece never states its Wazuh version (for example, Wazuh 4.14.6). 4.x and 5.0 differ in paths, rule IDs, and pipeline.')
    markers = [b for b in blocks if b.kind == 'comment' and 'UNVERIFIED' in b.text]
    markers += [b for b in blocks if b.kind != 'comment' and 'not verified in the lab]' in b.raw.lower()]
    for b in markers:
        r.add('MARKER', ERROR if stage == 'final' else WARN, b,
              'Unverified claim. It must be verified by a tester, or cut, before a final Doc.' if stage == 'final'
              else 'Unverified claim marker: list it for the tester.', b.raw.strip())
    if fmt == 'html' and stage == 'final':
        for b in blocks:
            if b.kind != 'code' and re.search(r'\(image:', b.raw):
                r.add('IMAGE-PLACEHOLDER', ERROR, b, 'A screenshot placeholder is still in the Doc.', b.raw)
    return r, wazuh

def main(argv):
    args = [a for a in argv if not a.startswith('--')]
    opts = dict(a[2:].split('=', 1) if '=' in a else (a[2:], '1') for a in argv if a.startswith('--'))
    if len(args) != 1:
        print(__doc__)
        return 2
    stage, dtype = opts.get('stage', 'draft'), opts.get('type', 'blog')
    allow = set(filter(None, opts.get('allow', '').upper().split(',')))
    blocks, fmt, src = load(args[0])
    rep, wazuh = check(blocks, fmt, src, stage, dtype, opts.get('wazuh', 'auto'), allow)
    errors = [f for f in rep.findings if f['severity'] == ERROR]
    if 'json' in opts:
        print(json.dumps({'file': args[0], 'format': fmt, 'stage': stage, 'type': dtype, 'wazuh': wazuh,
                          'allowed': sorted(allow), 'errors': len(errors),
                          'warnings': len(rep.findings) - len(errors), 'findings': rep.findings}, indent=2))
    else:
        loc = 'block' if fmt == 'html' else 'line'
        print(f'{args[0]}  [{fmt}, stage={stage}, type={dtype}, Wazuh {wazuh}.x]')
        for sev in (ERROR, WARN):
            group = [f for f in rep.findings if f['severity'] == sev]
            if group:
                print(f'\n{sev.upper()}S ({len(group)})')
            for f in group:
                where = f'{loc} {f["line"]}' if f['line'] else 'whole piece'
                sec = f'  [{f["section"][:40]}]' if f['section'] else ''
                print(f'  {f["rule"]:18} {where:10}{sec}  {f["message"]}')
                if f['snippet']:
                    print(f'  {"":18} > {f["snippet"]}')
        print(f'\n{len(errors)} error(s), {len(rep.findings) - len(errors)} warning(s).'
              + (f' Allowed: {",".join(sorted(allow))}.' if allow else ''))
    return 1 if errors else 0

if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    sys.exit(main(sys.argv[1:]))
