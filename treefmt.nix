{
  projectRootFile = "flake.nix";

  programs.nixfmt.enable = true;
  programs.ruff-format.enable = true;
  programs.mdformat.enable = true;
  settings.formatter.mdformat.options = [ "--number" ];
}
