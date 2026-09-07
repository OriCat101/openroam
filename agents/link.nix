{
  prompts,
  agentSuffix,
  researchTools,
  ...
}:
{
  description = "Add backlinks to an org file, one link-section subagent per heading";
  mode = "primary";
  prompt = builtins.readFile (prompts + "/link.md") + agentSuffix;
  tools = researchTools;
}
