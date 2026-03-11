#!/usr/bin/env bash
# --------------------------------------------------
# custom function to print horizontal lines
# --------------------------------------------------
lines() {
    printf '%*s\n' "${1:-50}" '' | tr ' ' '-'
}
