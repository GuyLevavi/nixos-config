# home.nix — thin wrapper kept at repo root for backwards compatibility
# All content lives in home/gui.nix (which imports home/base.nix).
{ ... }: {
  imports = [ ./home/gui.nix ];
}
