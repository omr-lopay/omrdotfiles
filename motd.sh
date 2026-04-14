#!/usr/bin/env zsh
# MOTD — sourced from .zshrc on interactive login

_MOTD_PURPLE="\033[38;2;113;124;188m"
_MOTD_GREEN="\033[32m"
_MOTD_RED="\033[31m"
_MOTD_BOLD="\033[1m"
_MOTD_RESET="\033[0m"

_MOTD_CHECK="${_MOTD_GREEN}✓${_MOTD_RESET}"
_MOTD_CROSS="${_MOTD_RED}✗${_MOTD_RESET}"

# ── banner ─────────────────────────────────────────────────

echo ''
printf "${_MOTD_PURPLE}"
echo '__         ______     ______   ______     __  __    '
echo '/\ \       /\  __ \   /\  == \ /\  __ \   /\ \_\ \   '
echo '\ \ \____  \ \ \/\ \  \ \  _-/ \ \  __ \  \ \____ \  '
echo ' \ \_____\  \ \_____\  \ \_\    \ \_\ \_\  \/\_____\ '
echo '  \/_____/   \/_____/   \/_/     \/_/\/_/   \/_____/ '
printf "${_MOTD_RESET}"
echo ''

# ── first login — wizard handles everything, just show banner ─

[[ ! -f "$HOME/.lpy-init-done" ]] && return 0

# ── subsequent logins — show checklist if incomplete ──────

local _motd_git_ok=false _motd_ssh_ok=false _motd_gh_ok=false _motd_repos_ok=false

# Git identity
local _n _e
_n="$(git config --global user.name 2>/dev/null)"
_e="$(git config --global user.email 2>/dev/null)"
[[ -n "$_n" && -n "$_e" ]] && _motd_git_ok=true

# SSH key verified
[[ -f "$HOME/.ssh/.github_verified" ]] && _motd_ssh_ok=true

# gh auth
gh auth status >/dev/null 2>&1 && _motd_gh_ok=true

# Repos
[[ -d "$HOME/code/lopay-api/.git" ]] && _motd_repos_ok=true

local _motd_tunnel=""
[[ -f "$HOME/.tunnel-url" ]] && _motd_tunnel=$(cat "$HOME/.tunnel-url")

if $_motd_git_ok && $_motd_ssh_ok && $_motd_gh_ok && $_motd_repos_ok; then
  printf "  ${_MOTD_GREEN}${_MOTD_BOLD}All set.${_MOTD_RESET} Happy coding!\n"
  echo ''
  if [[ -n "$_motd_tunnel" ]]; then
    printf "  ${_MOTD_BOLD}HTTPS Tunnel${_MOTD_RESET}  ${_motd_tunnel}\n"
    printf "  ${_MOTD_RESET}Run ${_MOTD_BOLD}sloth tunnel${_MOTD_RESET} to see all ports or expose new ones.\n"
    echo ''
  fi
  return 0
fi

printf "  Setup checklist:\n\n"

$_motd_gh_ok   && printf "  ${_MOTD_CHECK}  GitHub authenticated\n"     || printf "  ${_MOTD_CROSS}  GitHub not authenticated\n"
$_motd_ssh_ok  && printf "  ${_MOTD_CHECK}  SSH key on GitHub\n"       || printf "  ${_MOTD_CROSS}  SSH key not on GitHub\n"
$_motd_git_ok  && printf "  ${_MOTD_CHECK}  Git identity configured\n" || printf "  ${_MOTD_CROSS}  Git identity not set\n"
$_motd_repos_ok && printf "  ${_MOTD_CHECK}  Repos cloned\n"            || printf "  ${_MOTD_CROSS}  Repos not cloned\n"

printf "\n  Run ${_MOTD_BOLD}sloth init${_MOTD_RESET} to finish setup.\n"
echo ''
