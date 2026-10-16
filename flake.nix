{
  description = "cpubox / gpubox - Hyprland + Noctalia on NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Package, global config and OpenCode plugin come from here (home/tmux.nix).
    workmux = {
      url = "github:raine/workmux";
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
