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
      url = "github:arpadav/aedit/preparing-for-release";
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
    # helper function: builds a home-manager config for
    # a given user. passes username + homeDirectory into
    # `home.nix` via `extraSpecialArgs`
    # --------------------------------------------------
    _mkHome = { username, homeDirectory ? "/home/${username}" }:
      home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs; };
        # --------------------------------------------------
        # import home module
        # --------------------------------------------------
        modules = [
          ./home.nix
          {
            home.username = builtins.getEnv "USER";
            home.homeDirectory = builtins.getEnv "HOME";
            # home.username = username;
            # home.homeDirectory = homeDirectory;
            home.stateVersion = "25.11";
            nixpkgs.overlays = [ rust-overlay.overlays.default ];
          }
        ];
      };
  in
  {
    # --------------------------------------------------
    # profiles
    # --------------------------------------------------
    # https://www.chrisportela.com/posts/home-manager-flake/#creating-basic-home-manager-flake-configuration
    # https://nix-community.github.io/home-manager/index.xhtml#sec-flakes-flake-parts-module
    # see how define `homeConfigurations`
    # --------------------------------------------------
    homeConfigurations = {
      arpad = _mkHome { username = "arpad"; };
      arpadav = _mkHome { username = "arpadav"; };
    };
  };
}
