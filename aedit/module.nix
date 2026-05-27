{ inputs, config, lib, ... }:

let
  # --------------------------------------------------
  # live (out-of-store) symlink helper: edits to these
  # dotfiles are picked up without a home-manager rebuild
  # --------------------------------------------------
  liveDir = "${config.home.homeDirectory}/.config/home-manager/aedit/dotfiles";
  live = rel: config.lib.file.mkOutOfStoreSymlink "${liveDir}/${rel}";
in

{
  # --------------------------------------------------
  # aedit defaults
  # --------------------------------------------------
  imports = [
    inputs.aedit.homeManagerModules.default
  ];

  # --------------------------------------------------
  # configs (live)
  # --------------------------------------------------
  home.file = {
    ".bash_functions".source = live ".bash_functions";
  };

  # --------------------------------------------------
  # helix config/languages: defined directly (live) rather than via
  # programs.aedit.helix*File, so the source is a live symlink
  # --------------------------------------------------
  xdg.configFile."helix/config.toml".source = live "helix-config.toml";
  xdg.configFile."helix/languages.toml".source = live "helix-languages.toml";

  # --------------------------------------------------
  # broot: keep brootCfgFiles pointing at the in-repo paths so the aedit
  # module derives clean import names, but force the actual sources to live
  # symlinks (mkForce, since the module also defines these xdg files)
  # --------------------------------------------------
  xdg.configFile."broot/broot-conf.hjson".source = lib.mkForce (live "broot-conf.hjson");
  xdg.configFile."broot/broot-verbs.hjson".source = lib.mkForce (live "broot-verbs.hjson");

  # --------------------------------------------------
  # aedit config
  # --------------------------------------------------
  programs.aedit = {
    enable = true;
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
