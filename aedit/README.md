# aedit

Standalone [aedit](https://github.com/arpadav/aedit) with custom config, for arpad.

## Quick Start

One-liner to install `aedit` with my configs:

```sh
curl -fsSL https://raw.githubusercontent.com/arpadav/home/main/aedit/install.sh | sh
```

This installs Nix (if missing), pulls the `aedit` flake, and configures everything.

## Usage in Parent Flake

This module is imported by the root `home.nix` via `./aedit/module.nix`. It can also be used standalone via its own `flake.nix`.
