{ pkgs, lib, ... }:
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

  # External-only monitor policy: disable eDP-1 while any external monitor is
  # present; restore it once alone. Persisted via a sourced conf file, not
  # `hyprctl keyword` — keywords reset on every reload (Noctalia triggers one
  # per theme switch), which flapped the panel and shuffled workspaces.
  # Syncs once at launch too, so booting already-docked works.
  monitor-watch = pkgs.writeShellScriptBin "monitor-watch" ''
    set -euo pipefail
    internal="eDP-1"
    state="$HOME/.config/hypr/monitor-state.conf"

    sync_monitors() {
      external=$(${pkgs.hyprland}/bin/hyprctl -j monitors all \
        | ${pkgs.jq}/bin/jq "[.[] | select(.name != \"$internal\")] | length")
      if [ "$external" -gt 0 ]; then
        want="monitor = $internal, disable"
      else
        want="" # empty file -> the per-panel rules in hyprland.conf apply
      fi
      if [ "$want" != "$(cat "$state" 2>/dev/null || true)" ]; then
        printf '%s\n' "$want" > "$state"
        ${pkgs.hyprland}/bin/hyprctl reload >/dev/null
      fi
    }

    sync_monitors
    ${pkgs.socat}/bin/socat -u UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" - |
      while read -r line; do
        case "$line" in
          monitoradded*|monitorremoved*) sync_monitors ;;
        esac
      done
  '';
in
{
  home.packages = [
    screen-record
    rb
    update
    monitor-watch
  ];

  # hyprland.conf sources monitor-state.conf, and Hyprland errors on a missing
  # source — guarantee it exists before the first launch on a fresh install.
  # monitor-watch owns its content from then on.
  home.activation.ensureMonitorStateConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    [ -f "$HOME/.config/hypr/monitor-state.conf" ] \
      || install -Dm644 /dev/null "$HOME/.config/hypr/monitor-state.conf"
  '';
}
