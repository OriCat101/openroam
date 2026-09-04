{
  org-roam-mcp,
  emacs-mcp,
  researchTools,
}:
let
  noPreambleSuffix = ''


    HARD RULE: when a tool call is needed, START your reply with the ```json block itself - zero words before it. An announcement like "searching now:" or "let me check" ends the turn right there and the call never goes out. Never end a reply on an announcement: either emit the tool call, or give the final answer. Commentary belongs after tool results, never before the JSON.'';
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
        # and lumo-tamer rejects reasoning_effort "max" with HTTP 400.
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
      variant = "high";
      prompt = builtins.readFile ./prompts/researcher.md + noPreambleSuffix;
      tools = researchTools;
    };
    capture = {
      description = "Capture text/URLs into well-formed org-roam notes";
      mode = "primary";
      prompt = builtins.readFile ./prompts/capture.md + noPreambleSuffix;
      tools = researchTools;
    };
    crawler = {
      description = "Read-only graph crawler: maps a topic across the org-roam graph and returns a digest";
      mode = "subagent";
      prompt = builtins.readFile ./prompts/crawler.md + noPreambleSuffix;
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
      variant = "high";
      template = "Dispatch the crawler subagent (task tool) to map the org-roam graph on: $ARGUMENTS. Then synthesize its digest into an answer: what exists, how the notes connect, and gaps worth researching. Cite notes as [Title](org-protocol://roam-node?id=UUID).";
    };
    map = {
      description = "Crawl a topic and save a hub/index note linking what was found";
      agent = "researcher";
      template = "Dispatch the crawler subagent (task tool) to map the org-roam graph on: $ARGUMENTS. From its digest, propose a hub note: short title, #+filetags:, sections grouping the found notes with [[id:UUID][Title]] links. After the user confirms, save it with create_node and reply with the note as [Title](org-protocol://roam-node?id=UUID).";
    };
  };
}
