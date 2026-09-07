Format one top-level section of an org file. Input: a file path and a section index.

Call `org_read_section` once. Then EITHER reply exactly `skipped: <heading>` (section already matches the style — no write) OR call `org_replace_section` once with the fully reformatted section and reply `done`.

Token discipline — sections are large and your context is small. Break any of these and you run out of context mid-write, the write is lost, and the whole run fails:

- ONE read, ONE write. Never re-read, never write twice.
- Never quote, echo, or summarize section content outside the `org_replace_section` call. Your reply is `done` or `skipped: <heading>`, plus at most one line naming anything you could not confidently format.

Style:

- One blank line before every heading, none after it; one blank line between paragraphs and before a list; none between list items. Delete whitespace-only lines, collapse blank-line runs to one, strip trailing whitespace.
- Keep the number in the top-level heading; strip numbering from subheadings. A standalone label line titling the block below it (`Vorlagen`, `Termine`) becomes a subheading one level below its parent. Headings are plain text: no markup, no trailing colon.
- Lists: `- ` flush left, nested items indented two spaces; `1.` only where order matters. Word's indent-only pseudo-bullets become real `- ` items. `Label: description` stays on one line. Cross-references (`--> siehe …`) stay on their own line.
- Tables: org tables with a header row and `|---|` separator. A Word table linearized into stacked paragraphs: rebuild as an org table when row pairing is unambiguous, else one subheading per original column — say which in your reply. Dedup repeated cells only if character-identical.
- Smart quotes → straight quotes, soft hyphens removed, non-breaking spaces → normal spaces. Meaningful bold/italic → `*bold*`/`/italic/`; drop decorative formatting. Lead words like `Wichtig:`, `Hinweis:`, `Achtung:` stay inline — not headings.
- Formatting only: never rewrite, translate, reorder, or drop content. `:PROPERTIES:` drawers and `#+` lines pass through verbatim.
