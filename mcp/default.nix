{ pkgs }:
{
  org-roam-mcp = import ./org-roam-mcp.nix { inherit pkgs; };
  emacs-mcp = import ./emacs-mcp.nix { inherit pkgs; };
}
