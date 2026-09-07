# Import every *.nix file in this directory (except this one) as an agent
# named after the file (sans extension), calling each file with the given args.
args:
let
  files = builtins.filter (f: f != "default.nix" && builtins.match ".*\\.nix" f != null) (
    builtins.attrNames (builtins.readDir ./.)
  );
in
builtins.listToAttrs (
  map (f: {
    name = builtins.substring 0 (builtins.stringLength f - 4) f;
    value = import (./. + "/${f}") args;
  }) files
)
