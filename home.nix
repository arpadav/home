{ inputs, pkgs, lib, ... }:

{
  # --------------------------------------------------
  # aedit
  # --------------------------------------------------
  imports = [
    ./aedit/module.nix
  ];

  # --------------------------------------------------
  # my home packages
  # --------------------------------------------------
  home.packages = with pkgs; [
    eza
    fd
    gcc
    git
    ripgrep
    tmux
    # --------------------------------------------------
    # rust-overlay additional options
    # --------------------------------------------------
    (rust-bin.stable.latest.default.override {
      extensions = [
        "rust-src"
        "rust-analyzer"
      ];
    })
  ];

  # --------------------------------------------------
  # configs
  # --------------------------------------------------
  home.file = {
    ".config/nix/nix.conf".source = ./nix.conf;
  };

  # --------------------------------------------------
  # aliases
  # --------------------------------------------------
  home.shellAliases = {
    ls = "eza";
    find = "fd";
  };
}
