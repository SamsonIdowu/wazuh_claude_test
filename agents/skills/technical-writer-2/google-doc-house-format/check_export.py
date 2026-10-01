#!/usr/bin/env python3
"""Audit a Google Doc's HTML export against the house format. Run it on the Doc you just
uploaded, and on any Doc you are handed to review.

Usage:
  check_export.py <export.html | download_file_content.json> [--stage=draft|final] [--json]

The JSON form is what download_file_content(fileId, exportMimeType="text/html") writes when the
export is too large to return inline: base64 HTML in `content`. Styles in an export live in CSS
classes, so every element's style is resolved through the <style> block before counting.
Exits 1 when a check fails. Formatting only; run stylecheck.py on the same file for the wording.
"""
import base64, json, re, sys
from html.parser import HTMLParser

MONO = re.compile(r'font-family:\s*["\']?courier new', re.I)
BLOCKS = {'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li'}
HEAD_SIZE = {'h1': '20pt', 'h2': '16pt', 'h3': '14pt'}

class Export(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.classes, self.css, self.in_style = {}, '', False
        self.stack, self.cur, self.blocks = [], None, []
        self.td, self.li, self.tables, self.links = 0, 0, [], []

    def style(self, attrs):
        a = dict(attrs)
        s = ''
        for c in (a.get('class') or '').split():
            s += ';' + self.classes.get(c, '')
        s = (s + ';' + (a.get('style') or '')).lower()
        return a, re.sub(r'\s*([:;])\s*', r'\1', s)

    def handle_starttag(self, tag, attrs):
        if tag == 'style':
            self.in_style = True
            return
        a, s = self.style(attrs)
        inherited = self.stack[-1][1] if self.stack else ''
        eff = inherited + ';' + s if tag not in BLOCKS else s
        self.stack.append((tag, eff))
        if tag == 'table':
            self.tables.append({'cells': 0, 'mono_cells': 0, 'border': 'border' in s or 'border' in eff})
        if tag == 'td':
            self.td += 1
            if self.tables:
                self.tables[-1]['cells'] += 1
                self.tables[-1]['td_style'] = s
        if tag == 'li':
            self.li += 1
        aid = a.get('id') or ''
        if tag == 'a' and aid.startswith('cmnt') and not aid.startswith('cmnt_ref') and self.cur is not None:
            self.cur['comment'] = True
        if tag == 'a' and a.get('href') and not aid.startswith('cmnt'):
            self.links.append(eff)
        if tag in BLOCKS:
            if tag == 'p' and self.cur is not None and self.cur['tag'] == 'li':
                return   # a paragraph inside a list item belongs to the item
            self.cur = {'tag': tag, 'style': s, 'segs': [], 'in_td': self.td > 0, 'in_li': self.li > 0,
                        'title': 'title' in (a.get('class') or '').split()}

    def handle_endtag(self, tag):
        if tag == 'style':
            self.in_style = False
            for sel, body in re.findall(r'\.([\w-]+)\s*\{([^}]*)\}', self.css):
                self.classes[sel] = self.classes.get(sel, '') + ';' + body
            return
        if tag == 'td':
            self.td -= 1
        if tag == 'li':
            self.li -= 1
        while self.stack:
            t, _ = self.stack.pop()
            if t == tag:
                break
        if tag == 'p' and self.cur is not None and self.cur['tag'] == 'li':
            return
        if tag in BLOCKS and self.cur is not None:
            if not self.cur.get('comment'):
                self.blocks.append(self.cur)
            self.cur = None

    def handle_data(self, data):
        if self.in_style:
            self.css += data
        elif self.cur is not None:
            self.cur['segs'].append((data, self.stack[-1][1] if self.stack else ''))

def load(path):
    raw = open(path, encoding='utf-8').read()
    if path.endswith('.json'):
        raw = base64.b64decode(json.loads(raw)['content']).decode('utf-8')
    return raw

def audit(src, stage):
    p = Export()
    p.feed(src)
    res = []
    def add(name, ok, got, want, catches):
        res.append({'check': name, 'ok': ok, 'got': got, 'want': want, 'catches': catches})

    heads = [b for b in p.blocks if b['tag'] in ('h1', 'h2', 'h3')]
    if heads and heads[0] is p.blocks[0] and any('26pt' in st for t, st in heads[0]['segs']):
        heads = heads[1:]   # the title before its Title style is set; counted by 'Title style set'
    bold = [b for b in heads if 'font-weight:700' in b['style'] or
            any('font-weight:700' in st for t, st in b['segs'] if t.strip())]
    add('bold headings', not bold, len(bold), 0, 'headings importing bold (font-weight must sit on a span)')
    wrong = [b for b in heads if not any(HEAD_SIZE[b['tag']] in st for t, st in b['segs'] if t.strip())
             and HEAD_SIZE[b['tag']] not in b['style']]
    add('heading sizes (H1 20, H2 16, H3 14pt)', not wrong, len(wrong), 0, 'the importer\'s 24pt/18pt defaults')
    titles = [b for b in p.blocks if b['title']]
    add('Title style set', bool(titles), len(titles), 1, 'manual step 1 still open: title is a Heading 1')
    blue = [l for l in p.links if '#0000ee' in l]
    blue += [1 for b in p.blocks for t, st in b['segs'] if '#0000ee' in st]
    add('browser-blue links', not blue, len(blue), 0, 'links falling back to #0000ee')

    body = [b for b in p.blocks if b['tag'] == 'p' and not b['in_td'] and not b['in_li'] and not b['title']
            and ''.join(t for t, _ in b['segs']).strip()
            and not all(MONO.search(st) for t, st in b['segs'] if t.strip())]
    caption = re.compile(r'^\s*(Fig\.|Figure)\s*\d+|^\s*\(image:')
    captions = [b for b in body if caption.match(''.join(t for t, _ in b['segs']))]
    prose = [b for b in body if b not in captions]
    just = [b for b in prose if 'text-align:justify' in b['style']]
    add('justified body paragraphs', len(just) == len(prose), f'{len(just)}/{len(prose)}', 'all', 'the body style not applying')
    cen = [b for b in captions if 'text-align:center' in b['style']]
    add('centred captions', len(cen) == len(captions), f'{len(cen)}/{len(captions)}', 'all', 'captions left-aligned')

    code_lines = [b for b in p.blocks if ''.join(t for t, _ in b['segs']).strip()
                  and all(MONO.search(st) for t, st in b['segs'] if t.strip())]
    path = re.compile(r'^\s*[\w./\\:~-]*[/\\.][\w./\\:~-]*:?\s*$')   # a lone file path above a block
    stray = [b for b in code_lines if not b['in_td'] and not path.match(''.join(t for t, _ in b['segs']))]
    add('code lines inside a table', not stray, len(stray), 0, 'code pasted as bare monospace paragraphs (markdown import)')
    unshaded = [b for b in code_lines if not any('#cfe2f3' in st for t, st in b['segs'] if t.strip())]
    add('code shading #cfe2f3', not unshaded, f'{len(code_lines) - len(unshaded)}/{len(code_lines)}', 'all', 'shading dropped')
    inline_code = sum(1 for b in p.blocks if b not in code_lines for t, st in b['segs'] if t.strip() and MONO.search(st))
    inline_unshaded = sum(1 for b in p.blocks if b not in code_lines for t, st in b['segs']
                          if t.strip() and MONO.search(st) and '#cfe2f3' not in st)
    add('inline code shading', inline_unshaded == 0, f'{inline_code - inline_unshaded}/{inline_code}', 'all', 'inline spans unshaded')

    damage = []
    for b in code_lines:
        text = ''.join(t for t, _ in b['segs'])
        if re.search('[‘’“”–—]', text):
            damage.append(text.strip()[:80])
    add('autocorrect damage in code', not damage, len(damage), 0, 'curly quotes or dashes typed into a command after upload')
    esc = [b for b in p.blocks if re.search(r'\\\[|\\\]', ''.join(t for t, _ in b['segs']))]
    add('escaped square brackets', not esc, len(esc), 0, 'a markdown upload (\\[...\\])')

    text_all = [''.join(t for t, _ in b['segs']) for b in p.blocks]
    ph = [t for t in text_all if '(image:' in t]
    add('image placeholders', stage != 'final' or not ph, len(ph), 0 if stage == 'final' else 'any',
        'manual step 2 still open: screenshots not placed')
    mk = [t for t in text_all if 'not verified in the lab]' in t.lower()]
    add('unverified markers', stage != 'final' or not mk, len(mk), 0 if stage == 'final' else 'any',
        'an unverified claim in a final Doc')
    return res, {'code_lines': code_lines, 'damage': damage}

def main(argv):
    opts = dict(a[2:].split('=', 1) if '=' in a else (a[2:], '1') for a in argv if a.startswith('--'))
    args = [a for a in argv if not a.startswith('--')]
    if len(args) != 1:
        print(__doc__)
        return 2
    res, extra = audit(load(args[0]), opts.get('stage', 'draft'))
    failed = [r for r in res if not r['ok']]
    if 'json' in opts:
        print(json.dumps({'file': args[0], 'failed': len(failed), 'checks': res, 'damage': extra['damage']}, indent=2))
    else:
        for r in res:
            mark = 'ok  ' if r['ok'] else 'FAIL'
            print(f'{mark} {r["check"]:40} got {str(r["got"]):8} want {r["want"]}' + ('' if r['ok'] else f'   <- {r["catches"]}'))
        for d in extra['damage']:
            print(f'     damaged code line: {d}')
        print(f'\n{len(failed)} check(s) failed.')
    return 1 if failed else 0

if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    sys.exit(main(sys.argv[1:]))
