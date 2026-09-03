{
  description = "openroam — research & note-taking agent for org-roam: opencode customized for lumo-tamer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    lumo-tamer-nix = {
      url = "github:OriCat101/lumo-tamer-nix/mistress";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      lumo-tamer-nix,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (
        pkgs:
        let
          org-roam-mcp = import ./org-roam-mcp.nix { inherit pkgs; };

          # Tools kept lean on purpose: lumo-tamer's tool calling is experimental
          # and Lumo's context is small; every enabled tool costs schema tokens.
          researchTools = {
            bash = false;
            edit = false;
            write = false;
            patch = false;
            todowrite = false;
            todoread = false;
          };

          opencodeConfig = import ./opencodeConfig.nix { inherit org-roam-mcp researchTools; };
          configJson = (pkgs.formats.json { }).generate "opencode.json" opencodeConfig;

          lumo-tamer = lumo-tamer-nix.packages.${pkgs.system}.lumo-tamer;

          server = pkgs.writeShellApplication {
            name = "openroam-server";
            runtimeInputs = [ lumo-tamer ];
            text = ''exec tamer server "$@"'';
          };

          openroam = pkgs.writeShellApplication {
            name = "openroam";
            runtimeInputs = [
              pkgs.opencode
              pkgs.curl
              lumo-tamer
            ];
            text = ''
              export OPENCODE_CONFIG="${configJson}"
              export LUMO_BASE_URL="''${LUMO_BASE_URL:-http://localhost:3003/v1}"
              export LUMO_API_KEY="''${LUMO_API_KEY:-your-super-secret-key}"
              export ORG_ROAM_DIR="''${ORG_ROAM_DIR:-$HOME/roam}"
              export ORG_ROAM_DB_PATH="''${ORG_ROAM_DB_PATH:-$HOME/.emacs.d/org-roam.db}"
              export LUMO_TAMER_HOME="''${LUMO_TAMER_HOME:-''${XDG_STATE_HOME:-$HOME/.local/state}/lumo-tamer}"

              if [ ! -f "$LUMO_TAMER_HOME/config.yaml" ]; then
                mkdir -p "$LUMO_TAMER_HOME"
                cat > "$LUMO_TAMER_HOME/config.yaml" <<EOF
              auth:
                method: login

              server:
                apiKey: "your-super-secret-key"
                customTools:
                  enabled: true
                instructions:
                  injectInto: "last"
              EOF
              fi

              health_url="''${LUMO_BASE_URL%/v1}/health"
              server_pid=""
              if ! curl -fsS -m 2 "$health_url" >/dev/null 2>&1; then
                echo "starting lumo-tamer server..." >&2
                tamer server >>"$LUMO_TAMER_HOME/openroam-server.log" 2>&1 &
                server_pid=$!
                trap '[ -n "$server_pid" ] && kill "$server_pid" 2>/dev/null' EXIT
                up=""
                for _ in $(seq 1 60); do
                  if curl -fsS -m 2 "$health_url" >/dev/null 2>&1; then
                    up=1
                    break
                  fi
                  kill -0 "$server_pid" 2>/dev/null || break
                  sleep 0.5
                done
                if [ -z "$up" ]; then
                  echo "lumo-tamer failed to start; see $LUMO_TAMER_HOME/openroam-server.log" >&2
                  echo "first run may need an interactive login: nix run github:OriCat101/lumo.el#server" >&2
                  exit 1
                fi
              fi

              if [ "$#" -ge 1 ] && [ -d "$1" ]; then
                cd "$1"
                shift
              else
                cd "$ORG_ROAM_DIR"
              fi
              opencode "$@"
            '';
          };
        in
        {
          inherit org-roam-mcp openroam server;
          default = openroam;
        }
      );

      apps = forAllSystems (pkgs: {
        default = {
          type = "app";
          program = "${self.packages.${pkgs.system}.default}/bin/openroam";
        };
        server = {
          type = "app";
          program = "${self.packages.${pkgs.system}.server}/bin/openroam-server";
        };
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            sqlite
            ripgrep
            uv
            opencode
          ];
        };
      });
    };
}
