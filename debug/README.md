# debug

Docker environment for testing home-manager config changes without affecting your real system.

## Usage

From anywhere:

```sh
./debug/enter.sh
```

This builds a Docker image with Nix pre-installed and drops you into a container with the repo mounted at `~/ahome`.

Inside the container, apply the config:

```sh
cd ~/ahome
./debug/load.sh
```

This runs `home-manager switch` against the local flake, so you can verify your changes work before committing.

## How It Works

- `enter.sh` — builds the Docker image (parameterized with your `$USER`) and starts an interactive container with the repo bind-mounted
- `load.sh` — runs `home-manager switch` against the local flake inside the container
- `Dockerfile` — Ubuntu 24.04 base with Nix single-user install, matching your username/UID
