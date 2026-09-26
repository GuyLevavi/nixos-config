{ inputs, lib, ... }:
let
  root = "${inputs.matt-skills}/skills";

  # Upstream declares its shipped set only in .claude-plugin/marketplace.json;
  # these siblings are outside it (Claude/git-hook machinery opencode can't run,
  # plus WIP). Everything else is discovered — a new skill or category lands on
  # the next `update` with no edit here.
  reject = [
    "deprecated"
    "in-progress"
    "misc"
  ];

  dirsIn =
    path:
    builtins.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir path));

  categories = builtins.filter (category: !(builtins.elem category reject)) (dirsIn root);
in
{
  # Whole skill dirs (SKILL.md + supporting files) as read-only store symlinks.
  # The six hand-rolled skills in this directory are not managed here; a name
  # collision would show up as a home-manager .hm-bak backup at activation.
  xdg.configFile = builtins.listToAttrs (
    lib.concatMap (
      category:
      map (name: {
        name = "opencode/skills/${name}";
        value.source = "${root}/${category}/${name}";
      }) (dirsIn "${root}/${category}")
    ) categories
  );
}
