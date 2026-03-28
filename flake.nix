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

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, catppuccin, lazyvim-nix, nixos-wsl, ... }:
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

      # NixOS-WSL headless — online, x86_64, no GUI.
      # First-time setup: see README "Deploy → NixOS WSL" section.
      # Apply: sudo nixos-rebuild switch --flake ~/nixos-config#wsl
      wsl = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nixos-wsl.nixosModules.default
          {
            wsl.enable      = true;
            wsl.defaultUser = "gl";
            # Don't pollute $PATH with Windows executables (major perf win).
            # Keep interop.enabled = true so you can still call explorer.exe etc.
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
    # Use these when Nix is installed but the system is NOT NixOS
    # (bare Ubuntu, Docker containers, non-NixOS servers).
    # Apply with:
    #   nix run nixpkgs#home-manager -- switch --flake /path/to/config#<name>

    # Online headless — bare Ubuntu / Docker (has autoupdate, cloud plugins)
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

    # RunAI airgap — same as airgap but for RunAI pods where the user is 'jensen'.
    # RunAI pods have a pre-existing 'jensen' user; home-manager activation must
    # match the actual username or symlinks land in the wrong home directory.
    # Build: nix build .#homeConfigurations.runai.activationPackage
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
