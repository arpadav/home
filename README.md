# home

Nix home-manager flake managing my dev environment. Declarative, reproducible setup for shell tools, editor configs, and dev toolchains.

## Quick Start

One-liner to install the full environment on any Linux machine:

```sh
curl -fsSL https://raw.githubusercontent.com/arpadav/home/main/install.sh | sh
```

This installs Nix (if missing), pulls the flake, and runs `home-manager switch`.

## Structure

```
home.nix          # main home-manager module (packages, aliases, configs)
flake.nix         # root flake (uses $USER/$HOME from env)
aedit/            # standalone aedit editor config (can be installed independently)
debug/            # Docker environment for testing changes
install.sh        # full environment installer
```

## Local Development

Clone and switch locally:

```sh
git clone https://github.com/arpadav/home.git
cd home
nix run home-manager -- switch --flake .#$USER --impure
```

Test changes in Docker before applying — see [debug/README.md](debug/README.md).

## See Also

- [aedit/README.md](aedit/README.md) — standalone aedit config
- [debug/README.md](debug/README.md) — Docker test environment
