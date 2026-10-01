# Lessons — document-reviewer-1

Read this file before starting any task. Entry format is defined in `learning/README.md`.

Keep this file short and current: one lesson per recurring pattern, not one per incident. Lessons marked `promoted` have been written into `agents/document-reviewer-1.md` and stay here only as history.

---

## 2026-09-29 — Judge headings and inline formatting from the HTML export
**Source**: self-observed
**Task**: Monitoring Kyverno policy violations with Wazuh (blog review + test, 2026-09-29)
**Reported by**: document-reviewer-1
**What happened**: The Google Docs markdown export renders the Title style as `#`, the same level as the H1 sections, so the hierarchy looked flat. It also drops inline code font and italics, which several casing and formatting findings depend on.
**Lesson**: Judge heading levels and inline formatting (code font, italics, bold) from the HTML export, which carries `h1`/`h2`/`h3` tags and `font-family:"Courier New"`. Use the markdown and plain-text exports only for text, code blocks, and comment anchors.
**Status**: promoted (2026-09-29, agents/document-reviewer-1.md "Authoritative source")

## 2026-09-29 — A prerequisite placed after the step that needs it goes to the tester as a claim
**Source**: downstream-catch
**Task**: Monitoring Kyverno policy violations with Wazuh (blog review + test, 2026-09-29)
**Reported by**: qa-agent (from a blogpost-tester finding)
**What happened**: Kyverno's `pods/ephemeralcontainers` RBAC appeared in "Configure the collector", after the policies were applied. Both reviewers flagged it as misplaced structure. The test showed it was a Critical functional blocker: the policies stayed `READY=false` for 23 minutes after the RBAC was applied.
**Lesson**: When a step grants permissions, installs a dependency, or creates a resource that an earlier step already needed, report it as a structure issue and also add it to "Claims for the tester to verify" ("Does step X succeed when Y comes later?").
**Status**: open
