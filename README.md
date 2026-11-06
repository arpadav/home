# home

Nix home-manager flake managing my dev environment. Declarative, reproducible setup for shell tools, editor configs, and dev toolchains.

## Quick Start

One-liner to install the full environment on Linux, WSL, or macOS:

```sh
curl -fsSL https://raw.githubusercontent.com/arpadav/home/main/install.sh | sh
```

This installs Nix (if missing), pulls the flake, and runs `home-manager switch`.

## Two clones

| clone | where | job |
|---|---|---|
| install copy | `~/.config/aav/home` (`$ARPAD_HOME_CFG`) | every switch builds from it, and the dotfiles and brain link into it (repo-backed skills link into their roots). never edited by hand; its brain never checks out `logs` |
| edit copy | any path (see below) | where this repo and the brain are edited, logged into, and synced from |

`install.sh` makes the install copy. In Claude Code, `/home-setup` makes the edit
copy and fixes an install copy that is missing or a symlink.

```sh
sy                         # pull the install copy (submodules, logs skipped), then switch
re                         # switch the install copy as it is
bash <edit copy>/bin/sy    # existing machine, first time: moves the old clone, switches from the new path
```

Not `re` from an old shell that first time: it still builds from the old path,
and once that clone has moved, from `github:arpadav/home` - without the brain.

## Repo roots

Repo-backed links (the `ask-arpad` and `nas` skills) resolve through the
directories in `~/.config/aav/repos.toml`, searched in order. Without the file
the only root is `~/repos/personal`:

```toml
roots = ["~/repos/active", "~/repos/inactive"]
```

The edit copy is `edit = "/path/to/home"` from the same file when set, else the
first `<root>/home`; either way only a clone holding `brain/bin` that is not the
install copy counts. `roots` keeps its default when the file sets only `edit`.
The file lives in `$XDG_CONFIG_HOME/aav/` when that is set to an absolute path.

## Local Development

Test changes in Docker before applying — see [debug/README.md](debug/README.md).

## See Also

- [aedit/README.md](aedit/README.md) — standalone aedit config
- [debug/README.md](debug/README.md) — Docker test environment
