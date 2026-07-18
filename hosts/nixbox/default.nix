# hosts/nixbox — Intel laptop, no dGPU. Everything shared is in ../common.nix.
{ ... }:
{
  imports = [ ./hardware-configuration.nix ];
  networking.hostName = "nixbox";
}
