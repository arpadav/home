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
  programs.bash = {
    enable = true;
    shellAliases = {
      ls = "eza";
      find = "fd";
      fed = "curl -fsSL https://arpadvoros.com/ed | sh";
      fenv = "curl -fsSL https://arpadvoros.com/env | sh";
    };
  };
}
