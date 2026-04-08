{
  description = "guy's nixos";

  inputs = {
    # nixos-unstable for up-to-date Hyprland, Neovim, Nushell
    nixpkgs.url = "nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
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

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Exposes pkgs.vscode-marketplace.<publisher>.<name> for all marketplace extensions.
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, catppuccin, lazyvim-nix, nixos-wsl, nix-vscode-extensions, ... }:
  let
    # Shared home-manager modules used by all GUI configurations.
    commonHomeModules = [
      catppuccin.homeModules.catppuccin
      lazyvim-nix.homeManagerModules.default
    ];
    # VSCode marketplace overlay — applied to nixosConfigurations that use programs.vscode.
    vscodeOverlay = nix-vscode-extensions.overlays.default;
  in {
    nixosConfigurations = {

      # Intel laptop — online, GUI, Hyprland
      nixbox = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          { nixpkgs.overlays = [ vscodeOverlay ]; }
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

      # NVIDIA gaming laptop — online, GUI, Hyprland, RTX 4060
      gamingbox = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          { nixpkgs.overlays = [ vscodeOverlay ]; }
          ./hosts/gamingbox/configuration.nix
          catppuccin.nixosModules.catppuccin
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.gl = {
                imports = [ ./home/gamingbox.nix ] ++ commonHomeModules;
              };
              backupFileExtension = "backup";
            };
          }
        ];
      };

      # NixOS-WSL headless — online, x86_64, no GUI.
      # Apply: sudo nixos-rebuild switch --flake ~/nixos-config#wsl
      wsl = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nixos-wsl.nixosModules.default
          {
            wsl.enable      = true;
            wsl.defaultUser = "gl";
            wsl.wslConf.interop.appendWindowsPath = false;
            nix.settings.experimental-features = [ "nix-command" "flakes" ];
            system.stateVersion = "25.05";
          }
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs    = true;
              useUserPackages  = true;
              users.gl = {
                imports = [ ./home/base.nix ] ++ commonHomeModules;
              };
              backupFileExtension = "backup";
            };
          }
        ];
      };

    };

    # ── Standalone home-manager configurations ────────────────────────────
    homeConfigurations.wsl = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [ ./home/base.nix ] ++ commonHomeModules;
    };

    homeConfigurations.airgap = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [ ./home/base.nix ./home/airgap.nix ] ++ commonHomeModules;
    };

    homeConfigurations.runai = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        ./home/base.nix
        ./home/airgap.nix
        { home.username = "jensen"; home.homeDirectory = "/home/jensen"; }
      ] ++ commonHomeModules;
    };

  };
}
