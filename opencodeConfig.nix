{
  org-roam-mcp,
  emacs-mcp,
  researchTools,
}:
let
  noPreambleSuffix = ''


    HARD RULE: when a tool call is needed, START your reply with the ```json block itself - zero words before it. No plan ("First step: ..."), no restating these rules, no announcement like "searching now:" or "let me check" - any of those ends the turn right there and the call never goes out. Never end a reply on an announcement: either emit the tool call, or give the final answer. Commentary belongs after tool results, never before the JSON, and never about the tool-call format itself.'';
  atRefSuffix = ''


    An @-reference in user input points at an org-roam node via its ID: @UUID (or @id:UUID). Fetch it with org-roam_get_node and link it as [[id:UUID][Title]]. If what follows @ is not a UUID, treat it as a title and resolve it with org-roam_resolve_ref first.'';
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

  agent = {
    build.disable = true;
    plan.disable = true;
    researcher = {
      description = "Research assistant over the org-roam knowledge base";
      mode = "primary";
      prompt = builtins.readFile ./prompts/researcher.md + agentSuffix;
      tools = researchTools;
    };
    capture = {
      description = "Capture text/URLs into well-formed org-roam notes";
      mode = "primary";
      prompt = builtins.readFile ./prompts/capture.md + agentSuffix;
      tools = researchTools;
    };
    format = {
      description = "Format a pasted Word-like document into clean org-mode, one subagent per heading";
      mode = "primary";
      prompt = builtins.readFile ./prompts/format.md + agentSuffix;
      tools = researchTools;
    };
    format-section = {
      description = "Formats a single top-level section of an org file (org_read_section → org_replace_section)";
      mode = "subagent";
      # no atRefSuffix: section agents never see @-references, and the suffix
      # tells the model to call org-roam tools that are disabled here
      prompt = builtins.readFile ./prompts/format-section.md + noPreambleSuffix;
      tools = sectionToolsOff;
    };
    link = {
      description = "Add backlinks to an org file, one link-section subagent per heading";
      mode = "primary";
      prompt = builtins.readFile ./prompts/link.md + agentSuffix;
      tools = researchTools;
    };
    link-section = {
      description = "Links mentions of existing org-roam nodes in a single top-level section";
      mode = "subagent";
      prompt = builtins.readFile ./prompts/link-section.md + noPreambleSuffix;
      tools = sectionToolsOff // {
        # the only extra tool the link prompt allows itself: verifying a
        # phrase that names a note missing from the candidate list
        "emacs_org-roam_resolve_ref" = true;
      };
    };
    crawler = {
      description = "Read-only graph crawler: maps a topic across the org-roam graph and returns a digest";
      mode = "subagent";
      prompt = builtins.readFile ./prompts/crawler.md + agentSuffix;
      tools = researchTools // {
        "org-roam_create_node" = false;
        "org-roam_update_node" = false;
        "org-roam_add_link" = false;
        "emacs_syncdb" = false;
        task = false;
      };
    };
  };

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
