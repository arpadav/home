{
  pkgs,
  config,
  ...
}:
let
  # --------------------------------------------------
  # brain: arpad's one transferable second-brain - cards +
  # scripts + agentic files
  # --------------------------------------------------
  aavBrain = "${config.home.homeDirectory}/repos/personal/home/brain";
  agentsRoot = "${aavBrain}/agentic-files/agents";
  skillsRoot = "${aavBrain}/agentic-files/skills";
  codexAgents = "${aavBrain}/.generated/codex/agents";
  brainSkills = [
    "brain-plan"
    "brain-execute"
    "brain-review"
    "brain-self-refine"
    "brain-meta-drive"
    "brain-meta-recall"
    "brain-meta-learn"
    "brain-meta-intent"
    "brain-meta-author-prompt"
    "brain-meta-style"
    "brain-meta-curate"
    "brain-meta-commit"
  ];
  mkLinks = prefix: src: names: builtins.listToAttrs (map (name: {
    name = "${prefix}/${name}";
    value.source = config.lib.file.mkOutOfStoreSymlink "${src}/${name}";
  }) names);
  brainLinks =
    (mkLinks ".claude/skills" skillsRoot brainSkills)
    // (mkLinks ".agents/skills" skillsRoot brainSkills)
    // (mkLinks ".codex/skills" skillsRoot brainSkills);
in
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
    deno
    eza
    fd
    git
    go
    mosh
    nil
    pandoc
    ripgrep
    svelte-language-server
    superhtml
    tmux
    tombi
    ttyd
  ];

  # --------------------------------------------------
  # configs
  # --------------------------------------------------
  home.file = brainLinks // {
    ".config/nix/nix.conf".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/.config/home-manager/nix.conf";
    ".config/helix/runtime/".source = "${pkgs.helix.runtime}";
    ".claude/agents/brain".source =
      config.lib.file.mkOutOfStoreSymlink "${agentsRoot}/brain";
    ".claude/agents/general".source =
      config.lib.file.mkOutOfStoreSymlink "${agentsRoot}/general";
    ".claude/agents/rust".source =
      config.lib.file.mkOutOfStoreSymlink "${agentsRoot}/lang/rust";
    ".claude/agents/style".source =
      config.lib.file.mkOutOfStoreSymlink "${agentsRoot}/style";
    ".claude/agents/custom".source =
      config.lib.file.mkOutOfStoreSymlink "${agentsRoot}/custom";
    ".codex/agents".source =
      config.lib.file.mkOutOfStoreSymlink codexAgents;
    ".local/share/aav-brain".source =
      config.lib.file.mkOutOfStoreSymlink "${aavBrain}/logs";
    ".local/bin/brain-find" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        exec python3 "${aavBrain}/bin/brain-find.py" "$@"
      '';
    };
  };
  # --------------------------------------------------
  # compile codex TOML agents on every switch, so the
  # gitignored .generated/ dir stays fresh. $DRY_RUN_CMD is
  # a no-op echo under `--dry-run`, so a dry run never
  # writes; a compile failure WARNS but does NOT abort the
  # switch (stale codex agents beat a bricked activation)
  # --------------------------------------------------
  home.activation.brainCompile =
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.python3}/bin/python3 ${aavBrain}/bin/compile.py \
        || echo "warn: codex agent compile failed; .generated/ may be stale" >&2
    '';

  # --------------------------------------------------
  # bash config
  # --------------------------------------------------
  programs.bash = {
    enable = true;
    # --------------------------------------------------
    # aliases
    # --------------------------------------------------
    shellAliases = {
      ls = "eza";
      fed = "curl -fsSL https://arpadvoros.com/ed | sh";
      re = "home-manager switch --flake \$ARPAD_HOME_CFG#\$USER && unset __HM_SESS_VARS_SOURCED && source $HOME/.nix-profile/etc/profile.d/hm-session-vars.sh && hash -r";
      rl = "unset __HM_SESS_VARS_SOURCED && source $HOME/.bashrc && hash -r";
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

      # just completion
      source "$HOME/.config/just/completions/just.bash"

      # broot
      source "$HOME/.config/broot/launcher/bash/br"

      # export pkgconfig path
      export PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig
    '';

  };

  # --------------------------------------------------
  # PATH additions: home.sessionPath lands inside the
  # sentinel-guarded hm-session-vars.sh, so it's applied
  # exactly once per session. re-sourcing .profile/.bashrc
  # (or running `rl`/`re`) can no longer duplicate entries.
  # --------------------------------------------------
  home.sessionPath = [
    "$HOME/bin"
    "/usr/local/cuda/bin"
    "$HOME/.foundry/bin"
    "$HOME/.lmstudio/bin"
    "$HOME/.local/bin"
    "$HOME/.opencode/bin"
    "$HOME/.kimi-code/bin"
  ];

  # --------------------------------------------------
  # env vars - guarded via hm-session-vars.sh (once/session)
  # --------------------------------------------------
  home.sessionVariables = {
    ARPAD_HOME_CFG = "$HOME/.config/home-manager";
    AAV_BRAIN = "$ARPAD_HOME_CFG/brain";
    LD_LIBRARY_PATH = "/usr/local/cuda/lib64:$LD_LIBRARY_PATH";
    C_INCLUDE_PATH = "/usr/include/x86_64-linux-gnu:$C_INCLUDE_PATH";
  };
}
