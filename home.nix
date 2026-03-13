{
  pkgs,
  ...
}:

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
    git
    go
    nil
    ripgrep
    tmux
  ];

  # --------------------------------------------------
  # configs
  # --------------------------------------------------
  home.file = {
    ".config/nix/nix.conf".source = ./nix.conf;
    ".config/helix/runtime/".source = "${pkgs.helix.runtime}";
  };

  programs.bash = {
    enable = true;
    # --------------------------------------------------
    # aliases
    # --------------------------------------------------
    shellAliases = {
      ls = "eza";
      fed = "curl -fsSL https://arpadvoros.com/ed | sh";
      re = "home-manager switch --flake \$ARPAD_HOME_CFG#\$USER && rl";
      rl = "source $HOME/.bashrc";
      pe = "penv $@";
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
      [ -f $HOME/.cargo/env ] && . $HOME/.cargo/env
      [ -f $HOME/.bash_secrets ] && . $HOME/.bash_secrets
      [ -f $HOME/.bash_functions ] && . $HOME/.bash_functions

      # nvm
      export NVM_DIR="$HOME/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
      [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

      # openclaw completion
      # source "$HOME/.openclaw/completions/openclaw.bash"
      # linuxbrew
      # eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"

      # just completion
      source "$HOME/.config/just/completions/just.bash"

      # broot
      source "$HOME/.config/broot/launcher/bash/br"
    '';

    # --------------------------------------------------
    # env vars - use this over home.sessionVariables
    # --------------------------------------------------
    sessionVariables = {
      ARPAD_HOME_CFG = "$HOME/.config/home-manager";
      PATH = "$HOME/bin:/usr/local/cuda/bin:$HOME/.local/bin:$PATH";
      LD_LIBRARY_PATH = "/usr/local/cuda/lib64:$LD_LIBRARY_PATH";
      C_INCLUDE_PATH="/usr/include/x86_64-linux-gnu:$C_INCLUDE_PATH";
    };
  };
}
