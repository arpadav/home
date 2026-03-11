#!/usr/bin/env sh
#
# arpad home - full environment headless installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/arpadav/home/main/install.sh | sh
#
# Author: aav
# --------------------------------------------------
command -v curl >/dev/null 2>&1 || echo "curl is required but not installed"
curl -fsSL https://raw.githubusercontent.com/arpadav/home/main/hi.sh | sh -s -- \
    --runner home-manager/master \
    --flake "github:arpadav/home" \
    --name "arpad's home env"
