{
  description = "cpubox / gpubox - Hyprland + Noctalia on NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pinned to a tag so breakage is opt-in; bump with
    # `nix flake lock --update-input noctalia`.
    noctalia = {
      url = "github:noctalia-dev/noctalia/v5.0.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Temporary opencode downgrade: 1.18.26–1.18.30 crash when the
    # opencode-go gateway auth exists; this rev ships 1.18.25. Drop input and
    # overlay together once a fixed opencode is verified.
    nixpkgs-opencode = {
      url = "github:NixOS/nixpkgs/d2f67949798825fe853f7c5d0492b8bf016d3f88";
    };

    # Vendored into the store by home/skills.nix; no flake.nix upstream.
    matt-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    };

    # Package, global config and OpenCode plugin come from here (home/tmux.nix).
    workmux = {
      url = "github:raine/workmux";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    { nixpkgs, home-manager, nixpkgs-opencode, ... }@inputs:
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
              # temporary opencode pin — see inputs.nixpkgs-opencode
              nixpkgs.overlays = [
                (_final: _prev: {
                  opencode = nixpkgs-opencode.legacyPackages.${system}.opencode;
                })
              ];
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
