#!/bin/bash
set -euo pipefail

BOLD="\033[1m"
GREEN="\033[32m"
DIM="\033[2m"
RESET="\033[0m"

REPOS_DIR="$HOME/code"
mkdir -p "$REPOS_DIR"

clone_or_update() {
  local url="$1"
  local branch="${2:-}"
  local name="${url##*/}"
  name="${name%.git}"
  local dest="$REPOS_DIR/$name"

  if [[ -d "$dest/.git" ]]; then
    printf "  ${DIM}Already cloned: %s — pulling latest${RESET}\n" "$name"
    git -C "$dest" pull --ff-only --quiet || true
  else
    printf "  Cloning %s...\n" "$name"
    if [[ -n "$branch" ]]; then
      git clone -b "$branch" "$url" "$dest"
    else
      git clone "$url" "$dest"
    fi
  fi
}

printf "\n${BOLD}Cloning Lopay repos into ~/code/${RESET}\n\n"

clone_or_update "https://github.com/lopay-limited/lopay-api.git" "dev-env-improvements"

printf "\n${GREEN}Done.${RESET} Repos are in ~/code/\n\n"
