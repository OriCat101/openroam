{
  prompts,
  agentSuffix,
  researchTools,
  ...
}:
{
  description = "Research assistant over the org-roam knowledge base";
  mode = "primary";
  prompt = builtins.readFile (prompts + "/researcher.md") + agentSuffix;
  tools = researchTools;
}
