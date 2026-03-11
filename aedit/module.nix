{ inputs, pkgs, lib, ... }:

{
  # --------------------------------------------------
  # aedit defaults
  # --------------------------------------------------
  imports = [
    inputs.aedit.homeManagerModules.default
  ];

  # --------------------------------------------------
  # configs
  # --------------------------------------------------
  home.file = {
    ".bash_functions".source = ./dotfiles/.bash_functions;
  };

  # --------------------------------------------------
  # aedit config
  # --------------------------------------------------
  programs.aedit = {
    enable = true;
    helixCfgFile = ./dotfiles/helix-config.toml;
    helixLangFile = ./dotfiles/helix-languages.toml;
    brootCfgFiles = [
      ./dotfiles/broot-conf.hjson
      ./dotfiles/broot-verbs.hjson
    ];
  };

  # --------------------------------------------------
  # settings
  # --------------------------------------------------
  home.shell.enableBashIntegration = true;
  programs.home-manager.enable = true;
}
