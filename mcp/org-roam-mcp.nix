{ pkgs }:
pkgs.python3Packages.buildPythonApplication {
  pname = "org-roam-mcp";
  version = "0.1.0-unstable-2026-01-22";
  pyproject = true;
  src = pkgs.fetchFromGitHub {
    owner = "aserranoni";
    repo = "org-roam-mcp";
    rev = "e526327a023f032b1c252cadd829968d8a1e5358";
    hash = "sha256-CRYT9Mkawswi4DQLDF+sQm+pe61wfWo6DSDfgIaJIpo=";
  };
  # upstream's console script points at an async main() and never awaits it
  postPatch = ''
    cat >> src/org_roam_mcp/server.py <<'EOF'

    def run() -> None:
        asyncio.run(main())
    EOF
    substituteInPlace pyproject.toml \
      --replace-fail 'org_roam_mcp.server:main' 'org_roam_mcp.server:run'
  '';
  build-system = [ pkgs.python3Packages.hatchling ];
  dependencies = with pkgs.python3Packages; [
    mcp
    pydantic
    typing-extensions
    anyio
  ];
  doCheck = false;
}
