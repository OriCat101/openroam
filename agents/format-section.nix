{
  prompts,
  noPreambleSuffix,
  sectionToolsOff,
  ...
}:
{
  description = "Formats a single top-level section of an org file (org_read_section → org_replace_section)";
  mode = "subagent";
  # no atRefSuffix: section agents never see @-references
   prompt = builtins.readFile (prompts + "/format-section.md") + noPreambleSuffix;
  tools = sectionToolsOff;
}
