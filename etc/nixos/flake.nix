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
  };

  outputs = { self, nixpkgs, home-manager, ... }: {
    nixosConfigurations = {

      # Intel desktop (primary machine)
      nixbox = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/nixbox/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.guy = import ./home.nix;
              backupFileExtension = "backup";
            };
          }
        ];
      };

      # NVIDIA Windows/dual-boot machine (uncomment when ready)
      # winbox = nixpkgs.lib.nixosSystem {
      #   system = "x86_64-linux";
      #   modules = [
      #     ./hosts/winbox/configuration.nix
      #     home-manager.nixosModules.home-manager
      #     {
      #       home-manager = {
      #         useGlobalPkgs = true;
      #         useUserPackages = true;
      #         users.guy = import ./home.nix;
      #         backupFileExtension = "backup";
      #       };
      #     }
      #   ];
      # };

    };
  };
}
