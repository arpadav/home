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

  programs.bash = {
    enable = true;
    # --------------------------------------------------
    # aliases
    # --------------------------------------------------
    shellAliases = {
      ls = "eza";
      find = "fd";
      fed = "curl -fsSL https://arpadvoros.com/ed | sh";
      re = "home-manager switch --flake $ARPAD_HOME_CFG#$USER";
      pe = "source ~/.bash_functions && penv $@";
      hm = "ae $ARPAD_HOME_CFG/home.nix";
    };

    # --------------------------------------------------
    # ~/.profile
    # --------------------------------------------------
    profileExtra = ''
      case "$TERM" in
        xterm-color|*-256color|xterm-kitty) color_prompt=yes;;
      esac
      if [ "$color_prompt" = yes ]; then
        PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
      else
        PS1='\u@\h:\w\$ '
      fi
    '';

    # --------------------------------------------------
    # ~/.bashrc
    # --------------------------------------------------
    bashrcExtra = ''
      [ -f $HOME/.profile ] && . $HOME/.profile

      # linuxbrew
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"

      # nvm
      export NVM_DIR="$HOME/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
      [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

      # openclaw completion
      source "$HOME/.openclaw/completions/openclaw.bash"

      # just completion
      source "$HOME/.config/just/completions/just.bash"

      # broot
      source "$HOME/.config/broot/launcher/bash/br"
    '';
  };

  # --------------------------------------------------
  # env vars
  # --------------------------------------------------
  home.sessionVariables = {
    ARPAD_HOME_CFG = "$HOME/.config/home-manager";
    PATH = "/usr/local/cuda/bin:$PATH";
    LD_LIBRARY_PATH = "/usr/local/cuda/lib64:$LD_LIBRARY_PATH";
  };
}
