#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
docker build -t ahome --build-arg USERNAME="$USER" "$SCRIPT_DIR" && docker run -it -v "$REPO_DIR":/home/"${USER}"/ahome ahome
