---
name: self-check-sweep
description: Run the Wazuh style guide's mechanical rules, plus the open writer lessons, over a markdown/RST draft or a Google Docs HTML export, and fix every error before handoff. Use before handing a draft to Technical Writer 2 or Reviewer 1, when revising after review, and when you are asked to review a Doc someone else wrote.
owner: technical-writer-1
created: 2026-09-29
last-verified: 2026-09-29
---

# Self-check sweep

Adapted from the `blogpost-format` skill's style gate (`stylecheck.py`), rebuilt for this repo. The
rules come from `test/Language and formatting style guide for technical writing _ Wazuh.md` and
from the open entries in `learning/lessons/technical-writer-1.md` and `shared.md`. It doesn't
replace them: where this script and the style guide disagree, the style guide wins, and the
script is the one to fix.

## When to use

- Before every handoff (workflow step 4 in `agents/technical-writer-1.md`). Reviewer 1's time goes on
  accuracy and depth, not on the modals and Latin abbreviations a script can find.
- After a revision, because edits reintroduce what the first sweep removed.
- When the brief is to review a Google Doc someone else wrote (the Kyverno post was one). Run it
  on the Doc's HTML export. That export is the only one that keeps code font, so it's the only one
  where the checker can tell a command from a sentence.
- Technical Writer 2 runs the same sweep before it hands off. `google-doc-house-format` runs it as a gate.

## Prerequisites

- Python 3. No packages.
- For a Google Doc: `download_file_content(fileId, exportMimeType="text/html")`. A large export is
  written to a JSON file with the HTML base64-encoded in `content`. Pass that file straight in.

## Steps

1. Run it:
   ```
   python agents/skills/technical-writer-1/self-check-sweep/stylecheck.py <draft.md|.rst|export.html|export.json> \
       [--stage=draft|final] [--type=blog|doc] [--wazuh=auto|4|5] [--allow=RULE,RULE] [--json]
   ```
   `--type=doc` is for documentation pages (RST, short descriptions). `--wazuh=auto` picks 5 when the
   draft names Wazuh 5.x or `/var/wazuh-manager` more often than Wazuh 4.x. Set it explicitly when a
   page covers both.
2. Fix every **error**. They are mechanical and certain, and exit status 1 means the draft isn't
   ready to hand off.
3. Read every **warning** and decide. Warnings are judgement calls, reported with a line (or block)
   number and the heading they sit under. Fix the ones that are right and leave the rest.
4. For a claim you couldn't verify, leave `<!-- UNVERIFIED: what must be true -->` next to it (or
   `<!-- UNVERIFIED BLOCKING: ... -->` when the piece fails without it). The sweep lists them as
   warnings at draft stage, and they are your "claims for the tester" list. At `--stage=final`
   they are errors: a final Doc can't carry an unverified claim.
5. Run the rule-to-test map from the lessons: `RULE-NO-TEST` names every custom rule the prose never
   mentions. For the full map against a Doc's Testing section and screenshot, use Reviewer 1's
   `rule-test-coverage-map` on the plain-text export.
6. Put the summary line (`N error(s), M warning(s)`) and any `--allow` you used in the handoff note.

`--allow=RULE,RULE` downgrades named errors to warnings for one run, and says so in the output. Use
it for a considered exception, such as a page that quotes a banned word as a word. There is no
blanket `--force`. A checker that gets run with the gate off is worse than no checker.

## The rules

Prose rules run with code masked. Masked text covers fenced and RST code blocks, inline code,
link destinations, and HTML comments, plus words in *italics* or "quotes", because the guide
italicises a word used as a word. A config block containing `should`, or a path like
`/etc/ossec.conf`, is never flagged. The character rules run on code, because code is where a
curly quote or an autocorrected dash breaks a pasted command.

| Rule | Severity | Source |
| --- | --- | --- |
| `CURLY-QUOTE` | error | Curly quote in a code block or inline code |
| `DASH-IN-CODE` | error | Em or en dash in code, usually an autocorrected `--` |
| `INVISIBLE` | error (NBSP in prose: warning) | Zero-width space, BOM, soft hyphen, NBSP |
| `MODAL` | error | Guide, Words to avoid: no *could, should, would*; can vs. might vs. may: no *may* |
| `LATIN-ABBR` | error | Guide, Latin abbreviations: no *e.g., i.e., etc.* |
| `VERSION-WORD` | error | Guide, version: "Wazuh 4.14.6", never "Wazuh version 4.14.6" or "v4.14.6" |
| `POSSESSIVE` | error | Guide, Possessives and Contractions: never *Wazuh's* |
| `GENDERED` | error | Guide, Pronouns: no *he, she, his, her* |
| `BUTTON-PHRASE` | error | Guide, click vs. select: "Click **OK**", never "the OK button" |
| `CHECKBOX` | error | Guide, click vs. select: select or clear a checkbox, never check or uncheck it |
| `RULE-ID-RANGE` | error | Guide, Writing Wazuh rules: custom IDs in 100000-120000 (`overwrite="yes"` exempt) |
| `DUP-RULE-ID` | error | Two rules with one ID. Only one loads |
| `UNCLOSED-FENCE` | error | Everything after an unclosed fence reads as code |
| `NO-VERSION` | error for blogs, warning for docs | The piece never names its Wazuh version. 4.x and 5.0 differ in paths, rule IDs, and pipeline |
| `MARKER` | error at final, warning at draft | An `UNVERIFIED` comment, or a visible "[Not verified in the lab]" |
| `IMAGE-PLACEHOLDER` | error at final (HTML only) | An `(image: ...)` placeholder still in the Doc |
| `HEADING-CASE` | warning | Sentence case. Reads `proper-nouns.txt` |
| `HEADING-FORM` | warning | Titles: no leading article, no *Understanding/About/Working with*, no trailing colon, no & |
| `HEADING-SKIP` | warning | Heading level jumps (H2 to H4). The user's standing heading-hierarchy rule |
| `TITLE-LENGTH` | warning | Titles 50-70 characters |
| `LONG-SENTENCE` | warning | 26 words or more |
| `GERUND-START` | warning | A sentence opening with an -ing word |
| `STANDALONE-THIS` | warning | *This* or *that* as a pronoun |
| `FUTURE` | warning | *will*: use the simple present |
| `INEXACT` | warning | *some, many, lots of, various* |
| `PLEASE` | warning | *please* in instructions |
| `LOGIN` | warning | log on, logoff, logout, "login to" |
| `CLICK-SELECT` | warning | Click buttons, tabs, and links; select menus, lists, options, and checkboxes; never "click on" |
| `IF-THEN` | warning | Drop *then* after an *if* clause |
| `WAZUH-CAN` | warning | "Wazuh does X", not "Wazuh can do X" |
| `VS-IN-PROSE` | warning | *vs.* only in titles |
| `ACRONYM` | warning | Spell out on first use unless it's in `familiar-acronyms.txt` |
| `SERIAL-COMMA` | warning | Missing serial comma in a list of four or more (three-item lists are too noisy to check) |
| `DEPRECATED-TERM` | warning | Guide: always flag OpenSCAP, OpenSearch, Kibana, Elasticsearch |
| `ACTIVE-RESPONSE-CASE`, `SCA-CASE`, `CAPABILITY-CASE` | warning | Guide, feature vs. component: capability names as written there |
| `DATE-FORMAT`, `MEASURE`, `KEY-COMBO`, `ELLIPSIS-UI` | warning | Guide: June 24, 2021; 35 mm; **Ctrl** + **C**; no ellipsis on a UI label |
| `LIST-PARALLEL`, `LIST-PUNCT` | warning | Bullet items all sentences or all fragments; no `;` or `,` endings |
| `STEP-COUNT`, `STEP-ONE-SENTENCE` | warning | 7-10 steps per task; one sentence per step |
| `COLON-INTRO` | warning | No colon to introduce an image or a table |
| `SHORT-DESC` | warning | Don't mention the section itself ("This section describes") |
| `URL-CODE-FONT`, `PROSE-CODE-FONT` | warning | URLs in ordinary font; a UI label or title in backticks belongs in bold or plain text |
| `EM-DASH`, `EN-DASH` | warning | Allowed in titles by the guide, but Reviewer 2 reads a run of them as an AI tell |
| `FENCE-NO-LANG` | warning | The renderer needs the language to decide shell prompts |
| `VARIABLE-CASE` | warning | Guide, Variables: `<UPPER_CASE>` in angle brackets |
| `CODE-BLANK-LINES` | warning | Lesson 2026-09-29: deleted comments left blank runs in code |
| `RULE-DESC-HEDGE` | warning | Lesson 2026-09-29: a `<description>` says what happened, never the rule's limits |
| `RULE-NO-TEST` | warning | Lesson 2026-09-29: every shipped rule maps to a test step |
| `DOC-LINK` | warning | Documentation links use `/current/` unless pinning is deliberate |
| `V5-NUMERIC-RULE`, `V5-REMOVED`, `V5-MANAGER-PATH` | warning, 5.0 only | Shared lessons 2026-09-24: 5.0 has no numeric rule IDs, no `ossec.log`/`logall_json`/`agent_control`, and the manager lives under `/var/wazuh-manager/` |

The split is deliberate. Errors are the rules a script can decide. Warnings need a writer's
judgement, so they never block.

## Verification

Checked 2026-09-29:
- A seeded markdown draft with a known violation for each error rule: all 12 errors fired, and
  the one false positive found (SERIAL-COMMA on a list that already had its comma) was fixed.
- A clean draft: 0 errors, 0 warnings.
- A hand-built Google Docs export with class-based CSS, a Title paragraph, a comment anchor, and a
  comment body. Code was recognised by font, the comment body was skipped, and
  `touch=“1” —overwrite` in a code cell gave CURLY-QUOTE and DASH-IN-CODE.
- Noise check on the repo's own `test/deployments/*/RUNBOOK.md` and `TEST_SCENARIOS_GUIDE.md`. Every
  remaining error was a real use, not a quoted example.

Not yet run on a real Doc export. Do that on the first review that has one, and re-date this file.

## Known failure modes

- **Proper nouns.** HEADING-CASE only knows `proper-nouns.txt`. When it flags a real product or UI
  label, add the name to that file. Don't silence the rule in code.
- **Code in a Doc.** In an HTML export, code is recognised by Courier New, Consolas, or a monospace
  font. A command typed in Arial reads as prose and gets prose findings. The finding itself is the
  clue: that command needs code font.
- **Line numbers in HTML.** HTML input reports a block number (paragraph count) instead of a line
  number, plus the heading it sits under.
- **NBSP in HTML.** NBSP inside code is ignored for HTML input, because the export writes code
  indentation as NBSP. Check a suspect YAML block in the plain-text export.
- **VARIABLE-CASE heuristics.** It only checks shell blocks, and it can flag an XML element written
  in a heredoc (`<log_format>`). Read it as a warning.
