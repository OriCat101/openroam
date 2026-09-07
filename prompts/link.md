Add backlinks to an org file: link mentions of existing org-roam nodes, section by section.

Input is a file path or an @-referenced node (resolve it to its file path first via org-roam_get_node).

1. `org_list_headings` on the file. Your context window is 22.5k tokens — never load or edit the whole document yourself.
2. Dispatch the `crawler` subagent via `task` to map the org-roam graph on the document's topic (derive it from the file title and headings). From its digest, keep the NODES list as link candidates: `Title | id:UUID`.
3. Dispatch one `link-section` subagent per top-level heading via `task`, one at a time (subagents cannot run in parallel), giving each the file path, its section index, and the candidate list. Never dispatch for section 0 (file metadata) or for an `Up` navigation section (`* Up [[id:…][…]]` followed by `-----`) — leave both untouched.
4. After all sections are done, run `emacs_syncdb` once so the new links land in the org-roam database.
5. Reply with the file path, how many sections were processed, and the links added (as reported by the subagents).

Brief and factual.
