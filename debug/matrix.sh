#!/usr/bin/env bash
#
# install every combination of this repo in a fresh container and check each
#
# Usage:
#   debug/matrix.sh                 the working tree, every local scenario
#   debug/matrix.sh remote          the one-line installers, against github main
#   debug/matrix.sh all             both
#   debug/matrix.sh <scenario>...   just those
#
# local scenarios copy the working tree as it stands, uncommitted edits
# included, so a change is tested before it is committed:
#   full       checkout at the install copy with the brain
#   no-brain   the same checkout, brain submodule never cloned
#   aedit      aedit alone, from the checkout
#   elsewhere  checkout outside the install copy
#   edit       full, plus an edit copy under the default root
#   migrate    an old ~/.config/home-manager clone, moved by sy, then full
#   held       brain/logs holding a new file, in the install copy and then in
#              an old clone: sy refuses, nothing deinited or moved
#   brain      the brain alone, from its own flake
# remote scenarios run the curl | sh installers on a box with no nix:
#   remote-full   install.sh, then a second switch from the checkout it cloned
#   remote-aedit  aedit/install.sh
#
# Author: aav
# --------------------------------------------------
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(dirname "$HERE")"
LOGS="${XDG_CACHE_HOME:-$HOME/.cache}/ahome-matrix"
LOCAL="full no-brain aedit elsewhere brain edit migrate held"
REMOTE="remote-full remote-aedit"
# local scenarios share one nix store, so only the first one downloads
STORE=ahome-matrix-nix

# --------------------------------------------------
# steps run inside the container. the checkout is a
# copy of /src with everything staged in the COPY, so
# a flake sees new files the way it will once they
# are committed
# --------------------------------------------------
SWITCH='nix run home-manager/master -- switch -b backup --impure'
# the install copy, the clone an old install left, and an edit copy under the
# default root, all expanded in the container
# shellcheck disable=SC2016
CFG='$HOME/.config/aav/home'
# shellcheck disable=SC2016
OLD='$HOME/.config/home-manager'
# shellcheck disable=SC2016
EDIT='$HOME/repos/personal/home'
COPY="mkdir -p ${CFG%/*} && cp -a /src $CFG && git -C $CFG add -A -- . ':!brain'"
STAGE_BRAIN="git -C $CFG/brain add -A -- . ':!logs'"
DROP_BRAIN="rm -rf $CFG/brain && mkdir $CFG/brain"
# the brain's gitdir lives under home's .git; moved beside its work tree it
# drops the worktree pointer back, and so does its own logs submodule
BRAIN_ALONE='cp -a /src/brain ~/aav-brain && rm ~/aav-brain/.git && cp -a /src/.git/modules/brain ~/aav-brain/.git &&
    git config -f ~/aav-brain/.git/config --unset core.worktree &&
    git config -f ~/aav-brain/.git/modules/logs/config --unset core.worktree &&
    echo "gitdir: ../.git/modules/logs" > ~/aav-brain/logs/.git &&
    git -C ~/aav-brain add -A -- . ":!logs"'

steps() {
    case $1 in
        full) echo "$COPY && $STAGE_BRAIN && cd $CFG && $SWITCH --flake .#headless &&
            /check.sh home aedit live brain=$CFG/brain" ;;
        edit) echo "$COPY && $STAGE_BRAIN && mkdir -p ${EDIT%/*} && cp -a /src $EDIT && cd $CFG &&
            $SWITCH --flake .#headless && /check.sh home aedit live brain=$CFG/brain edit=$EDIT" ;;
        migrate) echo "mkdir -p ${OLD%/*} && cp -a /src $OLD && git -C $OLD add -A -- . ':!brain' &&
            git -C $OLD/brain add -A -- . ':!logs' && bash $OLD/bin/sy --no-pull --no-switch && cd $CFG &&
            $SWITCH --flake .#headless && /check.sh home aedit live brain=$CFG/brain migrated" ;;
        held) echo "$COPY && echo held > $CFG/brain/logs/held && ! bash $CFG/bin/sy --no-pull --no-switch &&
            [ -e $CFG/brain/logs/.git ] && [ -e $CFG/brain/logs/held ] && mv $CFG $OLD &&
            ! bash $OLD/bin/sy --no-pull --no-switch &&
            [ -e $OLD/brain/logs/.git ] && [ -e $OLD/brain/logs/held ] && [ ! -e $CFG ]" ;;
        no-brain) echo "$COPY && $DROP_BRAIN && cd $CFG && $SWITCH --flake .#headless &&
            /check.sh home aedit live nobrain" ;;
        aedit) echo "$COPY && $DROP_BRAIN && cd $CFG && $SWITCH --flake '.?dir=aedit#headless' &&
            /check.sh aedit live nobrain" ;;
        elsewhere) echo "mkdir -p ~/src && cp -a /src ~/src/home && git -C ~/src/home add -A -- . ':!brain' &&
            cd ~/src/home && $SWITCH --flake .#headless && /check.sh home aedit store nobrain" ;;
        brain) echo "$BRAIN_ALONE && cd ~/aav-brain && $SWITCH --flake .#headless &&
            /check.sh brain=\$HOME/aav-brain" ;;
        remote-full) echo "curl -fsSL https://raw.githubusercontent.com/arpadav/home/main/install.sh | sh &&
            /check.sh home aedit store nobrain &&
            . ~/.nix-profile/etc/profile.d/nix.sh && cd $CFG && $SWITCH --flake .#headless &&
            /check.sh home aedit live nobrain" ;;
        remote-aedit) echo "curl -fsSL https://raw.githubusercontent.com/arpadav/home/main/aedit/install.sh | sh &&
            /check.sh aedit store nobrain" ;;
        *) return 1 ;;
    esac
}

# --------------------------------------------------
# one scenario, one fresh container; its log is kept
# --------------------------------------------------
run() {
    local s=$1 image=ahome-matrix-nix vol=(-v "$STORE":/nix) cmd
    # --------------------------------------------------
    # the scenario's steps
    # --------------------------------------------------
    cmd=$(steps "$s") || {
        echo "unknown scenario: $s" >&2
        return 2
    }
    # --------------------------------------------------
    # remote scenarios start with no nix, so no store
    # --------------------------------------------------
    case $s in remote-*) image=ahome-matrix-base vol=() ;; esac
    # --------------------------------------------------
    # a fresh container, its log kept
    # --------------------------------------------------
    docker run --rm "${vol[@]}" -v "$REPO":/src:ro -v "$HERE/check.sh":/check.sh:ro "$image" \
        bash -lc "export NIX_CONFIG='experimental-features = nix-command flakes'
            [ -f ~/.nix-profile/etc/profile.d/nix.sh ] && . ~/.nix-profile/etc/profile.d/nix.sh
            $cmd" >"$LOGS/$s.log" 2>&1
}

# --------------------------------------------------
# which scenarios
# --------------------------------------------------
case "${1:-}" in
    "") set -- $LOCAL ;;
    remote) set -- $REMOTE ;;
    all) set -- $LOCAL $REMOTE ;;
esac
# --------------------------------------------------
# images: a bare box for remote scenarios, a nix box for local ones
# --------------------------------------------------
mkdir -p "$LOGS"
docker build -q -t ahome-matrix-base --target base --build-arg USERNAME=tester "$HERE" >/dev/null &&
    docker build -q -t ahome-matrix-nix --target nix --build-arg USERNAME=tester "$HERE" >/dev/null || {
    echo "image build failed" >&2
    exit 1
}

# --------------------------------------------------
# remote scenarios install their own nix, so they
# start in the background
# --------------------------------------------------
failed=0
for s in "$@"; do
    case $s in remote-*)
        run "$s" &
        eval "pid_${s//-/_}=$!"
        ;;
    esac
done
# --------------------------------------------------
# local scenarios share the store, so they run in turn
# --------------------------------------------------
for s in "$@"; do
    case $s in remote-*) continue ;; esac
    if run "$s"; then echo "  pass  $s"; else
        echo "  FAIL  $s  ($LOGS/$s.log)"
        failed=1
    fi
done
# --------------------------------------------------
# the remote scenarios' results
# --------------------------------------------------
for s in "$@"; do
    case $s in remote-*)
        p="pid_${s//-/_}"
        if wait "${!p}"; then echo "  pass  $s"; else
            echo "  FAIL  $s  ($LOGS/$s.log)"
            failed=1
        fi
        ;;
    esac
done
exit $failed
