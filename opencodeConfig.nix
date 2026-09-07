{
  org-roam-mcp,
  emacs-mcp,
  researchTools,
}:
let
  noPreambleSuffix = builtins.readFile ./prompts/noPreambleSuffix.txt ;
  atRefSuffix = builtins.readFile ./prompts/atRefSuffix.txt;
  agentSuffix = atRefSuffix + noPreambleSuffix;

  # Section subagents get only the tools they need.
  sectionToolsOff = researchTools // {
    read = false;
    grep = false;
    glob = false;
    list = false;
    webfetch = false;
    task = false;
    "org-roam_search_nodes" = false;
    "org-roam_get_node" = false;
    "org-roam_get_backlinks" = false;
    "org-roam_create_node" = false;
    "org-roam_update_node" = false;
    "org-roam_add_link" = false;
    "org-roam_list_files" = false;
    "emacs_syncdb" = false;
    "emacs_org-roam_search_nodes_fuzzy" = false;
    "emacs_org-roam_get_node" = false;
    "emacs_org-roam_resolve_ref" = false;
    "emacs_org-roam_open_daily_note" = false;
    "emacs_org_list_headings" = false;
  };

   agentArgs = {
    prompts = ./prompts;
    inherit
      noPreambleSuffix
      atRefSuffix
      agentSuffix
      researchTools
      sectionToolsOff
      ;
  };
  agents = import ./agents agentArgs;
in
{
  "$schema" = "https://opencode.ai/config.json";
  provider.lumo = {
    npm = "@ai-sdk/openai-compatible";
    name = "Lumo (lumo-tamer)";
    options = {
      baseURL = "{env:LUMO_BASE_URL}";
      apiKey = "{env:LUMO_API_KEY}";
    };
    models = {
      lumo.name = "Lumo (auto)";
      lumo-lite.name = "Lumo Lite";
      lumo-max = {
        name = "Lumo Max";
        reasoning = true;
        options.reasoningEffort = "high";
        variants = {
          high.reasoningEffort = "high";
          max.disabled = true;
        };
      };
    };
  };
  model = "lumo/lumo-max";
  small_model = "lumo/lumo-lite";
  default_agent = "researcher";

  mcp.org-roam = {
    type = "local";
    command = [ "${org-roam-mcp}/bin/org-roam-mcp" ];
    enabled = true;
    environment = {
      ORG_ROAM_DB_PATH = "{env:ORG_ROAM_DB_PATH}";
      ORG_ROAM_DIR = "{env:ORG_ROAM_DIR}";
    };
  };
  mcp.emacs = {
    type = "local";
    command = [ "${emacs-mcp}/bin/emacs-mcp" ];
    enabled = true;
  };

  agent = agents;

  command = {
    format = {
      description = "Format a pasted Word-like document into clean org-mode";
      agent = "format";
      template = "Format the following into clean org-mode: $ARGUMENTS";
    };
    link = {
      description = "Add backlinks to an org file, section by section";
      agent = "link";
      template = "Add backlinks to the following org file (a path or @-referenced node): $ARGUMENTS";
    };
    related = {
      description = "Find and summarize notes related to a topic";
      agent = "researcher";
      template = "Search the org-roam notes for material related to: $ARGUMENTS. Summarize what exists, how the notes connect (backlinks), and point out gaps worth researching.";
    };
    capture = {
      description = "Capture text or a URL into a new org-roam note";
      agent = "capture";
      template = "Capture the following into the org-roam knowledge base: $ARGUMENTS";
    };
    deepsearch = {
      description = "Deeply map the knowledge base on a topic via the crawler subagent";
      agent = "researcher";
      template = "Dispatch the crawler subagent (task tool) to map the org-roam graph on: $ARGUMENTS. Then synthesize its digest into an answer: what exists, how the notes connect, and gaps worth researching. Cite notes as [Title](org-protocol://roam-node?id=UUID).";
    };
    map = {
      description = "Crawl a topic and save a hub/index note linking what was found";
      agent = "researcher";
      template = "Dispatch the crawler subagent (task tool) to map the org-roam graph on: $ARGUMENTS. From its digest, propose a hub note: short title, #+filetags:, sections grouping the found notes with [[id:UUID][Title]] links. After the user confirms, save it with create_node and reply with the note as [Title](org-protocol://roam-node?id=UUID).";
    };
  };
}
