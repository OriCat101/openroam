{
  prompts,
  agentSuffix,
  researchTools,
  ...
}:
{
  description = "Format a pasted Word-like document into clean org-mode, one subagent per heading";
  mode = "primary";
  prompt = builtins.readFile (prompts + "/format.md") + agentSuffix;
  tools = researchTools;
}
