# debug

Docker machines for testing installs without touching your real system.

## Install matrix

```sh
./debug/matrix.sh          # the working tree, every install combination
./debug/matrix.sh remote   # the curl | sh installers, against github main
```

Each scenario runs in a fresh container and `check.sh` asserts what the switch left behind. Logs land in `~/.cache/ahome-matrix/`. The brain runs it on its own when a change touches a path in `../verify.toml`.

## Interactive

```sh
./debug/enter.sh
```

Builds an Ubuntu 24.04 image with single-user Nix, matching your username and UID, and drops you into it with the repo mounted at `~/ahome`. From there:

```sh
nix run home-manager/master -- switch -b backup --impure --flake .#headless
```
