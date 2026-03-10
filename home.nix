{ inputs, pkgs, lib, ... }:

{
  # --------------------------------------------------
  # aedit
  # --------------------------------------------------
  imports = [
    ./headless-aedit/module.nix
  ];

  # --------------------------------------------------
  # my home packages
  # --------------------------------------------------
  home.packages = with pkgs; [
    eza
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
}
