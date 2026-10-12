{ inputs, lib, ... }:
let
  root = "${inputs.matt-skills}/skills";

  # Upstream's marketplace.json only lists its shipped set; these siblings are
  # Claude/git-hook machinery opencode can't run. Everything else is discovered.
  reject = [
    "deprecated"
    "in-progress"
    "misc"
  ];

  dirsIn =
    path:
    builtins.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir path));

  categories = builtins.filter (category: !(builtins.elem category reject)) (dirsIn root);

  # SKILL.md is shared format, so opencode and claude-code read the same dirs.
  linksInto =
    prefix:
    builtins.listToAttrs (
      lib.concatMap (
        category:
        map (name: {
          name = "${prefix}/${name}";
          value.source = "${root}/${category}/${name}";
        }) (dirsIn "${root}/${category}")
      ) categories
    );
in
{
  # Whole skill dirs as read-only store symlinks. Hand-rolled skills here are
  # untouched; a name collision would show up as a .hm-bak at activation.
  xdg.configFile = linksInto "opencode/skills";
  home.file = linksInto ".claude/skills";
}
