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
  };

  outputs = { self, nixpkgs, home-manager, catppuccin, ... }: {
    nixosConfigurations = {

      # Intel desktop (primary machine)
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
                imports = [
                  ./home.nix
                  catppuccin.homeModules.catppuccin
                ];
              };
              backupFileExtension = "backup";
            };
          }
        ];
      };

    };

    # Standalone home-manager for WSL / Ubuntu / Docker environments.
    # Apply with:
    #   nix run nixpkgs#home-manager -- switch --flake /path/to/config#wsl
    homeConfigurations.wsl = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        ./home/base.nix
        catppuccin.homeModules.catppuccin
      ];
    };
  };
}
