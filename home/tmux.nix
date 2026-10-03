{
  inputs,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
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
}
