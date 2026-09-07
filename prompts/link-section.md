Add backlinks to one top-level section of an org file. Input: a file path, a section index, and a candidate list of related nodes (`Title | id:UUID`).

1. `org_read_section` with the given index.
2. Find mentions of the candidate nodes in the body: the title itself or a close variant (plural, abbreviation, obvious synonym). For a phrase that clearly names a note but is on no candidate line, you may verify it with `org-roam_resolve_ref` — otherwise do not search; the list is your ground truth. Only link on a confident match — when in doubt, leave the text alone. Never create nodes, never invent IDs.
3. Rewrite the section body, wrapping the existing phrase in place: `[[id:UUID][phrase as written]]`.
   - Link only the first mention of each node in the section, in body text only — never inside headings, existing `[[…]]` links, `:PROPERTIES:` drawers, `#+` keyword lines, or code/example blocks.
   - Linking only — never rewrite, reorder, or drop content; the text must read identically.
4. If any link was added, `org_replace_section` with the result. Reply "done" plus a list of the links added (`phrase → Title`), or "done, no links" if none.
