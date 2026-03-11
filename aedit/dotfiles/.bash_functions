#!/usr/bin/env bash
# --------------------------------------------------
# custom function to print horizontal lines
# --------------------------------------------------
lines() {
    printf '%*s\n' "${1:-50}" '' | tr ' ' '-'
}
# --------------------------------------------------
# custom function to fetch arpad env
# --------------------------------------------------
fenv() {
    ARPAD_HOME_CFG="${ARPAD_HOME_CFG:-$HOME/.config/home-manager}"
    # --------------------------------------------------
    # exit if git dirty
    # --------------------------------------------------
    if [ -n "$(git -C "$ARPAD_HOME_CFG" status --porcelain)" ]; then
        echo "Git repo dirty - aborting, please stash or commit in $ARPAD_HOME_CFG"
        return 1
    fi
    git -C "$ARPAD_HOME_CFG" checkout main || return 1
    git -C "$ARPAD_HOME_CFG" pull || return 1
    re || return 1
}

# --------------------------------------------------
# custom function to push arpad env
# --------------------------------------------------
penv() {
    ARPAD_HOME_CFG="${ARPAD_HOME_CFG:-$HOME/.config/home-manager}"
    if [ "$1" != "-m" ] || [ -z "$2" ]; then
        echo "Usage: penv -m \"commit message\""
        return 1
    fi
    local msg="$2"
    if [ -z "$(git -C "$ARPAD_HOME_CFG" status --porcelain)" ]; then
        echo "Nothing to commit"
        return 0
    fi
    git -C "$ARPAD_HOME_CFG" add -A
    git -C "$ARPAD_HOME_CFG" commit -m "$msg"
    local branch
    branch=$(git -C "$ARPAD_HOME_CFG" rev-parse --abbrev-ref HEAD)
    git -C "$ARPAD_HOME_CFG" push origin "$branch"
}
