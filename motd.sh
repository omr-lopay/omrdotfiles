#!/bin/bash
# Dynamic MOTD — shows setup checklist on login
# Installed to /etc/update-motd.d/99-lopay (runs as root)

PURPLE="\033[38;2;113;124;188m"
GREEN="\033[32m"
RED="\033[31m"
BOLD="\033[1m"
DIM="\033[2m"
RESET="\033[0m"

CHECK="${GREEN}✓${RESET}"
CROSS="${RED}✗${RESET}"

# MOTD scripts run as root — target the login user's home
USER_HOME="/home/ubuntu"

# ── state detection ────────────────────────────────────────

check_git_identity() {
  local name email
  name="$(sudo -u ubuntu git config --global user.name 2>/dev/null)"
  email="$(sudo -u ubuntu git config --global user.email 2>/dev/null)"
  [[ -n "$name" && -n "$email" ]]
}

check_github_ssh() {
  [[ -f "$USER_HOME/.ssh/.github_verified" ]]
}

check_gh_auth() {
  sudo -u ubuntu bash -c 'gh auth status' >/dev/null 2>&1
}

check_repos() {
  [[ -d "$USER_HOME/code/lopay-api/.git" ]]
}

# ── run checks ─────────────────────────────────────────────

git_ok=false;   check_git_identity && git_ok=true
ssh_ok=false;   check_github_ssh   && ssh_ok=true
gh_ok=false;    check_gh_auth      && gh_ok=true
repos_ok=false; check_repos        && repos_ok=true

all_done=true
for v in $git_ok $ssh_ok $gh_ok $repos_ok; do
  [[ "$v" == "false" ]] && all_done=false && break
done

# ── render ─────────────────────────────────────────────────

echo ''
printf "${PURPLE}"
echo '__         ______     ______   ______     __  __    '
echo '/\ \       /\  __ \   /\  == \ /\  __ \   /\ \_\ \   '
echo '\ \ \____  \ \ \/\ \  \ \  _-/ \ \  __ \  \ \____ \  '
echo ' \ \_____\  \ \_____\  \ \_\    \ \_\ \_\  \/\_____\ '
echo '  \/_____/   \/_____/   \/_/     \/_/\/_/   \/_____/ '
printf "${RESET}"
echo ''

if $all_done; then
  printf "  ${GREEN}${BOLD}All set.${RESET} Happy coding!\n"
  echo ''
  exit 0
fi

printf "  Setup checklist:\n\n"

$git_ok  && printf "  ${CHECK}  Git identity\n"            || printf "  ${CROSS}  Git identity not set\n"
$ssh_ok  && printf "  ${CHECK}  SSH key on GitHub\n"       || printf "  ${CROSS}  SSH key not on GitHub\n"
$gh_ok   && printf "  ${CHECK}  GitHub CLI authenticated\n" || printf "  ${CROSS}  GitHub CLI not authenticated\n"
$repos_ok && printf "  ${CHECK}  Repos cloned\n"            || printf "  ${CROSS}  Repos not cloned\n"

printf "\n  Run ${BOLD}lpy init${RESET} to finish setup.\n"
echo ''
