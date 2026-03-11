#!/usr/bin/env sh
#
# headless installer
#
# Usage:
#   curl -fsSL <url> | sh -s -- --runner <runner> --flake <flake> --name <name> [--msg <msg>]
#
# Author: aav
# --------------------------------------------------
set -eu
command -v curl >/dev/null 2>&1 || echo "curl is required but not installed"

# --------------------------------------------------
# color support
# --------------------------------------------------
CAN_COLOR=false
if [ -n "${TERM:-}" ] && [ "$TERM" != "dumb" ]; then
    nc=$(tput colors 2>/dev/null || echo 0)
    [ "$nc" -ge 8 ] 2>/dev/null && CAN_COLOR=true
fi
[ "$CAN_COLOR" = false ] && [ -n "${COLORTERM:-}" ] && CAN_COLOR=true
if [ "$CAN_COLOR" = true ]; then
    BLUE='\033[1;34m' RED='\033[1;31m' GREEN='\033[0;32m' RST='\033[0m'
else
    BLUE='' RED='' GREEN='' RST=''
fi

# --------------------------------------------------
# helpers
# --------------------------------------------------
step() { printf "  ${BLUE}=>${RST} %s...\n" "$1"; }
die()  { printf "  ${RED}ERROR:${RST} %s\n" "$1" >&2; exit 1; }
quiet(){
    command -v awk >/dev/null || { "$@"; return $?; }
    local n=${QUIET_LINES:-3} l=${QUIET_LOG:-/tmp/quiet-$$.log} w=${COLUMNS:-$(tput cols 2>/dev/null||echo 80)} e=$(printf '\033[')
    printf ${e}?7l;trap "printf '${e}?7h'" INT TERM
    "$@" 2>&1|tee "$l"|stdbuf -oL tr '\r' '\n'|awk -Wi -v n="$n" -v w="$w" -v e='\033[' '{m=w-5;b[NR%n]=length($0)>m?substr($0,1,m-1)"…":$0;v=NR<n?NR:n;if(NR<=n)printf"\n";printf e"%dA",v;for(i=0;i<v;i++)printf e"2K  - "e"2;34m%s"e"0m\n",b[(NR-v+1+i)%n]}END{if(v+0){printf e"%dA",v;for(i=0;i<v;i++)printf e"2K\n";printf e"%dA",v}}'&&echo "  done (log: $l)"||{ printf "${e}?7h"; return 1;}
    printf "${e}?7h"
}

# --------------------------------------------------
# parse args
# --------------------------------------------------
RUNNER="" FLAKE="" NAME="" MSG=""
while [ $# -gt 0 ]; do
    case "$1" in
        --runner)
            RUNNER="$2"
            shift 2
            ;;
        --flake)
            FLAKE="$2"
            shift 2
            ;;
        --name)
            NAME="$2"
            shift 2
            ;;
        --msg)
            MSG="$2"
            shift 2
            ;;
        *) die "Unknown option: $1" ;;
    esac
done
[ -n "$RUNNER" ] || die "--runner is required"
[ -n "$FLAKE" ] || die "--flake is required"
[ -n "$NAME" ] || die "--name is required"

# --------------------------------------------------
# source nix env if it exists but isn't on PATH
# --------------------------------------------------
step "Checking Nix"
NIX_SH="$HOME/.nix-profile/etc/profile.d/nix.sh"
if ! command -v nix >/dev/null 2>&1; then
    if [ -f "$NIX_SH" ]; then
        . "$NIX_SH"
    fi
fi

# --------------------------------------------------
# if still not found, actuall install
# --------------------------------------------------
if ! command -v nix >/dev/null 2>&1; then
    step "Installing Nix"
    QUIET_LOG=/tmp/nix-install.log quiet curl -L https://nixos.org/nix/install | sh -s -- --no-daemon --yes ||
        die "Nix installation failed (see /tmp/nix-install.log)"
    [ -f "$NIX_SH" ] || die "Nix install finished but $NIX_SH not found"
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    command -v nix >/dev/null 2>&1 || die "Nix installed but still not on PATH"
fi

# --------------------------------------------------
# install
# --------------------------------------------------
step "Installing ${NAME}"
QUIET_LOG="/tmp/${NAME}-install.log" quiet nix --log-format raw run "$RUNNER" -- switch \
    --flake "$FLAKE" \
    --impure \
    --no-write-lock-file \
    --extra-experimental-features "nix-command flakes" ||
    die "${NAME} installation failed (see /tmp/${NAME}-install.log)"

# --------------------------------------------------
# done
# --------------------------------------------------
step "Done!"
printf "Remember to run ${GREEN}source ~/.profile$RST\n"
[ -n "$MSG" ] && printf "  %s\n" "$MSG"
