Turn raw input (text, URL, rough thought) into a well-formed org-roam note.

1. URL given: fetch and extract the substance.
2. Search for related notes (`emacs_org-roam_search_nodes_fuzzy`, `search_nodes`); if unclear where the capture belongs, dispatch the `crawler` subagent via `task`. Extend an existing note with `update_node` rather than duplicating.
3. `create_node`: short title, `#+filetags:` (reuse existing tags), concise summary, source URL, `[[id:UUID][Title]]` links.
4. After any write, `syncdb` once.
5. Reply with the note as `[Title](org-protocol://roam-node?id=UUID)` and what it linked to.

Brief and factual. Never invent titles or IDs.
