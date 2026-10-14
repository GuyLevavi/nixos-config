{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;

  # Claude rewrites settings.json at runtime, so it can't be a store symlink: swap
  # only the workmux-owned hooks for the pinned set, leaving every other key alone.
  claudeHooksMerge = pkgs.writeText "workmux-claude-hooks.jq" ''
    def ours: (.command // "") | test("workmux (set-window-status|register-agent)");
    .hooks = reduce ($plugin[0].hooks | to_entries[]) as $e (
      (.hooks // {})
      | map_values(map(.hooks |= map(select(ours | not))) | map(select(.hooks != [])))
      | with_entries(select(.value != []));
      .[$e.key] += $e.value)
  '';
in
{
  home.packages = [
    inputs.workmux.packages.${system}.default
    pkgs.tmux # config is repo-owned: tmux/tmux.conf
  ];

  # tmux.conf is symlinked out of the store (home/default.nix); colours come
  # from palette.conf, written at runtime by noctalia-theme-sync
  # (home/noctalia.nix). The ANSI fallback block lives in tmux/tmux.conf.
  xdg.configFile = {
    "workmux/config.yaml".text = ''
      nerdfont: true
      merge_strategy: rebase
      agent: opencode
      status_format: false
    '';
    # From the same pinned revision as the package so the two never skew.
    "opencode/plugins/workmux-status.ts".source =
      "${inputs.workmux}/resources/opencode/plugins/workmux-status.ts";
    # Re-export the pinned checkout so its relative hooks/skills resolve there;
    # opencode loads every *.ts in this dir as a plugin.
    "opencode/plugins/ponytail.ts".text =
      ''export { default } from "${inputs.ponytail}/.opencode/plugins/ponytail.mjs";'';
  };

  home.activation.workmuxClaudeHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="$HOME/.claude/settings.json"
    [ -f "$settings" ] || { mkdir -p "$HOME/.claude"; echo "{}" >"$settings"; }
    if ${pkgs.jq}/bin/jq --slurpfile plugin ${inputs.workmux}/.claude-plugin/plugin.json \
        -f ${claudeHooksMerge} "$settings" >"$settings.tmp"; then
      if cmp -s "$settings" "$settings.tmp"; then rm "$settings.tmp"; else run mv "$settings.tmp" "$settings"; fi
    else
      rm -f "$settings.tmp"; warnEcho "workmux: $settings is not valid JSON, hooks not installed"
    fi
  '';
}
