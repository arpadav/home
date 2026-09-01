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
    # one builder for every configuration below, so a named
    # login and an anonymous one cannot drift apart
    # --------------------------------------------------
    mkHome = { username, homeDirectory, pkgs }:
      home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs; };
        modules = [
          ./home.nix
          {
            home.username = username;
            home.homeDirectory = homeDirectory;
            home.stateVersion = "25.11";
          }
        ];
      };
    # --------------------------------------------------
    # helper fn from env
    # --------------------------------------------------
    fromEnv = name:
      let v = builtins.getEnv name;
      in if v != ""
      then v
      else throw "${name} is not set - this flake needs `--impure` and a login environment";
    # --------------------------------------------------
    # get system
    # --------------------------------------------------
    thisSystem =
      if builtins.getEnv "HOME" != ""
      then builtins.currentSystem
      else throw "this flake needs `--impure` to detect the current system";
    # --------------------------------------------------
    # the named logins all share one target, so it is
    # imported once rather than per configuration
    # --------------------------------------------------
    namedPkgs = import nixpkgs { system = "x86_64-linux"; };
    # --------------------------------------------------
    # logins with a config of their own, so `#arpad` keeps
    # resolving on the machines that already use it
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
      value = mkHome {
        username = u;
        homeDirectory = "/home/${u}";
        pkgs = namedPkgs;
      };
    }) users) // {
      headless = mkHome {
        username = fromEnv "USER";
        homeDirectory = fromEnv "HOME";
        pkgs = import nixpkgs { system = thisSystem; };
      };
    };
  };
}
