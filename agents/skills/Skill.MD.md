---
name: blogpost-format
description: Turn one or many markdown files into correctly formatted Google Docs, matching the visual spec in format.md - code and note tables, Courier New, shell prompts, borders - after checking each file against the writing rules. Use when generating the Doc for a blog post, when formatting a batch of .md files, when a Doc came out unformatted, or when asked to apply the house format.
---

# Blog format

Input: one or many markdown files, `blog-posts/posts/<slug>/draft.md` by
default. Output: a Google Doc per file that already looks like a Wazuh blog
post, plus the short list of what a human still has to do by hand.

The spec is `blog-posts/format.md`, measured from
`blog-posts/Managing shadow IT with Wazuh.docx`. Read it. This skill implements
it; it does not replace it, and where the two disagree the spec wins.

## Why this exists

The old route was `create_file` with `contentMimeType: text/markdown`, which
gets headings, bold, lists, tables, and links right and gets everything
distinctive about a Wazuh post wrong. Code blocks land as bare monospace
paragraphs, notes as ordinary paragraphs, and every square bracket arrives
escaped as `\[...\]`. That left seven manual repairs on a 40-block post,
repeated on every regeneration.

**Upload HTML instead.** The Docs importer builds a real Doc table from an HTML
table and honors inline styles on the elements. That reaches four of the seven,
including the two that dominate the work.

## Three pieces

| File | Does |
| --- | --- |
| `batch.py` | The one to run. Gate, render, name, file, one manifest |
| `stylecheck.py` | The writing rules, read off the markdown. Blocks a bad render |
| `format.py` | The renderer. One file to one HTML body, per `format.md` |

## Run it

```
python blog-posts/.claude/skills/blogpost-format/batch.py [<inputs...>] \
    [--stage=auto|draft|final|research] [--markers=auto|visible|strip|keep] \
    [--allow=RULE,RULE] [--date=YYYY-MM-DD] [--dry-run]
```

Inputs are files, directories, or globs. A directory is walked for `.md`,
skipping `report/`, `lab/`, `.claude/`, and the pipeline's own bookkeeping
(`changelog.md`, `doc.md`, `pipeline.md`, and the rest), because a walk that
swept those up would generate a Doc per changelog. With no inputs at all it
formats every draft under `blog-posts/posts/`.

Writes one `<scratchpad>/blogpost-format/<duty>/<slug>/<slug>.html` per file,
plus `<scratchpad>/blogpost-format/manifest.json`. Exits 1 if anything was
blocked.

A render is disposable and never enters the repo. Once the Doc exists the HTML
has no further use, and the markdown it came from is the source of truth. The
scratchpad is `$CLAUDE_SCRATCHPAD` when the session sets it, and the system temp
directory otherwise. Upload from the path the run prints.
Requires pandoc on PATH.

**Run `batch.py`, not `format.py`.** The renderer knows nothing about whether
the markdown was fit to render, where the Doc goes, or what it is called. Going
around the driver skips the gate.

`--stage` decides the folder, the title suffix, and the marker default.
`auto` reads it from the filename: a `research-brief.md` is research, anything
else is a draft. A final is never inferred, because a Doc in **To be published**
is the deliverable and that has to be a decision somebody made.

| Stage | Folder | Doc title | Markers |
| --- | --- | --- | --- |
| `research` | Blog posts > Research | `Research report: <title> (YYYY-MM-DD)` | visible |
| `draft` | Blog posts | `<title> (draft, YYYY-MM-DD)` | visible |
| `final` | Blog posts > To be published | `<title>` | strip |

## The gate

`stylecheck.py` runs on every file before it is rendered. Errors block the
render. Warnings are recorded in the manifest and never block.

```
python blog-posts/.claude/skills/blogpost-format/stylecheck.py <file.md> \
    [--stage=...] [--allow=RULE,RULE] [--json]
```

**Why it blocks rather than warns.** A markdown fix costs one edit. The same fix
after a Doc's link has been shared costs a human pasting a passage into a live
Doc, because nothing can write into an existing Doc body and regenerating breaks
every shared link and drops the comment threads. See `Limitation.md`. So the
cheapest moment to catch a rule is before the render, and that is the only
moment this stage owns.

| Rule | Severity | From |
| --- | --- | --- |
| `EM-DASH` | error | `CLAUDE.md`, the override |
| `CURLY-QUOTE` | error | Straight quotes in anything copyable |
| `INVISIBLE` | error | Non-breaking space, zero-width space, BOM |
| `LATIN-ABBR` | error | Style guide, Latin abbreviations |
| `MODAL` | error | No could, should, would, or may |
| `VERSION-WORD` | error | Style guide, version. No `v` prefix, no "version 4.1.5" |
| `DOC-LINK` | error | Documentation links use `/current/` |
| `NO-VERSION` | error | Every piece states its Wazuh version |
| `BUTTON-PHRASE` | error | Never "the OK button", never check a checkbox |
| `UNCLOSED-FENCE` | error | The renderer stops on one |
| `MARKER` | error at `final` | An unverified claim cannot reach a final Doc |
| `EN-DASH` | warning | The override, by extension |
| `LONG-SENTENCE` | warning | Under 26 words |
| `HEADING-CASE` | warning | Sentence case |
| `PLEASE` | warning | Style guide, please |
| `STANDALONE-THIS` | warning | No bare *this* or *that* |
| `CLICK-SELECT` | warning | Click buttons, select menus |
| `VARIABLE-CASE` | warning | `<UPPER_CASE>` in angle brackets |
| `URL-CODE-FONT` | warning | No code font on a URL |
| `FENCE-NO-LANG` | warning | The renderer needs the language |

The split is deliberate. Errors are mechanical and certain; warnings are
judgement and are reported with a line number for a human to settle. A checker
that cries wolf gets run with the gate disabled, which is worse than no checker.

**Prose rules do not read code.** Fenced blocks, inline spans, link
destinations, and the drafter's HTML comments are masked before any wording rule
runs, so a config block containing "should", or a path like `/etc/ossec.conf`,
is not flagged. The three character rules run on everything, because those break
a command in the one place it has to survive verbatim.

`--allow=RULE,RULE` downgrades named rules to warnings for one run. It names
what it waives so the log distinguishes a considered exception from a bypassed
gate. There is no blanket `--force`, on purpose.

`HEADING-CASE` reads `proper-nouns.txt` beside the script. A product name
flagged there is added to that file, not silenced in code. It also stops at the
`SM Texts` heading: the style guide puts marketing content in title case, and
the social copy is marketing content.

## Render one file

`format.py` is still callable on its own, for the case where the gate has
already run and only the render is wanted.

```
python blog-posts/.claude/skills/blogpost-format/format.py \
    blog-posts/posts/<slug>/draft.md <slug> [--markers=visible|strip|keep]
```

`--markers` decides what happens to the `<!-- UNVERIFIED -->` comments the
drafter left. They are invisible in markdown and import as literal text, so they
cannot simply be passed through.

| Mode | Renders as | Use at |
| --- | --- | --- |
| `visible` (default) | **[Not verified in the lab]**, and **[Blocking, not verified in the lab]** for a blocking one | the draft Doc, before the lab |
| `strip` | removed entirely | the final Doc, after the loop closes |
| `keep` | left as HTML comments, invisible in the Doc | never, unless debugging |

A reviewer reading the Doc alone cannot see a markdown comment, so a draft Doc
built with `strip` presents unrun claims as settled. Default to `visible`.

## Upload it

One `create_file` call per ready row of the manifest. Read the row's `html` and
pass it as `textContent` with `contentMimeType: text/html`, into the row's
`folder_id`, titled with its `doc_title`. The driver has already decided all
three, so the call has nothing left to work out.

Nothing here talks to Drive itself. The connector lives in the session, not in a
subprocess, which is why the driver stops at a manifest.

**Do not upload the markdown.** Markdown import cannot produce a table, so every
code block and every note arrives as a plain paragraph and every square bracket
arrives escaped as `\[...\]`. That is the whole reason this stage exists.

Everything this workspace creates in Drive goes under **2026 > Claude**, one
subfolder per duty. Nothing is written anywhere else, so nothing ends up
scattered across the shared drive.

- **Research report**, at research time: **Claude > Blog posts > Research**
  (`1q5N-btqb9vvWsOtz54PShKSWCeQMRUQ-`), titled
  `Research report: <Working title> (YYYY-MM-DD)`.
- **Draft Doc**, at create time: the **Claude > Blog posts** root
  (`1HVVSy2PKjWQiL0siyuIgDkvOz3IAGZow`), titled
  `<Post title> (draft, YYYY-MM-DD)`.
- **Final Doc**, at validate: **Claude > Blog posts > To be published**
  (`1PC7Gk1nJh-zYxn9DnDxeMyvhM6_znXSp`), titled exactly the post title, with no
  date suffix. That is what marks it as the deliverable rather than a draft.

The folder a Doc sits in is the stage it is at, so put it in the right one on
the first upload. Nothing can be moved afterwards.

Record the URL in `blog-posts/posts/<slug>/doc.md`.

**Promotion out of Claude is a human step.** The team's own
`2026 > Blog posts` folder holds published work, and a final Doc joins it by
being dragged there, which keeps the URL, the comments, and the history. Do not
regenerate a Doc into that folder: see *Cannot move* in `Limitation.md`.

If the upload closes the socket, check the target folder with `search_files`
before retrying. A failed call can still leave a file behind, and a blind retry
then creates a duplicate. See `Limitation.md`.

## What the script does, and why each part is not obvious

**Code blocks become single-cell tables.** One column, one row, 1pt solid
`#000000` on all four sides, 6.5 in fixed, 5pt padding, Courier New 11pt at
single line spacing. Every line is its own paragraph in the cell, which is how
the reference holds them: one cell there carries 630 paragraphs. A run of `<br>`
inside one paragraph looks the same until a page break, where it cannot split
and Docs pushes the whole block to the next page.

**Headings and paragraph spacing are written out.** The importer does not apply
the named heading styles, it stamps its own 24pt bold on an `<h1>`, and it gives
imported paragraphs no spacing at all. Both are corrected inline, per the
measured spec in `format.md`.

**Code sits on pale blue.** `#cfe2f3` behind the glyphs, both in a block and on
an inline code span in running prose. It goes on a span rather than on the
paragraph, because the reference shades the characters and not the box: put it
on the paragraph and the blue runs to the right edge of the cell instead of
stopping with the text.

**Body text is justified, captions are centred.** `jc=both` on the body,
`jc=center` on every figure caption.

**A table or a figure is held 20pt off the text below it**, against the 10pt any
two paragraphs get. The one number in the spec that is not measured off the
reference; see `format.md` for why it departs.

**A title in backticks loses the code font.** Code font is for paths,
filenames, commands, and variables, so a capitalised phrase with a space in it
renders as plain text. `stylecheck` reports each one under `PROSE-CODE-FONT` so
the markdown gets fixed too, rather than only the Doc.

**Leading spaces become `&nbsp;`.** HTML collapses runs of whitespace, and the
indentation in an XML or YAML block is load bearing. A reader who copies a
flattened block gets a file that does not parse.

**Neither font carries a fallback list.** Confirmed 2026-08-28: `'Courier New',
monospace` imports as plain **Courier**, not Courier New. A single family name,
quoted or unquoted, imports as itself. Do not add a fallback back in.

**Shell prompts go on commands only, never on file content.** A block is
commands when its language is a shell language *and* the nearest preceding
non-empty line is not a lone inline-code path. The house structure puts the file
path immediately above a block that shows what a file should contain, so that
line is the only signal separating a script from the commands that run it.
Prefixing `> ` onto every line of a script the reader has to save would corrupt
it, silently, in the one place a reader copies verbatim.

**A continued line gets no prompt.** A command wrapped over two lines with a
trailing backslash, or a backtick in PowerShell, is one command. Prompting the
second half turns a working paste into a syntax error, in the one place a reader
copies verbatim.

**A figure caption is split into its own paragraph.** The draft writes the
`(image: ...)` placeholder and its `Fig. N: ` caption on consecutive lines,
which markdown reads as a single paragraph. format.md wants the caption
directly beneath the image as its own paragraph.

**Notes and warnings become the same table in body font.** Arial 11pt, opening
`Note: ` or `Warning: `. A code block and a note are identical apart from the
font, so the opening word is what tells them apart. `format.md` defines Note
only; Warning, Caution, and Important are carried on the same pattern because
drafts use them and a warning rendered as a bare paragraph stops looking like a
warning.

**Slack shortcodes stay as shortcodes.** pandoc would turn `:blue_heart:` into
the emoji character, which is wrong twice over: the SM Texts are copy for Slack
and Discord, where the shortcode is what gets pasted, and the character itself
arrives mojibaked through the HTML upload. The reader runs with `-emoji`.

**Banned characters fail the run.** An em dash or a curly quote stops the render
rather than travelling into a Doc, where autocorrect will add more.

## What is still manual, and why

The script prints these after every run. They are not oversights.

1. **Set the post title to Title style.** No HTML element maps to it. The
   importer makes the first `h1` a Heading 1, which is 24pt bold rather than
   26pt regular.
2. **Place the screenshots and their captions.** There is no image in the
   markdown to place, only an `(image: ...)` placeholder describing what the
   screenshot must prove.
3. **Turn autocorrect off**, Tools > Preferences, before anyone edits. Docs
   converts `--` to an em dash and straight quotes to curly ones as people type,
   which breaks the no-em-dash rule and any command a reader copies.

## Verified, and not

Confirmed 2026-08-28 by uploading a sample and exporting the result:

- Table borders import as 1pt solid `#000000` on all four sides
- Cell width imports as 468pt, which is exactly 6.5 in
- Courier New and Arial both survive, at the sizes given
- Bold survives inside a table cell
- `&nbsp;` indentation survives
- Square brackets arrive clean, with none of the `\[...\]` escaping that
  markdown import produces

Confirmed 2026-08-31, by uploading three probes and exporting each as HTML:

- `padding-top` and `padding-bottom` on a paragraph both arrive as space before
  and space after. **`margin-top` does not**, though `margin-bottom` does, so a
  paragraph spaced with `margin` alone comes out lopsided
- Heading `font-size` and `color` set inline both survive
- Heading `font-weight` set on the element does **not** survive. On a `span`
  wrapping the text it does
- A bare `<h1>` arrives at 24pt bold, an `<h2>` at 18pt bold. The importer does
  not apply the document's named heading styles
- Cell padding arrives as given, 5pt on each side
- Multiple paragraphs inside one cell stay separate paragraphs

Not confirmed, because an export cannot show it: how a code table paginates
across a page break. That is the reason for one paragraph per line, so it is
worth an eye on the first long post.

## Check the Doc you just uploaded

Do not hand a Doc over on the strength of the HTML that went into it. Export it
and read what came back.

```
download_file_content(fileId, exportMimeType="text/html")
```

A real post's export is too large to return inline, so it is written to a file
and the path comes back instead. That is the useful case, not a failure: decode
the `content` field, which is base64, and count what matters.

```python
import json, base64, re
d = json.load(open(PATH, encoding="utf-8"))
h = base64.b64decode(d["content"]).decode("utf-8")
```

Four counts settle whether the format took, and each has a known failure it
catches:

| Count | Should be | Catches |
| --- | --- | --- |
| `font-weight:700...font-size:(20\|16\|14)pt` | **zero** | headings importing bold |
| `color:#0000ee` | **zero** | links falling back to browser blue |
| `text-align:justify` | one per body paragraph | the stylesheet not applying |
| `background-color:#cfe2f3` | one per code line and inline span | shading dropped |

The export lower-cases `font-family` to `courier new` whatever the input says,
in every construct tested. That one is an artifact of the exporter, not a
defect, so do not chase it.

## Handing over

Say which of the three manual steps are outstanding. A Doc handed over as
"formatted" while its title is still Heading 1 and its figures are still
parenthesised placeholders is not formatted, and the next person cannot tell
what was skipped deliberately.
