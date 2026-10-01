---
name: google-doc-house-format
description: Turn one or many markdown drafts into Google Docs that already look like a Wazuh blog post (code and note tables, Courier New on #cfe2f3, shell prompts on commands only, measured heading and spacing), after gating each file through self-check-sweep. Then audit the Doc's HTML export against the same spec. Use when generating the Doc for a draft, when a Doc came out unformatted, or when reviewing the formatting of a Doc someone else produced.
owner: technical-writer-2
created: 2026-09-29
last-verified: 2026-09-29
---

# Google Doc house format

Adapted from the `blogpost-format` skill. Its three scripts and its `format.md` spec aren't in this
repo, so the pieces are rebuilt here in plain Python (no pandoc) with the spec written into
`render.py`. The formatting findings it records were measured by uploading probes and exporting
them (2026-08-28 and 2026-08-31) and are kept below.

| File | Does |
| --- | --- |
| `render.py` | The one to run. Gates each file through `stylecheck.py`, renders house HTML, names it, picks the folder, and writes one manifest |
| `check_export.py` | Audits a Doc's HTML export: the counts that show whether the format took, plus autocorrect damage |
| `../../technical-writer-1/self-check-sweep/stylecheck.py` | The wording gate (Writer 1's skill; the renderer imports it) |

## Why this exists

The Drive connector's `create_file` with `contentMimeType: text/markdown` gets headings, bold, lists,
tables, and links right. It gets everything distinctive about a Wazuh post wrong: code blocks land
as bare monospace paragraphs, notes as ordinary paragraphs, and every square bracket arrives
escaped as `\[...\]`. **Upload HTML instead.** The Docs importer builds a real table from an HTML
table and honours inline styles.

It also helps review. Reviewers judge headings and inline formatting from the HTML export (see
`agents/document-reviewer-1.md`, "Reading a Google Doc draft"). A Doc that already matches the
house format moves their findings from formatting to substance. `check_export.py` turns "does
this Doc look right" into counts.

## Run it

```
python agents/skills/technical-writer-2/google-doc-house-format/render.py [<inputs...>] \
    [--stage=auto|research|draft|final] [--markers=auto|visible|strip|keep] \
    [--allow=RULE,RULE] [--type=blog|doc] [--date=YYYY-MM-DD] [--out=DIR] [--dry-run]
```

Inputs are files, directories, or globs. A directory is walked for `.md`, skipping `learning/`,
`agents/`, `terraform/`, `deployments/`, and review files (`review-1.md`, `review-2.md`, `README.md`).
Otherwise a walk of `results/` would make a Doc out of every review. With no inputs, it formats
every draft under `results/`.

It writes `<out>/<stage>/<slug>/<slug>.html` per file, plus `<out>/manifest.json`, and exits 1 if
anything was blocked. `<out>` defaults to `$CLAUDE_SCRATCHPAD/google-doc-house-format`, or the
system temp directory. A render is disposable and never enters the repo. The markdown is the
source of truth.

**Run `render.py`, not the render function on its own.** The gate is the point: a markdown fix
costs one edit, but the same fix after a Doc's link is shared costs a human pasting into a live
Doc. The Drive tools here can't edit an existing Doc body, and regenerating breaks every shared
link and drops the comment threads.

`--stage` decides the folder, the title, and the marker default. `auto` reads it from the filename:
`research*.md` is research, anything else is a draft. A final is never inferred, because a Doc in
**To be published** is the deliverable, and putting it there is a decision somebody made.

| Stage | Folder (verified 2026-09-29) | Doc title | Markers |
| --- | --- | --- | --- |
| `research` | Claude > Blog posts > Research, `1q5N-btqb9vvWsOtz54PShKSWCeQMRUQ-` | `Research report: <title> (YYYY-MM-DD)` | visible |
| `draft` | Claude > Blog posts, `1HVVSy2PKjWQiL0siyuIgDkvOz3IAGZow` | `<title> (draft, YYYY-MM-DD)` | visible |
| `final` | Claude > Blog posts > To be published, `1PC7Gk1nJh-zYxn9DnDxeMyvhM6_znXSp` | `<title>` | strip |

At `final`, the gate also turns every `<!-- UNVERIFIED -->` marker into an error. A final Doc
can't present an unrun claim as settled.

`--markers` decides what happens to those comments. They're invisible in markdown and would
import as literal text:

| Mode | Renders as | Use at |
| --- | --- | --- |
| `visible` | **[Not verified in the lab]**, or **[Blocking, not verified in the lab]** | draft and research Docs, before the tester has run |
| `strip` | removed | final, after the tester closes the loop |
| `keep` | left as HTML comments | debugging only |

A reviewer reading only the Doc can't see a markdown comment. A draft built with `strip` presents
unrun claims as settled, so `auto` keeps them visible.

## Upload it

1. For each row of the manifest with `"ready": true`, read the row's `html` file and make one
   `create_file` call: `textContent` = the HTML, `contentMimeType: text/html`, `parentId` = the row's
   `folder_id`, and `title` = the row's `doc_title`. The driver has decided all three.
2. **Never upload the markdown.** See "Why this exists".
3. If the upload closes the socket, run `search_files` on the target folder before retrying. A
   failed call can still leave a file behind, and a blind retry creates a duplicate.
4. Put the Doc in the right folder on the first upload. The folder is the stage marker. `update_file`
   can change a Doc's `parentId` later, but a Doc that sat in the wrong folder has already told
   people it was at the wrong stage.
5. Give the Doc URL to the Security Manager in the handoff, and write it at the top of the draft's
   review file in `results/` so both reviewers open the same Doc.
6. Promotion out of Claude > Blog posts is a human step. A final Doc joins the team's own
   published folder by being dragged there, which keeps the URL, the comments, and the history.

## Check the Doc you just uploaded

Don't hand a Doc over on the strength of the HTML that went into it. Export it and read what
came back:

```
download_file_content(fileId, exportMimeType="text/html")
python agents/skills/technical-writer-2/google-doc-house-format/check_export.py <export.json|.html> [--stage=draft|final]
python agents/skills/technical-writer-1/self-check-sweep/stylecheck.py <export.json|.html> [--stage=draft|final]
```

A real post's export is too large to return inline, so it's written to a file, and both scripts
read that JSON directly (base64 `content`). Export styles live in CSS classes, and the script
resolves every element through the `<style>` block before counting.

| Check | Should be | Catches |
| --- | --- | --- |
| bold headings | 0 | `font-weight` set on the heading element, which the importer drops |
| heading sizes | 0 wrong | the importer's own 24pt `h1` and 18pt `h2` |
| Title style set | 1 | manual step 1 still open |
| browser-blue links | 0 | links falling back to `#0000ee` |
| justified body paragraphs | all | the body style not applying |
| centred captions | all | `Fig. N:` captions left-aligned |
| code lines inside a table | 0 outside | code as bare monospace paragraphs (a markdown upload) |
| code shading, inline code shading | all | `#cfe2f3` dropped |
| autocorrect damage in code | 0 | curly quotes or dashes typed into a command after upload |
| escaped square brackets | 0 | `\[...\]`, the tell of a markdown upload |
| image placeholders, unverified markers | 0 at final | manual step 2, or an unverified claim, still open |

The export lower-cases `font-family` to `courier new` whatever the input said. That's the
exporter, not a defect, so don't chase it.

**Reviewing a Doc you didn't make:** run both scripts on its export, the same way. A failed format
check, or autocorrect damage in a command, is a must-fix. A reader copies that command.

## What the renderer does, and why each part isn't obvious

- **Code blocks become single-cell tables.** 1pt solid `#000000` on all four sides, 468pt (6.5 in)
  fixed width, 5pt padding, Courier New 11pt at single spacing. Each line is its own paragraph in
  the cell. A run of `<br>` in one paragraph looks the same until a page break, where it can't split
  and Docs pushes the whole block to the next page.
- **Code sits on pale blue.** `#cfe2f3` goes on a span, both in blocks and on inline code, because
  the house format shades the characters, not the box. On the paragraph, the blue would run to the
  cell edge.
- **Headings and spacing are written out.** The importer doesn't apply the named heading styles,
  and it stamps its own 24pt bold on an `h1`. Sizes follow the Google Docs defaults (Title 26, H1 20,
  H2 16, H3 14pt, regular weight). `font-weight` goes on a span, because only there does it survive.
  Space before and after uses `padding`, because `margin-top` doesn't import. `# Title` then
  `## Section` maps to Title then H1 (the Title > H1 > H2 nesting Reviewer 1 confirmed on the
  Kyverno Doc).
- **Body text is justified at 10pt after; captions are centred.** A table or figure is held 20pt
  off the text below it.
- **A title in backticks loses the code font.** Code font is for paths, files, commands, and
  variables, so a capitalised phrase with a space in it renders plain. `stylecheck` reports it as
  `PROSE-CODE-FONT` so the markdown gets fixed too.
- **Leading spaces become `&nbsp;`.** HTML collapses whitespace, and indentation in XML and YAML is
  load bearing.
- **One font family, no fallback list.** `'Courier New', monospace` imports as plain Courier.
- **Shell prompts go on commands only.** `# ` goes on `bash`/`sh`/`shell`/`console` lines, and `> `
  on PowerShell and cmd. There's no prompt on: a line already starting `#`, `$`, `>`, or `PS`; a
  line continued from a trailing `\` (or a PowerShell backtick); a heredoc body; or a block that
  shows file content. File content is a fence marked `bash file` (or `noprompt`), or a block
  directly under a lone inline-code path line, the house structure for "save this file". Force a
  prompt with `bash prompt`. A prompt on a script the reader must save corrupts it silently.
- **A figure caption is split into its own paragraph.** `(image: ...)` and `Fig. N: ...` on
  consecutive lines are one paragraph to markdown.
- **Notes become the same table in body font.** A paragraph or blockquote starting
  `Note:`/`Warning:`/`Caution:`/`Important:` (bold or not) becomes a single-cell table in Arial 11pt,
  with the label in bold. A code block and a note differ only in font, so the opening word is what
  tells them apart.
- **Numbered lists resume.** A numbered list broken by a code block restarts with
  `<ol start="N">`, taken from the markdown number.
- **Links are `#1155cc` and underlined**, the Docs default, so they don't import as browser blue.

## What is still manual, and why

`render.py` prints these after every run. They're not oversights.

1. **Set the title to the Title style.** No HTML element maps to it. It arrives as a 26pt Heading 1.
2. **Place the screenshots and their captions.** The markdown has only an `(image: ...)`
   placeholder saying what the screenshot must prove. Take it from one clean run with the time
   filter set to that run, showing every rule ID the Testing section claims (writer lesson,
   2026-09-29).
3. **Turn autocorrect off** (Tools > Preferences) before anyone edits. Docs turns `--` into an em
   dash and straight quotes into curly ones as people type. `check_export.py` catches the damage.

## Verified, and not

Measured by the source skill, by uploading probes and exporting them:
- 2026-08-28: borders import as 1pt solid `#000000`, and cell width as 468pt. Courier New and Arial
  survive at the sizes given. Bold survives in a cell, and so does `&nbsp;` indentation. Square
  brackets arrive clean.
- 2026-08-31: `padding-top`/`padding-bottom` become space before/after, and `margin-top` doesn't.
  Inline heading `font-size` and `color` survive. `font-weight` survives on a span, not on the
  heading. A bare `h1` imports at 24pt bold and `h2` at 18pt bold. Cell padding survives. Multiple
  paragraphs in a cell stay separate.

Checked here, 2026-09-29, locally:
- `render.py` on a sample with a table, a note, a figure and caption, a numbered list broken by a
  code block, a bash continuation, a heredoc, a PowerShell backtick continuation, a file-content
  block, and an UNVERIFIED marker. The prompts, continuations, heredoc, file-content handling,
  `start="2"`, and centred caption were all correct.
- `check_export.py` on that render passed every check except "Title style set" (expected: manual
  step 1). On a hand-built class-based Docs export, it caught a bold heading, a stray monospace
  paragraph, unshaded code, and `“1” —overwrite` in a code cell.
- The gate blocked a seeded bad draft (12 errors), and `--stage=final` blocked a draft with an open
  UNVERIFIED marker.

Not verified: the Google Docs importer's handling of `<ol start>` and of `margin-top` on a table,
the Arial label bolding in notes, how a code table paginates across a page break, and this
renderer's output through a real upload and export. Before the first real use, upload one probe
to the **draft** folder, run `check_export.py` on its export, trash the probe, and re-date this
file.

## Handing over

Say which of the three manual steps are still open, and paste the `check_export.py` summary. A
Doc handed over as "formatted" while its title is still a Heading 1, and its figures are still
placeholders, isn't formatted. The next person can't tell what was skipped on purpose.
