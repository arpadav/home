#!/usr/bin/env bash
# --------------------------------------------------
# custom function to print horizontal lines
# --------------------------------------------------
lines() {
    printf '%*s\n' "${1:-50}" '' | tr ' ' '-'
}

plan() {
    local f
    f="$(find "$HOME/.claude/plans" -type f -printf '%T@ %p\n' |
        sort -nr |
        head -n1 |
        cut -d' ' -f2-)"
    [ -n "$f" ] && "${EDITOR:-vim}" "$f"
}
