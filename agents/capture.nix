{
  prompts,
  agentSuffix,
  researchTools,
  ...
}:
{
  description = "Capture text/URLs into well-formed org-roam notes";
  mode = "primary";
  prompt = builtins.readFile (prompts + "/capture.md") + agentSuffix;
  tools = researchTools;
}
