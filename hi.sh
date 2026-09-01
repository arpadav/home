#!/usr/bin/env sh
#
# headless installer
#
# Usage:
#   curl -fsSL <url> | sh -s -- --runner <runner> --flake <flake> --name <name> [--msg <msg>] [--force]
#
# Author: aav
# --------------------------------------------------
set -eu

# --------------------------------------------------
# color support
# --------------------------------------------------
CAN_COLOR=false
if [ -t 1 ] && [ -n "${TERM:-}" ] && [ "$TERM" != "dumb" ]; then
    nc=$(tput colors 2>/dev/null || echo 0)
    [ "$nc" -ge 8 ] 2>/dev/null && CAN_COLOR=true
fi
[ "$CAN_COLOR" = false ] && [ -t 1 ] && [ -n "${COLORTERM:-}" ] && CAN_COLOR=true
ESC=$(printf '\033[')
if [ "$CAN_COLOR" = true ]; then
    BLUE="${ESC}1;34m" RED="${ESC}1;31m" GREEN="${ESC}0;32m" RST="${ESC}0m" DIM="${ESC}2;34m"
else
    BLUE='' RED='' GREEN='' RST='' DIM=''
fi

# --------------------------------------------------
# helpers
# --------------------------------------------------
step() { printf "  %s=>%s %s...\n" "$BLUE" "$RST" "$1"; }
die() {
    printf "  %sERROR:%s %s\n" "$RED" "$RST" "$1" >&2
    exit 1
}
need() { command -v "$1" >/dev/null 2>&1 || die "$1 is required but not installed"; }

# --------------------------------------------------
# get platform
# --------------------------------------------------
case "$(uname -s)" in
    Darwin) OS=mac ;;
    Linux) case "$(uname -r)" in *icrosoft* | *WSL*) OS=wsl ;; *) OS=linux ;; esac ;;
    MINGW* | MSYS* | CYGWIN*) OS=windows ;;
    *) OS=unknown ;;
esac

# --------------------------------------------------
# get nix profile script
# --------------------------------------------------
load_nix() {
    for p in "${XDG_STATE_HOME:-${HOME:-}/.local/state}/nix/profile/etc/profile.d/nix.sh" "${HOME:-}/.nix-profile/etc/profile.d/nix.sh" /nix/var/nix/profiles/default/etc/profile.d/nix.sh; do
        # shellcheck disable=SC1090  # runtime path, chosen above
        [ -f "$p" ] && {
            set +u
            . "$p"
            set -u
            return 0
        }
    done
    return 1
}

# --------------------------------------------------
# quiet + helpers
# --------------------------------------------------
CAN_WINDOW=false LINEBUF="" AWK_LIVE=""
[ -t 1 ] && command -v tee >/dev/null 2>&1 && command -v tr >/dev/null 2>&1 && printf 'probe\n' | awk '{exit 0}' >/dev/null 2>&1 && CAN_WINDOW=true
[ -z "$(printf '' | awk -Wi '{exit 0}' 2>&1)" ] && AWK_LIVE="-Wi"
command -v stdbuf >/dev/null 2>&1 && LINEBUF="stdbuf -oL"
# shellcheck disable=SC2317
restore_wrap() {
    [ "$CAN_WINDOW" = true ] && printf %s "${ESC}?7h"
    return 0
}
trap 'restore_wrap' EXIT
trap 'restore_wrap; exit 130' INT
trap 'restore_wrap; exit 143' TERM
# shellcheck disable=SC3043,SC2086
quiet() {
    local l="${QUIET_LOG:-$LOGDIR/quiet.log}" rc=0
    if [ "$CAN_WINDOW" = true ]; then printf %s "${ESC}?7l"
        { "$@" </dev/null 2>&1; echo $?>"$l.rc"; }|tee "$l"|$LINEBUF tr '\r' '\n'|awk $AWK_LIVE -v n="${QUIET_LINES:-3}" -v w="${COLUMNS:-$(tput cols 2>/dev/null||echo 128)}" -v e="$ESC" -v c="$DIM" -v z="$RST" 'BEGIN{n=int(n);if(n<1)n=3;w=int(w);if(w<20)w=128;m=w-5}{b[NR%n]=length($0)>m?substr($0,1,m-1)"…":$0;v=NR<n?NR:n;if(NR<=n)printf"\n";printf e"%dA",v;for(i=0;i<v;i++)printf e"2K  - %s%s%s\n",c,b[(NR-v+1+i)%n],z}END{if(v+0){printf e"%dA",v;for(i=0;i<v;i++)printf e"2K\n";printf e"%dA",v}}'
        printf %s "${ESC}?7h"; rc=$(cat "$l.rc" 2>/dev/null||echo 1); rm -f "$l.rc"; case $rc in ''|*[!0-9]*) rc=1;; esac
    else "$@" </dev/null >"$l" 2>&1||rc=$?; fi
    [ "$rc" -eq 0 ]||{ printf "  %sFAIL%s (see %s)\n" "$RED" "$RST" "$l"; return "$rc"; }
    printf "  done (log: %s)\n" "$l"
}

# --------------------------------------------------
# parse args
# --------------------------------------------------
RUNNER="" FLAKE="" NAME="" MSG="" FORCE=false
while [ $# -gt 0 ]; do
    # arity and shape: `--runner --flake x` would set RUNNER=--flake and fail on the wrong option
    case "$1" in
        --runner | --flake | --name | --msg)
            [ $# -ge 2 ] || die "$1 requires a value"
            case "$2" in -*) die "$1 requires a value, got the option $2" ;; esac
            ;;
    esac
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
        --force)
            FORCE=true
            shift
            ;;
        *) die "Unknown option: $1" ;;
    esac
done
[ -n "$RUNNER" ] || die "--runner is required"
[ -n "$FLAKE" ] || die "--flake is required"
[ -n "$NAME" ] || die "--name is required"
SNAME=$(printf '%s' "$NAME" | tr -cs 'A-Za-z0-9_' '_')

# --------------------------------------------------
# private log dir
# --------------------------------------------------
need mktemp
LOGDIR=$(mktemp -d "${TMPDIR:-/tmp}/hi-XXXXXX") || die "could not create a log directory"

# --------------------------------------------------
# source nix env if it exists but isn't on PATH
# --------------------------------------------------
[ "$FORCE" = true ] || {
    step "Checking Nix"
    command -v nix >/dev/null 2>&1 || load_nix || true
}

# --------------------------------------------------
# if still not found, actually install
# --------------------------------------------------
if [ "$FORCE" = true ] || ! command -v nix >/dev/null 2>&1; then
    case "$OS" in
        mac) NIX_FLAGS="--daemon" ;;
        linux | wsl) NIX_FLAGS="--no-daemon" ;;
        windows) die "windows is not supported natively - run this inside WSL" ;;
        *) die "unrecognised platform: $(uname -s)" ;;
    esac
    need curl
    step "Installing Nix ($OS)"
    NIX_INSTALLER="$LOGDIR/nix-install.sh"
    curl -fsSL https://nixos.org/nix/install -o "$NIX_INSTALLER" || die "could not download the Nix installer"
    [ -s "$NIX_INSTALLER" ] || die "the downloaded Nix installer is empty"
    QUIET_LOG="$LOGDIR/nix-install.log" quiet sh "$NIX_INSTALLER" "$NIX_FLAGS" --yes ||
        die "Nix installation failed (see $LOGDIR/nix-install.log)"
    load_nix || die "Nix install finished but no profile script was found (looked under \$XDG_STATE_HOME/nix, ~/.nix-profile and /nix/var/nix/profiles/default)"
    command -v nix >/dev/null 2>&1 || die "Nix installed but still not on PATH"
fi

# --------------------------------------------------
# install
# --------------------------------------------------
step "Installing ${NAME}"
export NIX_CONFIG="experimental-features = nix-command flakes"
QUIET_LOG="$LOGDIR/${SNAME}-install.log" quiet \
    nix --log-format raw run "$RUNNER" -- \
    switch -b backup --flake "$FLAKE" --impure --no-write-lock-file ||
    die "${NAME} installation failed (see $LOGDIR/${SNAME}-install.log)"

# --------------------------------------------------
# done
# --------------------------------------------------
step "Done!"
printf "Remember to run %ssource ~/.bashrc%s\n" "$GREEN" "$RST"
[ -n "$MSG" ] && printf "  %s\n" "$MSG"
exit 0
