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
  # --------------------------------------------------
  # the install copy, everything out-of-store links into
  # --------------------------------------------------
  installCopy = import ./install-copy.nix;
  homeCfg = "${config.home.homeDirectory}/${installCopy}";
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
  # repo files: live off the install copy, else the copy
  # in the flake source
  # --------------------------------------------------
  repoFile = rel:
    if onDisk "${homeCfg}/${rel}"
    then config.lib.file.mkOutOfStoreSymlink "${homeCfg}/${rel}"
    else ./. + "/${rel}";
  dotfile = rel: repoFile "dotfiles/${rel}";
  # --------------------------------------------------
  # misc lang
  # --------------------------------------------------
  cudaShimRel = ".local/share/clangd-cuda-shim";
  cudaShim = "${config.home.homeDirectory}/${cudaShimRel}";
  # --------------------------------------------------
  # brain: a private submodule, so a checkout may not have
  # it. its module is read off disk, never from the flake
  # copy, which leaves submodules out. imports cannot see
  # `config`, so the path is built from the login's HOME
  # --------------------------------------------------
  brainModule = "${builtins.getEnv "HOME"}/${installCopy}/brain/module.nix";
in
{
  # --------------------------------------------------
  # aedit, repo-backed links, and the brain when it is
  # checked out
  # --------------------------------------------------
  imports = [
    ./aedit/module.nix
    ./repos.nix
  ] ++ lib.optionals (builtins.pathExists brainModule) [
    brainModule
    # the brain's edit copy is the home edit copy's brain
    ({ config, ... }: { aav.brain.edit = lib.mapNullable (e: "${e}/brain") config.aav.home.edit; })
  ];
  warnings = lib.optional (!builtins.pathExists brainModule)
    "brain module not found at ${brainModule} - brain skills and agents are not linked";

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
  home.file = {
    ".config/nix/nix.conf".text = builtins.readFile ./nix.conf;
    ".config/helix/runtime".source = "${pkgs.helix.runtime}";
    ".tmux.conf".source = dotfile "tmux.conf";
    ".local/share/no-agent-summary.js".source = dotfile "no-agent-summary.js";
    ".local/bin/sy".source = repoFile "bin/sy";
    # forced: a hand-made link may sit where this goes
    ".claude/skills/home-setup" = {
      source = repoFile ".claude/skills/home-setup";
      force = true;
    };
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
  # git. the install copy and the edit copy (and their
  # submodules, whose gitdirs live under each .git) are
  # personal: commit as arpadav, and route arpadav/ ssh
  # urls through the personal alias when it exists
  # --------------------------------------------------
  programs.git = {
    enable = true;
    includes = map (copy: {
      condition = "gitdir:${copy}/";
      contents = {
        user = {
          name = "arpadav";
          email = "arpadav@gmail.com";
        };
      } // lib.optionalAttrs hasPersonalSshHost {
        url."git@${personalSshHost}:arpadav/".insteadOf = "git@github.com:arpadav/";
      };
    }) ([ homeCfg ] ++ lib.optional (config.aav.home.edit != null) config.aav.home.edit);
  };
  # --------------------------------------------------
  # a switch from `github:arpadav/home` leaves no install
  # copy behind. sy makes one without switching: an old
  # ~/.config/home-manager clone is moved (`mv`), else
  # github is cloned without logs. a path already there
  # is never touched. runs after linkGeneration so the
  # submodule fetch already sees the git include above
  # a brain submodule that cannot be fetched only warns
  # --------------------------------------------------
  home.activation.installCopy = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [ ! -e "${homeCfg}" ] && [ ! -L "${homeCfg}" ]; then
      PATH="${lib.makeBinPath [ config.programs.git.package pkgs.openssh ]}:$PATH" \
        ARPAD_HOME_CFG="${homeCfg}" \
        run ${pkgs.bash}/bin/bash ${./bin/sy} --no-pull --no-switch \
        || warnEcho "could not make the install copy at ${homeCfg} (see sy's output above); run /home-setup"
    fi
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
      re = "sy --no-pull && unset __HM_SESS_VARS_SOURCED && source \$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh && hash -r";
      hm =
        if config.aav.home.edit != null
        then "ae ${config.aav.home.edit}/home.nix"
        else "echo 'no edit copy - run /home-setup' >&2 && false";
      hl = "rg --passthru";
      # --------------------------------------------------
      # tailscale ssh claims :22 on the tailnet address, so
      # mosh's bootstrap never reaches the real sshd. point
      # it at the second sshd port instead
      #   mts user@gpu-host
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

      # --------------------------------------------------
      # a tmux server first started from an ssh login hands
      # every pane an empty DISPLAY, so GUI apps find no
      # screen; attach to this user's running X session
      # --------------------------------------------------
      if [ -z "$DISPLAY" ]; then
        for sock in /tmp/.X11-unix/X*; do
          [ -O "$sock" ] || continue
          export DISPLAY=":''${sock##*/X}"
          [ -r "/run/user/$UID/gdm/Xauthority" ] && export XAUTHORITY="/run/user/$UID/gdm/Xauthority"
          break
        done
      fi

      # nvm
      export NVM_DIR="$HOME/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
      [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

      # just completion
      [ -f "$HOME/.config/just/completions/just.bash" ] && . "$HOME/.config/just/completions/just.bash"
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
    ARPAD_HOME_CFG = "$HOME/${installCopy}";
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
