#!/usr/bin/env sh
#
# arpad's aedit installer w/ config
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/arpadav/home/main/aedit/install.sh | sh
#
# Author: aav
# --------------------------------------------------
command -v curl >/dev/null 2>&1 || echo "curl is required but not installed"
curl -fsSL https://raw.githubusercontent.com/arpadav/home/main/hi.sh | sh -s -- \
    --runner home-manager/master \
    --flake "github:arpadav/home?dir=aedit#headless" \
    --name "arpad's aedit"
