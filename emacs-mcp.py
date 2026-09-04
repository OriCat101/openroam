"""MCP server exposing the user's running Emacs via emacsclient.

To add a tool: write a @mcp.tool() function that builds an elisp form and
returns eval_in_emacs(form). Interpolate string arguments with quote() only.
"""

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


mcp.run()
