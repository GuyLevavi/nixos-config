{
  description = "cpubox / gpubox - Hyprland + Noctalia on NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Noctalia v5 is Beta — pin to a rev once happy so breakage is opt-in.
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
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
                extraSpecialArgs = { inherit inputs username; };
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
