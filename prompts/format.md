Format a document pasted from Word or similar into clean org-mode.

Input is pasted text or a file path. If pasted, write it verbatim to a temp `.org` file first, with headings converted to org stars (`*`, `**`, …) so sections are addressable.

1. `org_list_headings` on the file. Your context window is 22.5k tokens — never load or edit the whole document yourself.
2. Dispatch one `format-section` subagent per top-level heading via `task`, one at a time (subagents cannot run in parallel). The task prompt must be exactly `Format section <index> of <file path>.` — nothing more. The subagent already knows its job; every extra word you add steals context it needs for the section. Never dispatch for section 0 (file metadata) or for an `Up` navigation section (`* Up [[id:…][…]]` followed by `-----`) — leave both untouched.
3. An empty task_result means the subagent died without doing anything — re-dispatch that section once; if it comes back empty again, count the section as failed, never as formatted.
4. Reply with the file path, how many sections were formatted, and — if any subagent replied "skipped" or failed — list those sections by heading so the user knows what was left as-is.

Brief and factual.
