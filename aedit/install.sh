#!/usr/bin/env sh
#
# arpad's aedit installer w/ config
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/arpadav/home/main/aedit/install.sh | sh
#
# Author: aav
# --------------------------------------------------
set -eu
command -v curl >/dev/null 2>&1 || {
    echo "curl is required but not installed" >&2
    exit 1
}
# --------------------------------------------------
# make tmp dir to download file into
# --------------------------------------------------
HI=$(mktemp "${TMPDIR:-/tmp}/hi-XXXXXX") || {
    echo "could not create a temp file" >&2
    exit 1
}
trap 'rm -f "$HI"' EXIT
curl -fsSL https://raw.githubusercontent.com/arpadav/home/main/hi.sh -o "$HI" ||
    {
        echo "could not download hi.sh" >&2
        exit 1
    }
[ -s "$HI" ] || {
    echo "downloaded hi.sh is empty" >&2
    exit 1
}
# --------------------------------------------------
# run
# --------------------------------------------------
sh "$HI" \
    --runner home-manager/master \
    --flake "github:arpadav/home?dir=aedit#headless" \
    --name "arpad's aedit"
