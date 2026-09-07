{
  prompts,
  agentSuffix,
  researchTools,
  ...
}:
{
  description = "Read-only graph crawler: maps a topic across the org-roam graph and returns a digest";
  mode = "subagent";
  prompt = builtins.readFile (prompts + "/crawler.md") + agentSuffix;
  tools = researchTools // {
    "org-roam_create_node" = false;
    "org-roam_update_node" = false;
    "org-roam_add_link" = false;
    "emacs_syncdb" = false;
    task = false;
  };
}
