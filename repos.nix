{
  config,
  lib,
  ...
}:
let
  # --------------------------------------------------
  # where this machine keeps its checkouts. per machine
  # and untracked: one root on one box, an active and an
  # inactive root on another. searched in order, first
  # root holding a repo wins
  # --------------------------------------------------
  home = config.home.homeDirectory;
  rootsFile = "${home}/.config/aav/repos.toml";
  defaultRoots = [ "~/repos/personal" ];
  hasRootsFile =
    if builtins.getEnv "HOME" != ""
    then builtins.pathExists rootsFile
    else throw "repos.nix reads ${rootsFile} - re-run with --impure";
  expand = p: if lib.hasPrefix "~/" p then "${home}/${lib.removePrefix "~/" p}" else p;
  roots = map expand (
    if hasRootsFile
    then (builtins.fromTOML (builtins.readFile rootsFile)).roots
    else defaultRoots
  );
  # --------------------------------------------------
  # repo name -> absolute checkout, or null
  # --------------------------------------------------
  repo = name: lib.findFirst builtins.pathExists null (map (r: "${r}/${name}") roots);
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
  # forced: hand-made links sit where these go
  # --------------------------------------------------
  home.file = lib.mapAttrs' (name: s: lib.nameValuePair ".claude/skills/${name}" {
    source = config.lib.file.mkOutOfStoreSymlink "${s.root}/${s.path}";
    force = true;
  }) found;

  warnings = lib.mapAttrsToList
    (name: s: "skill ${name}: repo ${s.repo} is in none of [${lib.concatStringsSep ", " roots}] (roots from ${if hasRootsFile then rootsFile else "the default; create ${rootsFile}"}) - not linked")
    missing;
}
