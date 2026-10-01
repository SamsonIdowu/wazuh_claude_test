#!/usr/bin/env python3
"""Map every custom rule in a post's rules XML to the Testing-section text that claims it.
Usage: coverage-map.py <rules.xml> <post-plain-text.txt> [--screenshot-ids 101901,101903,...]
Rules XML: the code block extracted from the doc. Post text: the plain-text export (CRLF ok)."""
import re, sys, xml.etree.ElementTree as ET
rules_xml, post = sys.argv[1], sys.argv[2]
shot = set()
if '--screenshot-ids' in sys.argv:
    shot = set(sys.argv[sys.argv.index('--screenshot-ids') + 1].split(','))
root = ET.fromstring('<root>' + open(rules_xml, encoding='utf-8').read() + '</root>')
rules = [(r.get('id'), r.get('level')) for r in root.iter('rule')]
text = open(post, encoding='utf-8').read().replace('\r', '')
# Testing section = from a line that is exactly "Testing" (optionally with comment anchors) to the next top-level heading
m = re.search(r'^Testing\b.*$', text, re.M)
testing = text[m.start():] if m else text
end = re.search(r'^(Visualizing|Conclusion|References)\b', testing, re.M)
testing = testing[:end.start()] if end else testing
LABELS = {'Output', 'Note', 'Where:', 'Where', 'Warning'}  # table labels, not headings
# plain-text export prefixes some headings with a tab
heads = [(h.start(), h.group(1).strip()) for h in re.finditer(r'^\t?([A-Z][^\n.:]{3,60})$', testing, re.M)
         if h.group(1).strip() not in LABELS]
def section(pos):
    s = [h for p, h in heads if p <= pos]
    return s[-1] if s else '?'
print(f"{'RULE':8} {'LVL':4} {'CLAIMED IN (Testing subsection)':45} SCREENSHOT")
for rid, lvl in rules:
    hits = sorted({section(x.start()) for x in re.finditer(r'\b' + rid + r'\b', testing)})
    claim = '; '.join(hits) if hits else '** NO TEST **'
    s = ('yes' if rid in shot else '** no **') if shot else '-'
    if lvl == '0': claim, s = 'base rule (never alerts)', 'n/a'
    print(f'{rid:8} {lvl:4} {claim[:45]:45} {s}')
