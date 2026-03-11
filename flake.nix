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
  };

  # --------------------------------------------------
  # flake outputs, while binding function inputs to
  # `inputs`, as well as other deconstruction. naming
  # matters
  # --------------------------------------------------
  outputs = inputs @ { nixpkgs, home-manager, ... }:
  let
    # --------------------------------------------------
    # define `pkgs` = x86_64-linux packages from Nix
    # --------------------------------------------------
    pkgs = import nixpkgs {
      system = "x86_64-linux";
    };
    # --------------------------------------------------
    # user options - dont know why this cant be dynamically
    # defined
    # --------------------------------------------------
    users = [
      "arpad"
      "arpadav"
    ];
  in
  {
    # --------------------------------------------------
    # create home config using users
    # --------------------------------------------------
    homeConfigurations = builtins.listToAttrs (map (u: {
      name = u;
      value = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs; };
        modules = [
          ./home.nix
          {
            home.username = u;
            home.homeDirectory = "/home/${u}";
            home.stateVersion = "25.11";
          }
        ];
      };
    }) users);
  };
}
