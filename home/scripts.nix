{ pkgs, ... }:
let
  # writeShellScriptBin pins every dependency to a store path.

  screen-record = pkgs.writeShellScriptBin "screen-record" ''
    set -euo pipefail
    out="$HOME/Videos/$(date +%Y-%m-%d_%H-%M-%S).mp4"
    mkdir -p "$HOME/Videos"
    if ${pkgs.procps}/bin/pgrep -x wf-recorder >/dev/null; then
      ${pkgs.procps}/bin/pkill -INT -x wf-recorder
      noctalia msg notification-show "Recording saved" "$out"
    else
      geom=$(${pkgs.slurp}/bin/slurp) || exit 0
      noctalia msg notification-show "Recording started" "Press the bind again to stop"
      ${pkgs.wf-recorder}/bin/wf-recorder -g "$geom" -f "$out"
    fi
  '';

  rb = pkgs.writeShellScriptBin "rb" ''
    set -euo pipefail
    cd /etc/nixos
    git add -A  # untracked files are invisible to a flake build
    sudo nixos-rebuild switch --flake "/etc/nixos#$(hostname)" "$@"
  '';

  update = pkgs.writeShellScriptBin "update" ''
    set -euo pipefail
    cd /etc/nixos
    nix flake update "$@"
    rb
  '';
in
{
  home.packages = [
    screen-record
    rb
    update
  ];
}
