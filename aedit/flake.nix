{
  # --------------------------------------------------
  # aedit flake w configs populated
  # --------------------------------------------------
  description = "headless aedit install";

  # --------------------------------------------------
  # flake inputs: source repositories fetched before
  # evaluation. these are NOT packages yet, just paths
  # to source code that nix will evaluate later
  # --------------------------------------------------
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    aedit = {
      url = "github:arpadav/aedit";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # --------------------------------------------------
  # flake outputs, while binding function inputs to
  # `inputs`, as well as other deconstruction. naming
  # matters
  # --------------------------------------------------
  outputs = inputs @ { nixpkgs, home-manager, ... }: {
    homeConfigurations.headless = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs { system = builtins.currentSystem; };
      extraSpecialArgs = { inherit inputs; };
      modules = [
        ./module.nix
        {
          home.username = builtins.getEnv "USER";
          home.homeDirectory = builtins.getEnv "HOME";
          home.stateVersion = "25.11";
        }
      ];
    };
  };
}
