{
  description = "openroam — research & note-taking agent for org-roam: opencode customized for lumo-tamer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    lumo-tamer-nix = {
      url = "github:OriCat101/lumo-tamer-nix/mistress";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      lumo-tamer-nix,
      treefmt-nix,
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

          emacs-mcp = pkgs.writeShellApplication {
            name = "emacs-mcp";
            runtimeInputs = [ (pkgs.python3.withPackages (ps: [ ps.mcp ])) ];
            text = "exec python3 ${./emacs-mcp.py}";
          };

          researchTools = {
            bash = false;
            edit = false;
            write = false;
            patch = false;
            todowrite = false;
            todoread = false;
          };

          opencodeConfig = import ./opencodeConfig.nix { inherit org-roam-mcp emacs-mcp researchTools; };
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
              pkgs.coreutils
              pkgs.gnugrep
              lumo-tamer
            ];
            text = ''
              export OPENCODE_CONFIG="${configJson}"
              export LUMO_BASE_URL="''${LUMO_BASE_URL:-http://localhost:3003/v1}"
              export LUMO_API_KEY="''${LUMO_API_KEY:-your-super-secret-key}"

              roam_var_from_emacs() {
                command -v emacsclient >/dev/null 2>&1 || return 1
                local val
                val=$(timeout 2 emacsclient -e \
                  "(if (and (boundp '$1) (symbol-value '$1)) (expand-file-name (symbol-value '$1)) \"\")" \
                  2>/dev/null) || return 1
                val=''${val#\"}
                val=''${val%\"}
                case $val in /*) ;; *) return 1 ;; esac
                printf '%s' "$val"
              }

              if [ -z "''${ORG_ROAM_DIR:-}" ]; then
                ORG_ROAM_DIR=$(roam_var_from_emacs org-roam-directory) || ORG_ROAM_DIR="$HOME/roam"
              fi
              export ORG_ROAM_DIR
              if [ -z "''${ORG_ROAM_DB_PATH:-}" ]; then
                ORG_ROAM_DB_PATH=$(roam_var_from_emacs org-roam-db-location) || ORG_ROAM_DB_PATH="$HOME/.emacs.d/org-roam.db"
              fi
              export ORG_ROAM_DB_PATH
              export LUMO_TAMER_HOME="''${LUMO_TAMER_HOME:-''${XDG_STATE_HOME:-$HOME/.local/state}/lumo-tamer}"

              config_yaml() {
                cat <<EOF
              # openroam:managed v2 — delete this file to have openroam regenerate it
              auth:
                method: login

              server:
                apiKey: "your-super-secret-key"
                customTools:
                  enabled: true
                instructions:
                  injectInto: "last"
                reasoning:
                  # Thinking is request-driven: opencode sends reasoning_effort only
                  # when a thinking variant is active. Keep the server default off.
                  default: "none"
                  # Forward Lumo's thinking tokens so opencode can render them.
                  surfaceThinking: true

              # A message starting with "/" (or "tamer ") would otherwise be swallowed
              # by lumo-tamer's command interceptor; "/logout" even exits the server,
              # killing every in-flight agent stream.
              commands:
                enabled: false
              EOF
              }

              # Byte-exact copy of what openroam previously wrote, to detect unmodified configs.
              legacy_config_yaml() {
                cat <<EOF
              auth:
                method: login

              server:
                apiKey: "your-super-secret-key"
                customTools:
                  enabled: true
                instructions:
                  injectInto: "last"

              # A message starting with "/" (or "tamer ") would otherwise be swallowed
              # by lumo-tamer's command interceptor; "/logout" even exits the server,
              # killing every in-flight agent stream.
              commands:
                enabled: false
              EOF
              }

              mkdir -p "$LUMO_TAMER_HOME"
              cfg="$LUMO_TAMER_HOME/config.yaml"
              if [ ! -f "$cfg" ]; then
                config_yaml > "$cfg"
              elif [ "$(cat "$cfg")" = "$(legacy_config_yaml)" ]; then
                # pristine older openroam config: safe to upgrade in place
                config_yaml > "$cfg"
              elif ! grep -q surfaceThinking "$cfg"; then
                {
                  echo "note: to see Lumo's thinking in the TUI, add to $cfg under 'server:':"
                  echo "  reasoning:"
                  echo "    surfaceThinking: true"
                } >&2
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

      formatter = forAllSystems (pkgs: treefmt-nix.lib.mkWrapper pkgs ./treefmt.nix);

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
