#!/bin/bash
nix run home-manager -- switch --flake .#$USER
