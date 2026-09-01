{
  pkgs,
  config,
  lib,
  ...
}:
let
  # --------------------------------------------------
  # read fs if exists
  # --------------------------------------------------
  onDisk = path:
    if builtins.getEnv "HOME" != ""
    then builtins.pathExists path
    else throw "home.nix probes the filesystem to locate your checkout - re-run with --impure";
  homeCfg = "${config.home.homeDirectory}/.config/home-manager";
  # --------------------------------------------------
  # brain: arpad's one transferable second-brain - cards +
  # scripts + agentic files
  # --------------------------------------------------
  aavBrain = "${homeCfg}/brain";
  agentsRoot = "${aavBrain}/agentic-files/agents";
  skillsRoot = "${aavBrain}/agentic-files/skills";
  codexAgents = "${aavBrain}/.generated/codex/agents";
  # --------------------------------------------------
  # list every submodule, fixes old recurse bug
  # --------------------------------------------------
  brainSkills =
    if hasBrain && onDisk skillsRoot
    then builtins.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir skillsRoot))
    else [ ];
  mkLinks = prefix: src: names: builtins.listToAttrs (map (name: {
    name = "${prefix}/${name}";
    value.source = config.lib.file.mkOutOfStoreSymlink "${src}/${name}";
  }) names);
  # --------------------------------------------------
  # check if has brain on disk
  # --------------------------------------------------
  hasBrain = onDisk agentsRoot;
  # --------------------------------------------------
  # dot files
  # --------------------------------------------------
  dotfile = rel:
    if onDisk "${homeCfg}/dotfiles/${rel}"
    then config.lib.file.mkOutOfStoreSymlink "${homeCfg}/dotfiles/${rel}"
    else ./dotfiles + "/${rel}";
  # --------------------------------------------------
  # misc lang
  # --------------------------------------------------
  cudaShimRel = ".local/share/clangd-cuda-shim";
  cudaShim = "${config.home.homeDirectory}/${cudaShimRel}";
  brainLinks =
    (mkLinks ".claude/skills" skillsRoot brainSkills)
    // (mkLinks ".agents/skills" skillsRoot brainSkills)
    // (mkLinks ".codex/skills" skillsRoot brainSkills)
    // lib.optionalAttrs hasBrain {
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
          exec ${pkgs.python3}/bin/python3 "${aavBrain}/bin/brain-find.py" "$@"
        '';
      };
    };
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
    clang-tools
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
    ".config/nix/nix.conf".text = builtins.readFile ./nix.conf;
    ".config/helix/runtime".source = "${pkgs.helix.runtime}";
    ".tmux.conf".source = dotfile "tmux.conf";
    ".config/clangd/config.yaml".text = ''
      If:
        PathMatch: [.*\.cu, .*\.cuh]
      CompileFlags:
        Compiler: clang++
        Add:
          - -xcuda
          - --cuda-path=/usr/local/cuda
          - --cuda-host-only
          - -nocudalib
          - -std=c++17
          - -isystem${cudaShim}
          - -I/usr/local/cuda/include
          - -I/usr/local/cuda/include/cccl
          - -Wno-unknown-cuda-version
    '';
    "${cudaShimRel}/texture_fetch_functions.h".text = "";
    "${cudaShimRel}/surface_functions.h".text = "";
  };
  # --------------------------------------------------
  # compile codex TOML agents on every switch
  # --------------------------------------------------
  home.activation.brainCompile = lib.mkIf hasBrain (
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.python3}/bin/python3 "${aavBrain}/bin/compile.py" \
        || echo "warn: codex agent compile failed; .generated/ may be stale" >&2
    ''
  );

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
      re = "home-manager switch --flake \"\$(arpad_flake)#headless\" --impure && unset __HM_SESS_VARS_SOURCED && source \$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh && hash -r";
      rl = "unset __HM_SESS_VARS_SOURCED && source $HOME/.bashrc && hash -r";
      pe = "penv $@";
      hm = "ae $ARPAD_HOME_CFG/home.nix";
      hl = "rg --passthru";
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
      [ -f "$HOME/.config/just/completions/just.bash" ] && . "$HOME/.config/just/completions/just.bash"

      # which flake `re` switches to
      arpad_flake() {
        if [ -d "''${ARPAD_HOME_CFG:-}" ]; then
          printf '%s' "$ARPAD_HOME_CFG"
        else
          printf '%s' "github:arpadav/home"
        fi
      }
    '';
  };

  home.sessionPath = [
    "$HOME/.nix-profile/bin"
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
    AAV_BRAIN = "$HOME/.config/home-manager/brain";
    LD_LIBRARY_PATH = "/usr/local/cuda/lib64\${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}";
    C_INCLUDE_PATH = "/usr/include/x86_64-linux-gnu\${C_INCLUDE_PATH:+:$C_INCLUDE_PATH}";
    PKG_CONFIG_PATH = "/usr/lib/x86_64-linux-gnu/pkgconfig\${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}";
  };
}
