# 02 - repo roots: one per-machine config says where repos live

## 0. status

**built.** D1 (a) local roots file, D2 (a) delete, D3 (b) default `~/repos/personal`.

## 1. goal

the home flake never names a repo directory. each machine says, once, which directories hold
its checkouts; every link into a repo is declared in nix and resolved through that list.

| machine | roots |
|---|---|
| work laptop | `~/repos/personal` |
| personal | `~/repos/active`, `~/repos/inactive` |

moving a repo between roots, or renaming a root, is a config edit plus `re` - no link touched by hand.

## 2. what broke on the move (measured 2026-11-02)

every break was a symlink made by hand, outside nix, with an absolute repo path baked in:

| link | pointed at | state |
|---|---|---|
| `~/.config/home-manager` | `repos/personal/home/` | dangling -> `home.nix` skipped the brain module -> the switch unlinked every brain skill/agent. repointed by hand |
| `~/.claude/skills/ask-arpad` | `repos/personal/send-email/skills/ask-arpad` | dangling. repointed by hand |
| `~/.claude/skills/nas` | `repos/personal/nas-help/skills/nas` | dangling. repointed by hand |
| `~/.local/bin/{ae,aedit-hx-start,aedit-broot-start,aedit-hx-open}` | `repos/personal/aedit/...` | dangling, and the targets no longer exist in `repos/active/aedit` either: leftovers from before aedit became a flake input |

the brain-module skip was also **silent**: `home.nix` imports it only `if pathExists`, so a missing
checkout switches green and deletes the links.

## 3. design

### 3.1 the config (per machine, not tracked)

`~/.config/aav/repos.toml`:

```toml
# searched in order; the first root holding a repo wins
roots = ["~/repos/active", "~/repos/inactive"]
```

work laptop: `roots = ["~/repos/personal"]`.

### 3.2 resolution (home.nix, impure like `brainModule` already is)

- read the file via `builtins.getEnv "HOME"`, `builtins.fromTOML`, expand `~`.
- `repo = name:` first `root/name` that `pathExists`, else `null`.
- missing file -> `warnings` entry naming the file to create; repo links are skipped, the rest of
  the switch proceeds.

### 3.3 links declared in nix (all `mkOutOfStoreSymlink`, `force = true`)

```nix
repoSkills = {
  ask-arpad = { repo = "send-email"; path = "skills/ask-arpad"; };
  nas       = { repo = "nas-help";   path = "skills/nas"; };
};
```

each becomes `.claude/skills/<name>` when its repo resolves; an unresolved one is a `warnings` entry,
not a throw (a work laptop without `nas-help` still switches).

### 3.4 the home-manager link and the silent brain skip

- `~/.config/home-manager` stays the one fixed entry point (everything else, `brainModule`,
  `aedit/module.nix`'s `liveDir`, is already relative to it). home-manager cannot create the link it
  is evaluated through, so `install.sh`/README set it from the config's roots: `ln -sfn
  "$(first root holding home)" ~/.config/home-manager`.
- the brain-module skip gains a `warnings` entry: "brain module not found at <path>; brain skills
  and agents will be unlinked". the switch still succeeds - it just stops being silent.

### 3.5 cleanup

- delete the four dangling aedit links in `~/.local/bin` (D2).
- `.claude/settings.local.json`: drop the stale `repos/personal` permission line.

## 4. open decisions

- **D1 config shape.** (a) untracked `~/.config/aav/repos.toml`, roots list [recommended: per-machine
  by nature, no hostname table to keep in sync]. (b) tracked in the flake, keyed by hostname.
- **D2 aedit bin links.** (a) delete - aedit is a flake input now [recommended]. (b) keep and resolve.
- **D3 work-laptop default when the file is missing.** (a) warn, link nothing [recommended].
  (b) fall back to `~/repos/personal`.

## 5. phases

1. (S) `home.nix`: config reader, `repo` resolver, `repoSkills` links, both warnings. verify:
   `home-manager build` on this machine shows the two skill links pointing into `repos/active`;
   with the file renamed, the build warns and still succeeds.
2. (S) `install.sh`/README: create the config on first install, set `~/.config/home-manager` from it.
3. (S) cleanup §3.5.
