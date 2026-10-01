#!/usr/bin/env python3
"""Gate, render, and name markdown drafts as house-format HTML for a Google Docs upload.

Usage:
  render.py <inputs...> [--stage=auto|research|draft|final] [--markers=auto|visible|strip|keep]
            [--allow=RULE,RULE] [--date=YYYY-MM-DD] [--out=DIR] [--dry-run]

Inputs are .md files, directories (walked for .md), or globs. Each file is checked by
technical-writer-1/self-check-sweep/stylecheck.py first; a file with errors is not rendered.
Writes <out>/<slug>/<slug>.html per file plus <out>/manifest.json. Exits 1 if any file was blocked.
The visual spec is in SKILL.md ("What the renderer does").
"""
import datetime, glob, html, json, os, re, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'technical-writer-1', 'self-check-sweep'))
import stylecheck  # noqa: E402

# Claude > Blog posts in the team Drive (verified 2026-09-29 with get_file_metadata)
FOLDERS = {'research': '1q5N-btqb9vvWsOtz54PShKSWCeQMRUQ-',   # Blog posts > Research
           'draft': '1HVVSy2PKjWQiL0siyuIgDkvOz3IAGZow',      # Blog posts
           'final': '1PC7Gk1nJh-zYxn9DnDxeMyvhM6_znXSp'}      # Blog posts > To be published
SKIP_DIRS = {'report', 'lab', '.claude', 'learning', 'agents', 'terraform', 'deployments', '.git'}
SKIP_FILES = {'readme.md', 'changelog.md', 'doc.md', 'pipeline.md', 'review-1.md', 'review-2.md', 'agents.md'}

# ---------------------------------------------------------------- spec (Google Docs defaults)
BODY_FONT, CODE_FONT = 'Arial', 'Courier New'   # one family each: a fallback list imports as Courier
SHADE = '#cfe2f3'
LINK = '#1155cc'
BORDER = 'border:1pt solid #000000'
HEADINGS = {  # doc level: (size pt, space before, space after, color)
    0: (26, 0, 3, '#000000'),     # Title (set the Title style by hand afterwards)
    1: (20, 20, 6, '#000000'),
    2: (16, 18, 6, '#000000'),
    3: (14, 16, 4, '#434343'),
    4: (12, 14, 4, '#666666'),
    5: (11, 12, 4, '#666666'),
}
PARA_AFTER, BLOCK_AFTER = 10, 20
SHELL = {'bash', 'sh', 'shell', 'console', 'zsh'}
WIN_SHELL = {'powershell', 'ps1', 'pwsh', 'cmd', 'bat'}
NOTE = re.compile(r'^(?:>\s*)?\*{0,2}(Note|Warning|Caution|Important)\*{0,2}\s*:\*{0,2}\s*(.*)$', re.I | re.S)

def esc(s):
    return html.escape(s, quote=False)

def inline(text):
    """Markdown inline -> HTML with the house styles. Code is shaded Courier New on a span."""
    out, pos = [], 0
    for m in re.finditer(r'(`+)(.+?)\1', text):
        out.append(_inline_text(text[pos:m.start()]))
        code = m.group(2)
        if re.fullmatch(r'[A-Z][a-z]+(?: [A-Za-z][a-z]+)+', code.strip()):
            out.append(esc(code))   # a title in backticks loses the code font
        else:
            out.append(f'<span style="font-family:\'{CODE_FONT}\';background-color:{SHADE}">{esc(code)}</span>')
        pos = m.end()
    out.append(_inline_text(text[pos:]))
    return ''.join(out)

def _inline_text(t):
    t = esc(t)
    t = re.sub(r'\[([^\]]+)\]\(([^)\s]+)\)',
               lambda m: f'<a href="{m.group(2)}" style="color:{LINK};text-decoration:underline">{m.group(1)}</a>', t)
    t = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', t)
    t = re.sub(r'(?<![\w*])\*(?!\s)(.+?)\*(?!\w)', r'<em>\1</em>', t)
    t = re.sub(r'(?<![\w])_(?!\s)(.+?)_(?!\w)', r'<em>\1</em>', t)
    return t

def para(content, extra='', align='justify', before=0):
    style = f'text-align:{align};padding-top:{before}pt;padding-bottom:{PARA_AFTER}pt;{extra}'
    return f'<p style="{style}"><span style="font-family:{BODY_FONT};font-size:11pt">{content}</span></p>'

def heading(level, text):
    size, before, after, color = HEADINGS[min(level, 5)]
    tag = 'h1' if level == 0 else f'h{min(level, 6)}'
    # font-weight only survives on a span; padding (not margin) becomes space before/after
    return (f'<{tag} style="padding-top:{before}pt;padding-bottom:{after}pt">'
            f'<span style="font-family:{BODY_FONT};font-size:{size}pt;color:{color};font-weight:normal">'
            f'{inline(text)}</span></{tag}>')

def cell_table(paragraphs, before=0):
    return (f'<table style="border-collapse:collapse;width:468pt;table-layout:fixed;margin-top:{before}pt">'
            f'<tr><td style="{BORDER};padding:5pt;width:468pt;vertical-align:top">'
            + ''.join(paragraphs) + '</td></tr></table>')

def prompt_for(lang, info, prev_line):
    """Shell prompts go on commands only. A block is file content when the fence says so
    (```bash file) or the line above it is a lone inline-code path."""
    if 'file' in info.split() or 'noprompt' in info.split():
        return ''
    if 'prompt' not in info.split() and re.fullmatch(r'`[^`\s]+`:?', prev_line.strip() or 'x'):
        return ''
    if lang in SHELL:
        return '# '
    if lang in WIN_SHELL:
        return '> '
    return ''

def code_block(lines, lang, info, prev_line, before=0):
    prompt = prompt_for(lang, info, prev_line)
    paras, cont, heredoc = [], False, None
    for ln in lines:
        p = ''
        if prompt and ln.strip() and not cont and heredoc is None and not re.match(r'^\s*(#|\$|>|PS[ >])', ln):
            p = prompt
        if heredoc is not None:
            if ln.strip() == heredoc:
                heredoc = None
        else:
            m = re.search(r"<<-?\s*['\"]?(\w+)['\"]?", ln)
            if m and lang in SHELL:
                heredoc = m.group(1)
        cont = bool(re.search(r'\\\s*$', ln)) if lang in SHELL else (bool(re.search(r'`\s*$', ln)) if lang in WIN_SHELL else False)
        text = p + ln
        lead = len(text) - len(text.lstrip(' '))
        body = '&nbsp;' * lead + esc(text[lead:])   # indentation is load bearing in XML and YAML
        span = (f'<span style="font-family:\'{CODE_FONT}\';font-size:11pt;background-color:{SHADE}">{body}</span>'
                if text.strip() else '&nbsp;')
        paras.append(f'<p style="line-height:1.0;padding-top:0pt;padding-bottom:0pt">{span}</p>')
    return cell_table(paras, before)

def note_block(label, text, before=0):
    body = (f'<p style="text-align:justify"><span style="font-family:{BODY_FONT};font-size:11pt">'
            f'<strong>{esc(label.capitalize())}:</strong> {inline(text)}</span></p>')
    return cell_table([body], before)

def md_table(rows, before=0):
    head, *rest = rows
    def row(cells, bold):
        tds = ''.join(f'<td style="{BORDER};padding:5pt;vertical-align:top"><p><span style="font-family:{BODY_FONT};font-size:11pt">'
                      + (f'<strong>{inline(c)}</strong>' if bold else inline(c)) + '</span></p></td>' for c in cells)
        return f'<tr>{tds}</tr>'
    return (f'<table style="border-collapse:collapse;width:468pt;margin-top:{before}pt">'
            + row(head, True) + ''.join(row(r, False) for r in rest) + '</table>')

def render_markers(src, mode):
    def sub(m):
        body = m.group(1)
        if not re.match(r'\s*UNVERIFIED', body):
            return '' if mode != 'keep' else m.group(0)
        if mode == 'keep':
            return m.group(0)
        if mode == 'strip':
            return ''
        label = 'Blocking, not verified in the lab' if 'BLOCKING' in body.upper() else 'Not verified in the lab'
        return f'**[{label}]**'
    return re.sub(r'<!--(.*?)-->', sub, src, flags=re.S)

def render(src, markers='visible'):
    """One markdown file -> (title, HTML document)."""
    src = render_markers(src.replace('\r\n', '\n'), markers)
    lines = src.split('\n')
    h1s = [l for l in lines if re.match(r'^#\s', l)]
    shift = 1 if len(h1s) == 1 else 0   # # Title, ## section -> Title, H1
    out, title, i, prev_nonempty, gap = [], '', 0, '', 0
    lists = []   # stack of (tag, indent)

    def close_lists(to_indent=-1):
        while lists and lists[-1][1] > to_indent:
            out.append(f'</{lists.pop()[0]}>')

    def spaced():
        nonlocal gap
        g, gap = gap, 0
        return g

    while i < len(lines):
        ln = lines[i]
        fm = re.match(r'^(\s*)(`{3,}|~{3,})\s*([\w+-]*)\s*(.*)$', ln)
        if fm:
            close_lists()
            indent, mark, lang, info = fm.groups()
            body, j = [], i + 1
            while j < len(lines) and not re.match(r'^\s*' + re.escape(mark[0]) + '{' + str(len(mark)) + r',}\s*$', lines[j]):
                body.append(lines[j][len(indent):] if lines[j].startswith(indent) else lines[j])
                j += 1
            out.append(code_block(body, lang.lower(), info.lower(), prev_nonempty, spaced()))
            gap = BLOCK_AFTER
            prev_nonempty, i = 'code', j + 1
            continue
        hm = re.match(r'^(#{1,6})\s+(.*?)\s*#*\s*$', ln)
        if hm:
            close_lists()
            level = 0 if not title else max(1, len(hm.group(1)) - shift)
            if not title:
                title = re.sub(r'[`*]', '', hm.group(2))
            out.append(heading(level, hm.group(2)))
            gap, prev_nonempty, i = 0, ln, i + 1
            continue
        if ln.lstrip().startswith('|'):
            close_lists()
            rows = []
            while i < len(lines) and lines[i].lstrip().startswith('|'):
                cells = [c.strip() for c in lines[i].strip().strip('|').split('|')]
                if not all(re.fullmatch(r':?-{2,}:?', c) for c in cells if c):
                    rows.append(cells)
                i += 1
            out.append(md_table(rows, spaced()))
            gap, prev_nonempty = BLOCK_AFTER, 'table'
            continue
        lm = re.match(r'^(\s*)([-*+]|\d+[.)])\s+(.*)$', ln)
        if lm:
            ind, tag = len(lm.group(1)), ('ul' if lm.group(2) in '-*+' else 'ol')
            num = re.match(r'\d+', lm.group(2))
            start = f' start="{num.group(0)}"' if num and num.group(0) != '1' else ''   # a list resumed after a code block
            if not lists or ind > lists[-1][1]:
                out.append(f'<{tag}{start}>')
                lists.append((tag, ind))
            else:
                close_lists(ind)
                if lists and lists[-1][0] != tag:
                    out.append(f'</{lists.pop()[0]}>')
                if not lists:
                    out.append(f'<{tag}{start}>')
                    lists.append((tag, ind))
            item, j = [lm.group(3)], i + 1
            while j < len(lines) and lines[j].strip() and not re.match(r'^\s*([-*+]|\d+[.)])\s+|^\s*(`{3,}|~{3,})|^#|^\s*\|', lines[j]):
                item.append(lines[j].strip())
                j += 1
            out.append(f'<li><p style="padding-bottom:4pt"><span style="font-family:{BODY_FONT};font-size:11pt">{inline(" ".join(item))}</span></p></li>')
            gap, prev_nonempty, i = 0, ln, j
            continue
        if not ln.strip():
            if lists and not (i + 1 < len(lines) and re.match(r'^\s+\S', lines[i + 1])):
                close_lists()
            i += 1
            continue
        # a paragraph: gather until blank or a new block
        chunk, j = [ln.strip()], i + 1
        while j < len(lines) and lines[j].strip() and not re.match(r'^\s*(`{3,}|~{3,}|#{1,6}\s|\||([-*+]|\d+[.)])\s)', lines[j]):
            chunk.append(lines[j].strip())
            j += 1
        close_lists()
        # a figure placeholder and its caption are two paragraphs, caption centred
        pieces, cur = [], []
        for c in chunk:
            if re.match(r'^(Fig\.|Figure)\s*\d+', c) or c.startswith('(image:'):
                if cur:
                    pieces.append(' '.join(cur))
                pieces.append(c)
                cur = []
            else:
                cur.append(c)
        if cur:
            pieces.append(' '.join(cur))
        for p in pieces:
            p = re.sub(r'^>\s?', '', p)
            nm = NOTE.match(p)
            if nm:
                out.append(note_block(nm.group(1), nm.group(2), spaced()))
                gap = BLOCK_AFTER
            elif re.match(r'^(Fig\.|Figure)\s*\d+', p):
                out.append(para(inline(p), align='center', before=0))
                gap = BLOCK_AFTER
            elif p.startswith('(image:'):
                out.append(para(inline(p), align='center', before=spaced()))
                gap = 0
            else:
                out.append(para(inline(p), before=spaced()))
        prev_nonempty, i = chunk[-1], j
    close_lists()
    doc = ('<!DOCTYPE html><html><head><meta charset="utf-8"><title>' + esc(title) + '</title></head>'
           f'<body style="font-family:{BODY_FONT};font-size:11pt">' + '\n'.join(out) + '</body></html>')
    return title, doc

# ---------------------------------------------------------------- driver
def expand(inputs, root):
    files = []
    for inp in inputs or [root]:
        for path in (glob.glob(inp) or [inp]):
            if os.path.isdir(path):
                for d, dirs, fs in os.walk(path):
                    dirs[:] = [x for x in dirs if x.lower() not in SKIP_DIRS and not x.startswith('.')]
                    files += [os.path.join(d, f) for f in fs if f.lower().endswith('.md') and f.lower() not in SKIP_FILES]
            elif path.lower().endswith('.md'):
                files.append(path)
    return sorted(set(os.path.abspath(f) for f in files))

def slug_of(path, title):
    base = os.path.splitext(os.path.basename(path))[0]
    if base.lower() in ('draft', 'post', 'index', 'final'):
        base = title or os.path.basename(os.path.dirname(path))
    return re.sub(r'[^a-z0-9]+', '-', base.lower()).strip('-')[:60] or 'draft'

def main(argv):
    opts = dict(a[2:].split('=', 1) if '=' in a else (a[2:], '1') for a in argv if a.startswith('--'))
    inputs = [a for a in argv if not a.startswith('--')]
    repo = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
    files = expand(inputs, os.path.join(repo, 'results'))
    if not files:
        print('No .md inputs found.')
        return 2
    date = opts.get('date', datetime.date.today().isoformat())
    scratch = os.environ.get('CLAUDE_SCRATCHPAD') or tempfile.gettempdir()
    out_root = opts.get('out', os.path.join(scratch, 'google-doc-house-format'))
    allow = set(filter(None, opts.get('allow', '').upper().split(',')))
    manifest, blocked = [], 0
    for f in files:
        stage = opts.get('stage', 'auto')
        if stage == 'auto':   # final is never inferred: a Doc in To be published is a decision
            stage = 'research' if 'research' in os.path.basename(f).lower() else 'draft'
        markers = opts.get('markers', 'auto')
        if markers == 'auto':
            markers = 'strip' if stage == 'final' else 'visible'
        blocks, fmt, src = stylecheck.load(f)
        rep, wazuh = stylecheck.check(blocks, fmt, src, 'final' if stage == 'final' else 'draft',
                                      opts.get('type', 'blog'), 'auto', allow)
        errors = [x for x in rep.findings if x['severity'] == 'error']
        warnings = [x for x in rep.findings if x['severity'] == 'warning']
        title, doc = render(src, markers)
        slug = slug_of(f, title)
        doc_title = {'research': f'Research report: {title} ({date})', 'draft': f'{title} (draft, {date})',
                     'final': title}[stage]
        row = {'source': f, 'slug': slug, 'stage': stage, 'markers': markers, 'wazuh': wazuh,
               'doc_title': doc_title, 'folder_id': FOLDERS[stage], 'errors': errors,
               'warnings': len(warnings), 'ready': not errors, 'html': None}
        if errors:
            blocked += 1
            print(f'BLOCKED  {f}\n         {len(errors)} error(s); run stylecheck.py on it for details.')
            for e in errors[:8]:
                print(f'         {e["rule"]} line {e["line"]}: {e["message"]}')
        elif 'dry-run' not in opts:
            d = os.path.join(out_root, stage, slug)
            os.makedirs(d, exist_ok=True)
            row['html'] = os.path.join(d, slug + '.html')
            with open(row['html'], 'w', encoding='utf-8') as fh:
                fh.write(doc)
            print(f'READY    {f}\n         -> {row["html"]}\n         title: {doc_title}  folder: {stage} ({FOLDERS[stage]})'
                  f'  warnings: {len(warnings)}')
        else:
            print(f'READY    {f} (dry run)  title: {doc_title}  warnings: {len(warnings)}')
        manifest.append(row)
    os.makedirs(out_root, exist_ok=True)
    mpath = os.path.join(out_root, 'manifest.json')
    with open(mpath, 'w', encoding='utf-8') as fh:
        json.dump(manifest, fh, indent=2)
    print(f'\nmanifest: {mpath}')
    print('Still manual after upload: 1) set the title to the Title style  2) place screenshots at the '
          '(image: ...) placeholders  3) turn off autocorrect (Tools > Preferences) before anyone edits.')
    return 1 if blocked else 0

if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    sys.exit(main(sys.argv[1:]))
