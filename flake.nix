{
  # --------------------------------------------------
  # arpad flake
  # --------------------------------------------------
  description = "arpad home flake";
  
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
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # --------------------------------------------------
  # flake outputs, while binding function inputs to
  # `inputs`, as well as other deconstruction. naming
  # matters
  # --------------------------------------------------
  outputs = inputs @ { nixpkgs, home-manager, rust-overlay, ... }:
  let
    # --------------------------------------------------
    # define `pkgs` = x86_64-linux packages from Nix
    # --------------------------------------------------
    pkgs = import nixpkgs {
      system = "x86_64-linux";
    };
    # --------------------------------------------------
    # user env
    # --------------------------------------------------
    username = builtins.getEnv "USER";
    homeDirectory = builtins.getEnv "HOME";
  in
  {
    # --------------------------------------------------
    # create home config using $USER
    # --------------------------------------------------
    homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = { inherit inputs; };
      modules = [
        ./home.nix
        {
          home.username = username;
          home.homeDirectory = homeDirectory;
          home.stateVersion = "25.11";
          nixpkgs.overlays = [ rust-overlay.overlays.default ];
        }
      ];
    };
  };
}
