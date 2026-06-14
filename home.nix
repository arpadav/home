{
  pkgs,
  config,
  ...
}:
let
  # --------------------------------------------------
  # brain: arpad's second-brain agents + skills, linked
  # live so reload-plugins/reload-skills pick up edits
  # --------------------------------------------------
  brain = "${config.home.homeDirectory}/repos/personal/agents/brain";
  aavBrain = "${config.home.homeDirectory}/repos/personal/aav-brain";
  # the skills are universal: same SKILL.md in claude, codex, ~/.agents. they
  # bootstrap the brain by discovery (P32): `brain-find` on PATH (installed below)
  # resolves $AAV_BRAIN / $AAV_BRAIN_BIN on any machine, so the skills invoke the
  # scripts via $AAV_BRAIN_BIN - no layout-assuming per-skill symlink.
  # 4 user ENTRIES (plan/execute/review/self-refine) + 8 brain-meta-* machinery
  # (the engine + the node-owner skills). all stay registered so the engine can
  # load the meta skills; the brain-meta- prefix is the "dont call directly" signal.
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
  # the 2 agents are claude-only frontmatter; codex gets them compiled.
  brainAgents = [
    "brain-review-gate"
    "brain-verifier"
  ];
  # build a set of "discovery-path/name" -> live-symlink entries.
  mkLinks = prefix: src: names: builtins.listToAttrs (map (name: {
    name = "${prefix}/${name}";
    value.source = config.lib.file.mkOutOfStoreSymlink "${src}/${name}";
  }) names);
  # claude reads skills + agents; codex reads skills only (raw skills +
  # compiled agents); ~/.agents is the modern shared skills location.
  brainLinks =
    (mkLinks ".claude/skills" "${brain}/skills" brainSkills)
    // (mkLinks ".agents/skills" "${brain}/skills" brainSkills)
    // (mkLinks ".codex/skills" "${brain}/skills" brainSkills)
    // (mkLinks ".codex/skills" "${brain}/compiled/codex" brainAgents);
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
    ".claude/agents/aav".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/.config/home-manager/agents";
    ".claude/agents/brain".source =
      config.lib.file.mkOutOfStoreSymlink
        "${brain}/agents";
    ".config/helix/runtime/".source = "${pkgs.helix.runtime}";
    # brain-find on PATH: the discovery entrypoint every brain skill bootstraps
    # from (P32), replacing the per-skill scripts/ symlink. exec the live script
    # so its `import brainlib` resolves from the real bin/ dir.
    ".local/bin/brain-find" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        exec python3 "${aavBrain}/bin/brain-find.py" "$@"
      '';
    };
  };

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
  ];

  # --------------------------------------------------
  # env vars - guarded via hm-session-vars.sh (once/session)
  # --------------------------------------------------
  home.sessionVariables = {
    ARPAD_HOME_CFG = "$HOME/.config/home-manager";
    AAV_BRAIN = "$HOME/repos/personal/aav-brain";
    AAV_BRAIN_BIN = "$HOME/repos/personal/aav-brain/bin";
    BRAIN_AGENTS = "$HOME/repos/personal/agents/brain";
    LD_LIBRARY_PATH = "/usr/local/cuda/lib64:$LD_LIBRARY_PATH";
    C_INCLUDE_PATH = "/usr/include/x86_64-linux-gnu:$C_INCLUDE_PATH";
  };
}
