"""MCP server exposing the user's running Emacs via emacsclient.

To add a tool: write a @mcp.tool() function that builds an elisp form and
returns eval_in_emacs(form). Interpolate string arguments with quote() only.
"""

import datetime
import json
import subprocess

from mcp.server.fastmcp import FastMCP

mcp = FastMCP("emacs")


def quote(s: str) -> str:
    """Escape s as an elisp string literal."""
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def eval_in_emacs(form: str, timeout: int = 120) -> str:
    """Evaluate an elisp form in the running Emacs.

    Returns emacsclient's printed result, or a message starting with
    "emacs error:" on failure.
    """
    try:
        proc = subprocess.run(
            ["emacsclient", "-e", form],
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except FileNotFoundError:
        return "emacs error: emacsclient not found on PATH"
    except subprocess.TimeoutExpired:
        return f"emacs error: timed out after {timeout}s"
    if proc.returncode != 0:
        return f"emacs error: {proc.stderr.strip() or proc.stdout.strip() or 'emacsclient failed'}"
    return proc.stdout.strip()


@mcp.tool()
def syncdb() -> str:
    """Sync the org-roam database after creating or editing notes, so searches and backlinks see the changes (runs org-roam-db-sync in Emacs)."""
    result = eval_in_emacs("(org-roam-db-sync)")
    if result.startswith("emacs error:"):
        return result
    return "org-roam database synced"


@mcp.tool(name="org-roam_search_nodes_fuzzy")
def search_nodes_fuzzy(query: str, max_results: int = 20) -> str:
    """Fuzzy full-text search across notes via NotDeft's Xapian index.

    Words are stemmed, so inexact forms match. Xapian query syntax is
    supported: "quoted phrases", AND/OR/NOT, wildcards like word*, and
    prefixes like title:foo or tag:bar. Returns matching note file paths,
    best matches first.
    """
    form = (
        f"(mapconcat #'identity"
        f" (seq-take (notdeft-list-files-by-query {quote(query)}) {int(max_results)})"
        f' "\\n")'
    )
    result = eval_in_emacs(form)
    if result.startswith("emacs error:"):
        return result
    try:
        files = json.loads(result)
    except ValueError:
        return result
    return files if files else "no matches"


def _section_form(file: str, index: int, body: str) -> str:
    """Elisp that binds beg/end around top-level section `index` of file, then evals body.

    Section 0 is the text before the first heading; sections 1..n are each
    top-level heading plus its body, up to the next top-level heading.
    """
    return (
        f"(with-current-buffer (find-file-noselect {quote(file)})"
        " (save-excursion (goto-char (point-min))"
        " (let (beg end)"
        f" (if (= {int(index)} 0) (setq beg (point-min))"
        f" (dotimes (_i {int(index)})"
        ' (unless (re-search-forward "^\\\\* " nil t) (error "no such heading")))'
        " (setq beg (match-beginning 0)))"
        ' (setq end (if (re-search-forward "^\\\\* " nil t) (match-beginning 0) (point-max)))'
        f" {body})))"
    )


@mcp.tool(name="org-roam_get_node")
def get_node(id: str) -> str:
    """Fetch an org-roam note by its UUID: returns its file path on the first line, then the full note contents."""
    form = (
        f"(let ((node (org-roam-node-from-id {quote(id)})))"
        ' (unless node (error "no node with id %s" ' + quote(id) + "))"
        " (let ((file (org-roam-node-file node)))"
        " (with-temp-buffer (insert-file-contents file)"
        ' (concat file "\\n\\n" (buffer-string)))))'
    )
    result = eval_in_emacs(form)
    if result.startswith("emacs error:"):
        return result
    try:
        return json.loads(result)
    except ValueError:
        return result


@mcp.tool(name="org-roam_resolve_ref")
def resolve_ref(name: str, max_results: int = 5) -> str:
    """Resolve an @Name reference to org-roam nodes by title (case-insensitive substring match, exact titles first).

    Returns up to max_results lines of "title\\tid\\tfile", best match first.
    """
    form = (
        f"(let* ((needle (downcase {quote(name)}))"
        " (hits (seq-filter (lambda (n)"
        " (string-match-p (regexp-quote needle) (downcase (org-roam-node-title n))))"
        " (org-roam-node-list)))"
        " (sorted (seq-sort-by (lambda (n)"
        " (if (string= (downcase (org-roam-node-title n)) needle) 0 1)) #'< hits)))"
        ' (mapconcat (lambda (n) (format "%s\\t%s\\t%s"'
        " (org-roam-node-title n) (org-roam-node-id n) (org-roam-node-file n)))"
        f' (seq-take sorted {int(max_results)}) "\\n"))'
    )
    result = eval_in_emacs(form)
    if result.startswith("emacs error:"):
        return result
    try:
        result = json.loads(result)
    except ValueError:
        pass
    return result if result else f"no node matching {name!r}"


@mcp.tool(name="org_list_headings")
def org_list_headings(file: str) -> str:
    """List the top-level headings of an org file, numbered from 1.

    Section 0 is any text before the first heading. Use with
    org_read_section / org_replace_section to process a large file one
    section at a time.
    """
    form = (
        f"(with-temp-buffer (insert-file-contents {quote(file)})"
        " (goto-char (point-min))"
        " (let ((n 0) acc)"
        ' (while (re-search-forward "^\\\\* .*$" nil t)'
        ' (setq n (1+ n)) (push (format "%d: %s" n (match-string 0)) acc))'
        ' (mapconcat #\'identity (nreverse acc) "\\n")))'
    )
    result = eval_in_emacs(form)
    if result.startswith("emacs error:"):
        return result
    try:
        result = json.loads(result)
    except ValueError:
        pass
    return result if result else "no headings"


@mcp.tool(name="org_read_section")
def org_read_section(file: str, index: int) -> str:
    """Return one top-level section of an org file.

    index 0 is the text before the first heading; 1..n are the top-level
    headings (see org_list_headings), each with its body and subheadings.
    """
    result = eval_in_emacs(
        _section_form(file, index, "(buffer-substring-no-properties beg end)")
    )
    if result.startswith("emacs error:"):
        return result
    try:
        return json.loads(result)
    except ValueError:
        return result


@mcp.tool(name="org_replace_section")
def org_replace_section(file: str, index: int, text: str) -> str:
    """Replace one top-level section of an org file with text and save.

    Same indexing as org_read_section. The replacement is inserted verbatim,
    so include the heading line itself and any leading/trailing blank lines
    the surrounding sections expect.
    """
    body = (
        "(progn (delete-region beg end) (goto-char beg)"
        f" (insert {quote(text)}) (save-buffer))"
    )
    result = eval_in_emacs(_section_form(file, index, body))
    if result.startswith("emacs error:"):
        return result
    return "section replaced"


@mcp.tool(name="org-roam_open_daily_note")
def open_daily_note(date: str = "") -> str:
    """Open a daily note in the running Emacs, creating it if it doesn't exist.

    date is YYYY-MM-DD; omit it to open today's note. Returns the note's
    file path.
    """
    if date:
        try:
            datetime.date.fromisoformat(date)
        except ValueError:
            return f"error: invalid date {date!r}, expected YYYY-MM-DD"
        goto = (
            f'(org-roam-dailies--capture (org-time-string-to-time {quote(date)}) t "d")'
        )
    else:
        goto = '(org-roam-dailies--capture (current-time) t "d")'
    result = eval_in_emacs(f"(progn {goto} (buffer-file-name))")
    if result.startswith("emacs error:"):
        return result
    return result


mcp.run()
