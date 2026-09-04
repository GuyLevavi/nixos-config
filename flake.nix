{
  description = "cpubox / gpubox - Hyprland + Noctalia on NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pinned to a tag deliberately (v5.0.1 is the first stable release after
    # 10 betas) — bump with `nix flake lock --update-input noctalia` so
    # breakage is opt-in, not whatever lands on the default branch.
    noctalia = {
      url = "github:noctalia-dev/noctalia/v5.0.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative LazyVim. Pinned to a LazyVim release tag the same way —
    # bump with `nix flake lock --update-input lazyvim` when upstream cuts
    # a new LazyVim release.
    lazyvim = {
      url = "github:pfassina/lazyvim-nix/v16.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      username = "gl";

      mkHost =
        hostName:
        nixpkgs.lib.nixosSystem {
          inherit system;
          # exposes inputs/username/hostName as module arguments
          specialArgs = { inherit inputs username hostName; };
          modules = [
            ./hosts/${hostName}
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "hm-bak";
                extraSpecialArgs = { inherit inputs username hostName; };
                users.${username} = import ./home;
              };
            }
          ];
        };
    in
    {
      nixosConfigurations = {
        cpubox = mkHost "cpubox";
        gpubox = mkHost "gpubox";
      };
    };
}
