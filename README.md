# home

Nix home-manager flake managing my dev environment. Declarative, reproducible setup for shell tools, editor configs, and dev toolchains.

## Quick Start

One-liner to install the full environment on Linux, WSL, or macOS:

```sh
curl -fsSL https://raw.githubusercontent.com/arpadav/home/main/install.sh | sh
```

This installs Nix (if missing), pulls the flake, and runs `home-manager switch`.

## For a machine you edit configs on

Everything out-of-store resolves through `~/.config/home-manager`. Clone there
and the same configs become live — edits apply without a rebuild, and the brain
skills, agents, and logs link up:

```sh
git clone --recurse-submodules https://github.com/arpadav/home.git ~/.config/home-manager
cd ~/.config/home-manager
nix run home-manager -- switch -b backup --flake .#headless --impure
```

## Local Development

Test changes in Docker before applying — see [debug/README.md](debug/README.md).

## See Also

- [aedit/README.md](aedit/README.md) — standalone aedit config
- [debug/README.md](debug/README.md) — Docker test environment
