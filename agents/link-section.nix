{
  prompts,
  noPreambleSuffix,
  sectionToolsOff,
  ...
}:
{
  description = "Links mentions of existing org-roam nodes in a single top-level section";
  mode = "subagent";
  prompt = builtins.readFile (prompts + "/link-section.md") + noPreambleSuffix;
  tools = sectionToolsOff // {
    "emacs_org-roam_resolve_ref" = true;
  };
}
