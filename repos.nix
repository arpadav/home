{
  config,
  lib,
  ...
}:
let
  home = config.home.homeDirectory;
  # --------------------------------------------------
  # his per-machine config folder: $XDG_CONFIG_HOME/aav
  # when that is an absolute path, else ~/.config/aav
  # --------------------------------------------------
  xdgConfig = builtins.getEnv "XDG_CONFIG_HOME";
  configDir = if lib.hasPrefix "/" xdgConfig then "${xdgConfig}/aav" else "${home}/.config/aav";
  # --------------------------------------------------
  # where this machine keeps its checkouts. per machine
  # and untracked: one root on one box, an active and an
  # inactive root on another. searched in order, first
  # root holding a repo wins
  # --------------------------------------------------
  rootsFile = "${configDir}/repos.toml";
  defaultRoots = [ "~/repos/personal" ];
  hasRootsFile =
    if builtins.getEnv "HOME" != ""
    then builtins.pathExists rootsFile
    else throw "repos.nix reads ${rootsFile} - re-run with --impure";
  expand = p: if lib.hasPrefix "~/" p then "${home}/${lib.removePrefix "~/" p}" else p;
  settings =
    if hasRootsFile
    then builtins.fromTOML (builtins.readFile rootsFile)
    else { };
  roots = map expand (settings.roots or defaultRoots);
  # --------------------------------------------------
  # repo name -> absolute checkout, or null
  # --------------------------------------------------
  repo = name: lib.findFirst builtins.pathExists null (map (r: "${r}/${name}") roots);
  # --------------------------------------------------
  # the clone of this repo that is edited. candidates:
  # `edit` alone when set, else `<root>/home` for every
  # root in order. the first candidate holding brain/bin
  # that is not an install copy wins; null when none
  # does. nix cannot resolve a symlink, so an install
  # copy is matched by its path string: a link to one is
  # not caught here
  # --------------------------------------------------
  installCopies = [ "${home}/${import ./install-copy.nix}" "${home}/.config/home-manager" ];
  editable = p: !(builtins.elem p installCopies) && builtins.pathExists "${p}/brain/bin";
  editCandidates =
    if (settings.edit or "") != ""
    then [ (expand settings.edit) ]
    else map (r: "${r}/home") roots;
  editRoot = lib.findFirst editable null editCandidates;
  # --------------------------------------------------
  # skills that live in their own repo rather than the
  # brain
  # --------------------------------------------------
  repoSkills = {
    ask-arpad = { repo = "send-email"; path = "skills/ask-arpad"; };
    nas = { repo = "nas-help"; path = "skills/nas"; };
  };
  resolved = lib.mapAttrs (_: s: s // { root = repo s.repo; }) repoSkills;
  found = lib.filterAttrs (_: s: s.root != null) resolved;
  missing = lib.filterAttrs (_: s: s.root == null) resolved;
in
{
  # --------------------------------------------------
  # the edit copy's checkout path, or null when this
  # machine has none; home.nix gives it the same git
  # identity as the install copy
  # --------------------------------------------------
  options.aav.home.edit = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "absolute path of the edit copy of the home repo, or null when none is found";
  };

  config = {
    aav.home.edit = editRoot;

    # --------------------------------------------------
    # forced: hand-made links sit where these go
    # --------------------------------------------------
    home.file = lib.mapAttrs' (name: s: lib.nameValuePair ".claude/skills/${name}" {
      source = config.lib.file.mkOutOfStoreSymlink "${s.root}/${s.path}";
      force = true;
    }) found;

    warnings = lib.mapAttrsToList
      (name: s: "skill ${name}: repo ${s.repo} is in none of [${lib.concatStringsSep ", " roots}] (roots from ${if settings ? roots then rootsFile else "the default; set roots in ${rootsFile}"}) - not linked")
      missing;
  };
}
