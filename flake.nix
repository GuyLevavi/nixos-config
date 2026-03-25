{
  description = "guy's nixos";

  inputs = {
    # nixos-unstable for up-to-date Hyprland, Neovim, Nushell
    nixpkgs.url = "nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      # Prevent home-manager from pulling its own nixpkgs version
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lazyvim-nix = {
      url = "github:pfassina/lazyvim-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, catppuccin, lazyvim-nix, ... }:
  let
    # Shared home-manager modules used by all configurations.
    commonHomeModules = [
      catppuccin.homeModules.catppuccin
      lazyvim-nix.homeManagerModules.default
    ];
  in {
    nixosConfigurations = {

      # Intel desktop (primary machine) — online, GUI, Hyprland
      nixbox = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/nixbox/configuration.nix
          catppuccin.nixosModules.catppuccin
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.gl = {
                imports = [ ./home.nix ] ++ commonHomeModules;
              };
              backupFileExtension = "backup";
            };
          }
        ];
      };

    };

    # ── Standalone home-manager configurations ────────────────────────────
    # Apply with:
    #   nix run nixpkgs#home-manager -- switch --flake /path/to/config#<name>

    # Online headless — WSL / Ubuntu / Docker (has autoupdate, cloud plugins)
    homeConfigurations.wsl = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [ ./home/base.nix ] ++ commonHomeModules;
    };

    # Airgap headless — for exporting closures to offline networks.
    # Differs from wsl: autoupdate disabled, no online plugins.
    # Build closure: nix build .#homeConfigurations.airgap.activationPackage
    homeConfigurations.airgap = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [ ./home/base.nix ./home/airgap.nix ] ++ commonHomeModules;
    };

  };
}
