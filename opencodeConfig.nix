{ org-roam-mcp, researchTools }:
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
      lumo-max.name = "Lumo Max";
    };
  };
  model = "lumo/lumo-max";
  small_model = "lumo/lumo-lite";

  mcp.org-roam = {
    type = "local";
    command = [ "${org-roam-mcp}/bin/org-roam-mcp" ];
    enabled = true;
    environment = {
      ORG_ROAM_DB_PATH = "{env:ORG_ROAM_DB_PATH}";
      ORG_ROAM_DIR = "{env:ORG_ROAM_DIR}";
    };
  };

  agent = {
    build.disable = true;
    plan.disable = true;
    researcher = {
      description = "Research assistant over the org-roam knowledge base";
      mode = "primary";
      prompt = builtins.readFile ./prompts/researcher.md + noPreambleSuffix;
      tools = researchTools;
    };
    capture = {
      description = "Capture text/URLs into well-formed org-roam notes";
      mode = "primary";
      prompt = builtins.readFile ./prompts/capture.md + noPreambleSuffix;
      tools = researchTools;
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
  };
}
