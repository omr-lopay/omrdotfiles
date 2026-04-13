#!/usr/bin/env zsh
# lpy-init.sh — Interactive first-login onboarding wizard
# Sourced via `lpy init` (not executed as subprocess) so it can
# write ~/.lpy.conf and source ~/.zshrc in the current shell.

_BOLD="\033[1m"
_DIM="\033[2m"
_CYAN="\033[36m"
_GREEN="\033[32m"
_YELLOW="\033[33m"
_RED="\033[31m"
_RESET="\033[0m"

_check="${_GREEN}✓${_RESET}"
_cross="${_RED}✗${_RESET}"

_LPY_CONF="$HOME/.lpy.conf"

# ── detection helpers ──────────────────────────────────────

_init_has_git_identity() {
  local name email
  name="$(git config --global user.name 2>/dev/null)"
  email="$(git config --global user.email 2>/dev/null)"
  [[ -n "$name" && -n "$email" ]]
}

_init_has_github_ssh() {
  [[ -f "$HOME/.ssh/.github_verified" ]] && return 0
  if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
         -T git@github.com 2>&1 | grep -q "Hi "; then
    touch "$HOME/.ssh/.github_verified"
    return 0
  fi
  return 1
}

_init_has_gh_auth() {
  gh auth status >/dev/null 2>&1
}

_init_has_repos() {
  [[ -d "$HOME/code/lopay-api/.git" ]]
}

# ── banner ─────────────────────────────────────────────────

printf "\n"
printf "  ${_BOLD}${_CYAN}┌──────────────────────────────────────────┐${_RESET}\n"
printf "  ${_BOLD}${_CYAN}│        Welcome to Lopay dev!             │${_RESET}\n"
printf "  ${_BOLD}${_CYAN}│   Let's get your environment set up.     │${_RESET}\n"
printf "  ${_BOLD}${_CYAN}└──────────────────────────────────────────┘${_RESET}\n"
printf "\n"

# ══════════════════════════════════════════════════════════
#  PHASE 1: Get Connected
# ══════════════════════════════════════════════════════════

printf "  ${_BOLD}Phase 1: Get Connected${_RESET}\n\n"

# ── Step 1: Git identity ──────────────────────────────────

printf "  ${_BOLD}[1/7]${_RESET} Git identity\n"

if _init_has_git_identity; then
  local _cur_name="$(git config --global user.name)"
  local _cur_email="$(git config --global user.email)"
  printf "        ${_check}  ${_cur_name} <${_cur_email}>\n\n"
else
  local _git_name _git_email

  printf "        Your name: "
  read -r _git_name
  while [[ -z "$_git_name" ]]; do
    printf "        Name is required: "
    read -r _git_name
  done

  printf "        Your email: "
  read -r _git_email
  while [[ -z "$_git_email" ]]; do
    printf "        Email is required: "
    read -r _git_email
  done

  git config --global user.name "$_git_name"
  git config --global user.email "$_git_email"
  printf "        ${_check}  Set to ${_git_name} <${_git_email}>\n\n"
fi

# ── Step 2: SSH key → GitHub ──────────────────────────────

printf "  ${_BOLD}[2/7]${_RESET} SSH key\n"

if _init_has_github_ssh; then
  printf "        ${_check}  SSH key verified with GitHub\n\n"
else
  local _pubkey_path="$HOME/.ssh/id_ed25519.pub"

  if [[ ! -f "$_pubkey_path" ]]; then
    printf "        ${_cross}  No SSH key found at ${_pubkey_path}\n"
    printf "        Run: ${_BOLD}ssh-keygen -t ed25519${_RESET}\n\n"
  else
    printf "\n        Your public key:\n"
    printf "        ${_DIM}────────────────────────────────────────${_RESET}\n"
    printf "        "
    cat "$_pubkey_path"
    printf "        ${_DIM}────────────────────────────────────────${_RESET}\n\n"
    printf "        1. Copy the key above\n"
    printf "        2. Go to: ${_BOLD}https://github.com/settings/ssh/new${_RESET}\n"
    printf "        3. Paste it and save\n\n"
    printf "        Press ${_BOLD}Enter${_RESET} when done (or ${_DIM}s${_RESET} to skip)... "

    local _ssh_answer
    read -r _ssh_answer

    if [[ "$_ssh_answer" == "s" || "$_ssh_answer" == "S" ]]; then
      printf "        ${_DIM}Skipped — run 'lpy init' later to retry${_RESET}\n\n"
    else
      printf "        Verifying... "
      if _init_has_github_ssh; then
        printf "${_check}  Verified!\n\n"
      else
        printf "${_cross}  Could not verify (this is OK — it may take a moment)\n"
        printf "        ${_DIM}You can verify later with: ssh -T git@github.com${_RESET}\n\n"
      fi
    fi
  fi
fi

# ── Step 3: GitHub CLI auth ───────────────────────────────

printf "  ${_BOLD}[3/7]${_RESET} GitHub CLI\n"

if _init_has_gh_auth; then
  printf "        ${_check}  Already authenticated\n\n"
else
  printf "        Let's authenticate the GitHub CLI.\n\n"
  gh auth login
  echo

  if _init_has_gh_auth; then
    printf "        ${_check}  GitHub CLI authenticated\n\n"
  else
    printf "        ${_cross}  Auth not completed — run ${_BOLD}gh auth login${_RESET} later\n\n"
  fi
fi

# ── Step 4: Clone repos ──────────────────────────────────

printf "  ${_BOLD}[4/7]${_RESET} Repos\n"

if _init_has_repos; then
  printf "        ${_check}  Already cloned (~/code/lopay-api)\n\n"
else
  printf "        Cloning repos into ~/code/...\n"
  if [[ -x "$HOME/setup-repos.sh" ]]; then
    "$HOME/setup-repos.sh"
    if _init_has_repos; then
      printf "        ${_check}  Repos cloned\n\n"
    else
      printf "        ${_cross}  Clone may have failed — check above for errors\n"
      printf "        ${_DIM}You can retry with: ~/setup-repos.sh${_RESET}\n\n"
    fi
  else
    printf "        ${_cross}  setup-repos.sh not found\n\n"
  fi
fi

# ══════════════════════════════════════════════════════════
#  PHASE 2: Personalise Your Terminal
# ══════════════════════════════════════════════════════════

printf "  ${_DIM}──────────────────────────────────────────${_RESET}\n"
printf "  ${_BOLD}${_GREEN}Connection all set!${_RESET} Now let's make your\n"
printf "  terminal feel like home.\n"
printf "  ${_DIM}──────────────────────────────────────────${_RESET}\n\n"

printf "  ${_BOLD}Phase 2: Personalise Your Terminal${_RESET}\n\n"

# ── Step 5: Prompt style ──────────────────────────────────

printf "  ${_BOLD}[5/7]${_RESET} Prompt style\n\n"
printf "        ${_BOLD}[1]${_RESET} Minimal\n"
printf "            ${_YELLOW}~/code/lopay-api${_RESET} %%\n\n"
printf "        ${_BOLD}[2]${_RESET} Standard\n"
printf "            ${_CYAN}ubuntu@lopay-dev${_RESET}:${_YELLOW}~/code/lopay-api${_RESET} ${_GREEN}(main)${_RESET} %%\n\n"
printf "        ${_BOLD}[3]${_RESET} Full\n"
printf "            ${_CYAN}ubuntu@lopay-dev${_RESET}:${_YELLOW}~/code/lopay-api${_RESET} ${_GREEN}(main)${_RESET}${_DIM} node:22.14${_RESET} %%\n\n"

local _prompt_choice
printf "        Choice [2]: "
read -r _prompt_choice

local _lpy_prompt_val
case "$_prompt_choice" in
  1) _lpy_prompt_val="minimal" ;;
  3) _lpy_prompt_val="full" ;;
  *) _lpy_prompt_val="standard" ;;
esac
printf "        ${_check}  ${_lpy_prompt_val}\n\n"

# ── Step 6: Shell enhancements ────────────────────────────

printf "  ${_BOLD}[6/7]${_RESET} Shell enhancements\n"
printf "        ${_DIM}Enter numbers separated by spaces, or 'all' for everything${_RESET}\n\n"
printf "        ${_BOLD}[1]${_RESET} bat     — syntax-highlighted cat replacement\n"
printf "        ${_BOLD}[2]${_RESET} eza     — modern ls with colors and grouping\n"
printf "        ${_BOLD}[3]${_RESET} icons   — file type icons in eza ${_DIM}(needs Nerd Font)${_RESET}\n"
printf "        ${_BOLD}[4]${_RESET} zsh-hl  — syntax highlighting as you type\n\n"

local _enhance_choice
printf "        Choice [1 2 4]: "
read -r _enhance_choice
[[ -z "$_enhance_choice" ]] && _enhance_choice="1 2 4"

local _lpy_bat=0 _lpy_eza=0 _lpy_icons=0 _lpy_syntax=0

if [[ "$_enhance_choice" == "all" ]]; then
  _lpy_bat=1; _lpy_eza=1; _lpy_icons=1; _lpy_syntax=1
else
  for _n in ${=_enhance_choice}; do
    case "$_n" in
      1) _lpy_bat=1 ;;
      2) _lpy_eza=1 ;;
      3) _lpy_icons=1 ;;
      4) _lpy_syntax=1 ;;
    esac
  done
fi

local _enhance_summary=""
(( _lpy_bat ))    && _enhance_summary="${_enhance_summary}bat, "
(( _lpy_eza ))    && _enhance_summary="${_enhance_summary}eza, "
(( _lpy_icons ))  && _enhance_summary="${_enhance_summary}icons, "
(( _lpy_syntax )) && _enhance_summary="${_enhance_summary}syntax highlighting, "
_enhance_summary="${_enhance_summary%, }"
[[ -z "$_enhance_summary" ]] && _enhance_summary="none"

printf "        ${_check}  ${_enhance_summary}\n\n"

# ── Step 7: Git shortcuts ────────────────────────────────

printf "  ${_BOLD}[7/7]${_RESET} Git shortcuts\n"
printf "        ${_DIM}Aliases: gs (status), gc (commit), gp (push), gl (log), ...${_RESET}\n"
printf "        ${_DIM}FZF helpers: gcof (fuzzy checkout), grf (fuzzy stage), glf (browse commits)${_RESET}\n\n"

local _git_choice
printf "        Enable? [Y/n]: "
read -r _git_choice

local _lpy_git_aliases=1 _lpy_git_fzf=1
case "$_git_choice" in
  [Nn]) _lpy_git_aliases=0; _lpy_git_fzf=0 ;;
esac

if (( _lpy_git_aliases )); then
  printf "        ${_check}  aliases + fzf helpers\n\n"
else
  printf "        ${_check}  disabled\n\n"
fi

# ══════════════════════════════════════════════════════════
#  Save & apply
# ══════════════════════════════════════════════════════════

cat > "$_LPY_CONF" <<EOF
# Lopay shell preferences — generated by 'lpy init'
LPY_PROMPT=$_lpy_prompt_val
LPY_USE_BAT=$_lpy_bat
LPY_USE_EZA=$_lpy_eza
LPY_EZA_ICONS=$_lpy_icons
LPY_SYNTAX_HIGHLIGHTING=$_lpy_syntax
LPY_GIT_ALIASES=$_lpy_git_aliases
LPY_GIT_FZF=$_lpy_git_fzf
LPY_CLIPBOARD=0
EOF

touch "$HOME/.lpy-init-done"

# Build summary
local _git_name_final="$(git config --global user.name 2>/dev/null)"
local _git_email_final="$(git config --global user.email 2>/dev/null)"
local _git_id_line="${_git_name_final} <${_git_email_final}>"

local _github_line=""
_init_has_github_ssh && _github_line="${_github_line}SSH key"
_init_has_gh_auth && {
  [[ -n "$_github_line" ]] && _github_line="${_github_line} + "
  _github_line="${_github_line}CLI"
}
[[ -z "$_github_line" ]] && _github_line="incomplete — run lpy init to retry"

local _repos_line="not cloned"
_init_has_repos && _repos_line="~/code/lopay-api"

local _git_shortcuts_line="off"
(( _lpy_git_aliases )) && _git_shortcuts_line="aliases + fzf helpers"

printf "  ${_DIM}──────────────────────────────────────────${_RESET}\n"
printf "  ${_GREEN}${_BOLD}All done!${_RESET} Here's what we set up:\n\n"
printf "    Git:       ${_git_id_line}\n"
printf "    GitHub:    ${_github_line}\n"
printf "    Repos:     ${_repos_line}\n"
printf "    Prompt:    ${_lpy_prompt_val}\n"
printf "    Tools:     ${_enhance_summary}\n"
printf "    Git keys:  ${_git_shortcuts_line}\n\n"
printf "  Run ${_BOLD}lpy setup${_RESET} anytime to change preferences.\n"
printf "  Run ${_BOLD}lpy init${_RESET} to re-run this wizard.\n"
printf "  ${_DIM}──────────────────────────────────────────${_RESET}\n\n"

# Reload shell config so choices take effect immediately
source "$HOME/.zshrc"
