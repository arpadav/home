#!/bin/sh
#
# arpad home — full environment headless installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/arpadav/home/main/install.sh | sh
#
# Author: aav
# --------------------------------------------------
set -eu
NIX_SH="$HOME/.nix-profile/etc/profile.d/nix.sh"
step() {
    printf "\t\033[1;34m=>\033[0m %s\n" "$1"
}
logbox() {
    local h=${LOGBOX_HEIGHT:-8}
    tput sc
    local rows=$(tput lines)
    local start=$((rows - h))
    local end=$((rows - 1))
    tput csr "$start" "$end"
    local i
    for i in $(seq "$start" "$end"); do
        tput cup "$i" 0
        tput el
    done
    tput cup "$start" 0
    "$@"
    tput csr 0 $((rows - 1))
    tput rc
}
# --------------------------------------------------
# source nix env if it exists but isn't on PATH
# --------------------------------------------------
if ! command -v nix >/dev/null 2>&1; then
    if [ -f "$NIX_SH" ]; then
        . "$NIX_SH"
    fi
fi
# --------------------------------------------------
# if still not found, install
# --------------------------------------------------
if ! command -v nix >/dev/null 2>&1; then
    step "Installing Nix..."
    logbox curl -L https://nixos.org/nix/install | sh -s -- --no-daemon --yes >/dev/null
    . "$NIX_SH"
fi

# --------------------------------------------------
# install full home environment
# --------------------------------------------------
step "Installing home environment..."
logbox nix run home-manager/master -- switch \
    --flake "github:arpadav/home#$USER" \
    --impure \
    --no-write-lock-file \
    --extra-experimental-features "nix-command flakes"

# --------------------------------------------------
# apply env
# --------------------------------------------------
step "Applying env..."
source ~/.profile 2>&1
broot --install 2>&1

# --------------------------------------------------
# done!
# --------------------------------------------------
step "Done!"
