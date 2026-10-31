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
  # personal github alias: a `Host aav-github` block in
  # ~/.ssh/config (HostName github.com + the personal
  # IdentityFile). the key choice stays in ssh config;
  # this only checks whether the alias is there
  # --------------------------------------------------
  personalSshHost = "aav-github";
  sshConfig = "${config.home.homeDirectory}/.ssh/config";
  hasPersonalSshHost =
    onDisk sshConfig
    && lib.any
      (line: builtins.match "[[:space:]]*[Hh]ost[[:space:]]+(.*[[:space:]])?${personalSshHost}([[:space:]].*)?" line != null)
      (lib.splitString "\n" (builtins.readFile sshConfig));
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
  # --------------------------------------------------
  # forced: these paths belong to the brain, and older
  # hand-made symlinks into a working checkout sit where
  # they go. without force every switch stops on them
  # --------------------------------------------------
  brainLinks = lib.mapAttrs (_: file: file // { force = true; }) (
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
    }
  );
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
    ".local/share/no-agent-summary.js".source = dotfile "no-agent-summary.js";
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
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${pkgs.python3}/bin/python3 "${aavBrain}/bin/store/compile.py" \
        || warnEcho "codex agent compile failed; .generated/ may be stale"
    ''
  );
  # --------------------------------------------------
  # git. the checkout in ~/.config/home-manager (and its
  # submodules, whose gitdirs live under its .git) is
  # personal: commit as arpadav, and route arpadav/ ssh
  # urls through the personal alias when it exists
  # --------------------------------------------------
  programs.git = {
    enable = true;
    includes = [
      {
        condition = "gitdir:${homeCfg}/";
        contents = {
          user = {
            name = "arpadav";
            email = "arpadav@gmail.com";
          };
        } // lib.optionalAttrs hasPersonalSshHost {
          url."git@${personalSshHost}:arpadav/".insteadOf = "git@github.com:arpadav/";
        };
      }
    ];
  };
  # --------------------------------------------------
  # a switch from `github:arpadav/home` leaves no checkout
  # behind, so `re` would keep pulling from github. clone
  # one into place so the next `re` builds from it. never
  # touches an existing path. runs after linkGeneration so
  # the submodule fetch already sees the git include above.
  # brain is a private ssh submodule, so a missing key only
  # warns
  # --------------------------------------------------
  home.activation.homeCfgClone = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [ ! -e "${homeCfg}" ] && [ ! -L "${homeCfg}" ]; then (
      export PATH="${lib.makeBinPath [ config.programs.git.package pkgs.openssh ]}:$PATH"
      if run git clone https://github.com/arpadav/home.git "${homeCfg}"; then
        run git -C "${homeCfg}" remote set-url --push origin git@github.com:arpadav/home
        run git -C "${homeCfg}" submodule update --init --recursive \
          || warnEcho "brain submodule clone failed; run \`git -C ${homeCfg} submodule update --init --recursive\`"
      else
        warnEcho "could not clone home flake into ${homeCfg}"
      fi
    ) fi
  '';

  # --------------------------------------------------
  # bash config
  # --------------------------------------------------
  programs.bash = {
    enable = true;
    # --------------------------------------------------
    # space-prefixed commands skip history. termius shell
    # integration types its setup snippet into the login
    # shell with a leading space and counts on this to
    # keep it out of ~/.bash_history
    # --------------------------------------------------
    historyControl = [ "ignorespace" ];
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
      # --------------------------------------------------
      # tailscale ssh claims :22 on the tailnet address, so
      # mosh's bootstrap never reaches the real sshd. point
      # it at the second sshd port instead
      #   mts arpad@100.111.196.8
      # --------------------------------------------------
      mts = "mosh --ssh=\"ssh -p 2222\"";
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
    bashrcExtra = lib.mkMerge [
      # --------------------------------------------------
      # per-machine escape hatch: unmanaged, never in this
      # repo, sourced before anything nix defines. mkBefore
      # rather than a leading line - other modules feed this
      # option too and would otherwise land above it.
      # it runs BEFORE bash's `[[ $- == *i* ]] || return`,
      # so the file must stay SILENT: anything printed here
      # reaches non-interactive shells and breaks scp/rsync
      # --------------------------------------------------
      (lib.mkBefore ''
        [ -r "$HOME/.bashrc.local" ] && . "$HOME/.bashrc.local"
      '')
      ''
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
      ''
    ];
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
    # --------------------------------------------------
    # claude code defaults to its fullscreen renderer, which
    # draws on the alternate screen like vim, so its output
    # never lands in tmux's scrollback and the wheel either
    # reaches the app or (with mouse capture off) nothing.
    # forcing the classic renderer keeps the conversation in
    # native scrollback, so tmux owns scrolling and
    # highlighting again. overrides the saved `tui` setting
    # --------------------------------------------------
    CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN = "1";
    # --------------------------------------------------
    # kill claude code's agent_summary side-query
    # gist flamerix-ai/c3905705cc4205e5de3011fa2e74efce
    # --------------------------------------------------
    BUN_OPTIONS = "\${BUN_OPTIONS:+$BUN_OPTIONS }--preload=$HOME/.local/share/no-agent-summary.js";
  };
}
