{
  description = "guy's nixos — Hyprland + DMS, minimal";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      # One helper for both GUI hosts; only the host dir and home module differ.
      mkHost = host: homeModule: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/common.nix
          ./hosts/${host}
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";
              users.gl.imports = [ homeModule ];
            };
          }
        ];
      };
    in
    {
      nixosConfigurations = {
        nixbox = mkHost "nixbox" ./home/gui.nix;
        gamingbox = mkHost "gamingbox" ./home/gamingbox.nix;
      };

      # Headless, online — bare Ubuntu/Docker (Dockerfile.headless, scripts/test-smoke.sh).
      homeConfigurations.wsl = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [ ./home/base.nix ];
      };

      # Headless, offline — built into a closure by scripts/build-airgap-closure.sh
      # and imported on the airgapped work machine (WSL) via `nix copy`.
      homeConfigurations.airgap = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          ./home/base.nix
          ./home/airgap.nix
          {
            nixpkgs.config.allowUnfree = true;
          }
        ];
      };
    };
}
