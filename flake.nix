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

    # opencode downgrade channel: 1.18.26–1.18.30 crash whenever the
    # opencode-go gateway auth exists ("failed to send prompt (server error)"
    # — TypeError in SystemPrompt.environment, verified 1.18.25 is clean).
    # This is the last nixpkgs rev shipping 1.18.25; the overlay below swaps
    # it in. Drop input + overlay together once a fixed opencode (> 1.18.30)
    # is verified.
    nixpkgs-opencode = {
      url = "github:NixOS/nixpkgs/d2f67949798825fe853f7c5d0492b8bf016d3f88";
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
