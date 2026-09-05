{ pkgs }:
pkgs.writeShellApplication {
  name = "emacs-mcp";
  runtimeInputs = [ (pkgs.python3.withPackages (ps: [ ps.mcp ])) ];
  text = "exec python3 ${./emacs-mcp.py}";
}
