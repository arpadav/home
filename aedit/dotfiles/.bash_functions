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
    cd "$ARPAD_HOME_CFG" || {
        echo "Cannot cd to $ARPAD_HOME_CFG"
        return 1
    }
    # --------------------------------------------------
    # exit if git dirty
    # --------------------------------------------------
    if [ -n "$(git status --porcelain)" ]; then
        echo "Git repo dirty - aborting, please stash or commit in $ARPAD_HOME_CFG"
        return 1
    fi
    git checkout main || return 1
    git pull || return 1
    re || return 1
}
