############################################################
# Bastion config (loaded from ~/.bastion.env)
############################################################
export BASTION_DB_PORT="5432"
export BASTION_DB_HOST="127.0.0.1"

BASTION_ENV="$HOME/.bastion.env"
if [[ -f "$BASTION_ENV" ]]; then
  source "$BASTION_ENV"
fi

############################################################
# nvm Setup
############################################################
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

############################################################
# Auto-switch Node version based on .nvmrc
############################################################
autoload -U add-zsh-hook

load-nvmrc() {
  command -v nvm >/dev/null 2>&1 || return

  local nvmrc_path="$PWD/.nvmrc"
  if [ -f "$nvmrc_path" ]; then
    local wanted
    wanted="$(<"$nvmrc_path")"

    if ! nvm ls "$wanted" >/dev/null 2>&1; then
      nvm install >/dev/null 2>&1
    fi

    if [ "$(nvm current 2>/dev/null)" != "v${wanted#v}" ]; then
      nvm use >/dev/null 2>&1
    fi
  else
    local def
    def="$(nvm version default 2>/dev/null)"
    if [ -n "$def" ] && [ "$(nvm current 2>/dev/null)" != "$def" ]; then
      nvm use default >/dev/null 2>&1
    fi
  fi
}

add-zsh-hook chpwd load-nvmrc
load-nvmrc

############################################################
# QoL
############################################################

# Syntax highlighting
[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Aliases
alias ..="cd .."
alias ...="cd ../.."
alias cat="bat"
alias ls='eza --icons --group-directories-first'
alias ll='eza -lh --icons --group-directories-first'
alias la='eza -lha --icons --group-directories-first'
alias hs='history 1 | grep'
alias ip='curl -s ifconfig.me && echo'
alias cip='curl -s ifconfig.me | xclip -selection clipboard'
alias elast='fc'
alias clod='claude'
alias claude:install='npm install -g @anthropic-ai/claude-code'

# mkcd: make a directory then cd into it
mkcd() { mkdir -p "$1" && cd "$1"; }

# sudo last command
please() {
  local last_cmd
  last_cmd="$(fc -ln -1)"
  if [ -n "$last_cmd" ]; then
    sudo $last_cmd
  else
    echo "No previous command found."
  fi
}

# del: Prompt once before deleting file or directory
del() {
  local target="$1"
  local RED="\033[31m" BLUE="\033[34m" BOLD="\033[1m" DIM="\033[2m" RESET="\033[0m"

  [[ -z "$target" ]] && { echo "Usage: del <file-or-directory>"; return 1; }
  [[ ! -e "$target" ]] && { echo "No such file or directory: $target"; return 1; }

  local NAME COLORED_NAME
  if [[ -d "$target" ]]; then
    NAME="${target%/}/"
    COLORED_NAME="${BLUE}${BOLD}${NAME}${RESET}"
  else
    NAME="$target"
    COLORED_NAME="${RED}${BOLD}${NAME}${RESET}"
  fi

  printf "Delete %b? ${DIM}[Enter=delete, Esc=cancel]${RESET} " "$COLORED_NAME"
  local key
  IFS= read -rsk1 key
  echo

  if [[ "$key" == $'\e' ]]; then
    echo "Aborted."
    return 130
  fi

  if [[ -z "$key" || "$key" == $'\n' || "$key" == 'y' || "$key" == 'Y' ]]; then
    rm -rf -- "$target"
    echo "'$NAME' deleted."
    return 0
  else
    echo "Aborted."
    return 1
  fi
}

# Time how long a command takes
timer() {
  local start end secs status
  start=$(date +%s)
  "$@"
  status=$?
  end=$(date +%s)
  secs=$((end - start))

  local BOLD="\033[1m" RED="\033[31m" GREEN="\033[32m" RESET="\033[0m"
  local COLOR=$([ $status -eq 0 ] && echo "$GREEN" || echo "$RED")

  printf "%bTook %ds%b\n" "${BOLD}${COLOR}" "$secs" "$RESET"
  return $status
}

# Copy name of current git branch
copybranch() {
  git rev-parse --abbrev-ref HEAD | xclip -selection clipboard
}

# Guided connection to postgres (using pgcli)
pgc() {
  command -v pgcli >/dev/null 2>&1 || { echo "pgcli not found. pipx install pgcli"; return 127; }

  local host port user db pass
  read -r "host?Host [localhost]: "
  host=${host:-localhost}

  read -r "port?Port [5432]: "
  port=${port:-5432}

  read -r "user?User [${USER}]: "
  user=${user:-$USER}

  read -r "db?Database (required): "
  if [[ -z "$db" ]]; then
    echo "Database name is required."; return 1
  fi

  read -rs "pass?Password (leave blank to let pgcli prompt): "
  echo

  if [[ -n "$pass" ]]; then
    PGPASSWORD="$pass" pgcli -h "$host" -p "$port" -U "$user" "$db"
  else
    pgcli -h "$host" -p "$port" -U "$user" "$db"
  fi
}

# Kill whatever is using a given port
killport() { lsof -ti tcp:"$1" | xargs -r kill -9; }

# Show process using a given port
checkport() {
  local port=$1
  if [[ -z "$port" ]]; then
    echo "Usage: checkport <port>"
    return 1
  fi
  lsof -nP -iTCP:$port -sTCP:LISTEN | awk 'NR==1 || /LISTEN/'
}

# Interactive TS REPL
tsrepl() {
  npx ts-node --transpile-only --interactive
}

############################################################
# Git QoL + ghelp
############################################################

alias gs='git status -sb'
alias ga='git add'
alias gap='git add -p'
alias gc='git commit -v'
alias gca='git commit -v --amend'
alias gco='git checkout'
alias gb='git branch -vv'
alias gbdm='git branch --merged main | grep -vE "^\*? *main$" | xargs -r git branch -d'
alias gp='git push'
alias gpl='git pull --rebase --autostash'
alias gl='git log --oneline --graph --decorate --boundary'
alias glg='git log --graph --pretty=format:"%C(auto)%h %C(bold blue)%ad %Creset%<(60,trunc)%s %C(italic dim)%an%Creset %C(green)%d" --date=short'

# Fuzzy checkout any branch (local/remote)
gcof() {
  if ! command -v fzf >/dev/null 2>&1; then
    echo "gcof needs fzf (apt install fzf)"; return 127
  fi
  git for-each-ref --format='%(refname:short)' refs/heads refs/remotes \
  | sed 's#^remotes/[^/]*/##' | sort -u \
  | fzf --height=40% --reverse --prompt='branch> ' \
  | xargs -r git checkout
}

# Fuzzy add from git status (multi-select)
grf() {
  if ! command -v fzf >/dev/null 2>&1; then
    echo "grf needs fzf (apt install fzf)"; return 127
  fi
  git -c color.status=always status --short \
  | fzf --ansi --multi --height=60% --reverse --prompt='stage> ' \
  | awk '{print $2}' | xargs -r git add
}

# Fuzzy browse commits with preview
glf() {
  if ! command -v fzf >/dev/null 2>&1; then
    echo "glf needs fzf (apt install fzf)"; return 127
  fi
  git log --oneline --decorate --graph --color=always \
  | fzf --ansi --no-sort --reverse --height=80% \
        --preview 'git show --color=always {1}' \
        --prompt='commit> ' \
        --bind 'enter:execute(git show {1} | less -R)'
}

# Create a new branch (optionally from a base branch/ref)
gnew() {
  local name="$1"
  local base="$2"

  if [[ -z "$name" ]]; then
    echo "Usage: gnew <branch-name> [base-branch-or-ref]"
    return 1
  fi

  if [[ -n "$base" ]]; then
    git checkout -b "$name" "$base"
  else
    git checkout -b "$name"
  fi
}

# ghelp: discover git commands & usage
typeset -A __GIT_HELP_DESC __GIT_HELP_USAGE

__GIT_HELP_DESC=(
  gs    "git status (short)"
  ga    "git add <paths>"
  gap   "git add -p (patch)"
  gc    "git commit -v"
  gca   "git commit -v --amend"
  gco   "git checkout <branch|--|path>"
  gnew  "create and checkout a new branch (optionally from base)"
  gcof  "fzf: checkout any branch (local/remote)"
  gb    "git branch -vv"
  gbdm  "delete branches merged into main"
  gp    "git push"
  gpl   "git pull --rebase --autostash"
  gl    "log: oneline graph"
  glg   "log: pretty graph with dates/authors"
  grf   "fzf: interactively stage files"
  glf   "fzf: browse commits with preview"
)

__GIT_HELP_USAGE=(
  gs  $'Usage: gs\nShows short status with branch/changes.\nEquivalent: git status -sb'
  ga  $'Usage: ga <path...>\nStage files for the next commit.'
  gap $'Usage: gap\nInteractive patch staging (add -p).'
  gc  $'Usage: gc\nOpens commit editor with verbose diff (commit.verbose).'
  gca $'Usage: gca\nAmends the last commit (keeps message unless editor configured).'
  gco $'Usage: gco <branch>\n       gco -- <path>\nSwitch branch or restore paths.'
  gnew $'Usage: gnew <branch-name> [base]\nCreates and checks out a new branch.\nIf base is provided, branch is created from that ref; otherwise from current branch.'
  gcof $'Usage: gcof\nFuzzy-pick a branch (local/remote) to checkout.\nRequires: fzf'
  gb  $'Usage: gb\nList branches with upstream and last commit.'
  gbdm $'Usage: gbdm\nDelete all branches fully merged into main (except main).'
  gp  $'Usage: gp\nPush current branch.'
  gpl $'Usage: gpl\nPull with rebase and autostash.'
  gl  $'Usage: gl\nCompact commit graph (oneline).'
  glg $'Usage: glg\nPretty, wrapped commit graph with date/author/refs.'
  grf $'Usage: grf\nFuzzy-select files from git status to stage (multi-select).\nRequires: fzf'
  glf $'Usage: glf\nFuzzy browse commits; Enter to open commit in less; right pane shows diff.\nRequires: fzf'
)

ghelp() {
  local subcmd="$1"
  shift || true

  if [[ -n "$subcmd" && "$subcmd" != "grep" ]]; then
    local key
    for key in "${(@k)__GIT_HELP_USAGE}"; do
      if [[ "$key" == "$subcmd" ]]; then
        print -r -- "$__GIT_HELP_USAGE[$key]"
        return 0
      fi
    done
    local matches=()
    for key in "${(@k)__GIT_HELP_DESC}"; do
      if [[ "$key" == *"$subcmd"* || "${__GIT_HELP_DESC[$key]}" == *"$subcmd"* ]]; then
        matches+="$key"
      fi
    done
    if (( ${#matches} )); then
      for key in "${matches[@]}"; do
        printf '%-6s %s\n' "$key" "${__GIT_HELP_DESC[$key]}"
      done | sort
      return 0
    else
      echo "ghelp: no match for '$subcmd'"; return 1
    fi
  fi

  if [[ "$subcmd" == "grep" ]]; then
    local pat="$1"
    [[ -z "$pat" ]] && { echo "Usage: ghelp grep <pattern>"; return 1; }
    for key in "${(@k)__GIT_HELP_DESC}"; do
      if [[ "$key" == *"$pat"* || "${__GIT_HELP_DESC[$key]}" == *"$pat"* ]]; then
        printf '%-6s %s\n' "$key" "${__GIT_HELP_DESC[$key]}"
      fi
    done | sort
    return 0
  fi

  for key in "${(@k)__GIT_HELP_DESC}"; do
    printf '%-6s %s\n' "$key" "${__GIT_HELP_DESC[$key]}"
  done | sort
}

############################################################
# Bastion SSM helpers
############################################################
export BASTION_STATE_DIR="${XDG_RUNTIME_DIR:-$HOME/.cache}/bastion"
mkdir -p "$BASTION_STATE_DIR"

_bastion_is_configured() {
  [[ -f "$BASTION_ENV" ]] && [[ -n "$BASTION_EU_INSTANCE" || -n "$BASTION_US_INSTANCE" ]]
}

_bastion_require_setup() {
  if ! _bastion_is_configured; then
    echo "Bastion is not configured. Run 'bastion setup' first."
    return 1
  fi
}

_bastion_setup() {
  local BOLD="\033[1m" DIM="\033[2m" CYAN="\033[36m" RESET="\033[0m"

  printf "\n${BOLD}${CYAN}Bastion Setup${RESET}\n"
  printf "${DIM}Credentials are saved to ~/.bastion.env (not committed to git).${RESET}\n\n"

  # Load existing values as defaults if re-running setup
  local cur_eu_name="${BASTION_DB_NAME_EU}" cur_eu_user="${BASTION_DB_USER_EU}" cur_eu_pass="${BASTION_DB_PASS_EU}"
  local cur_us_name="${BASTION_DB_NAME_US}" cur_us_user="${BASTION_DB_USER_US}" cur_us_pass="${BASTION_DB_PASS_US}"
  local cur_eu_inst="${BASTION_EU_INSTANCE}" cur_us_inst="${BASTION_US_INSTANCE}"

  local val

  # EU
  printf "${BOLD}EU (eu-west-2)${RESET}\n"

  read -r "val?  EC2 Instance ID${cur_eu_inst:+ [$cur_eu_inst]}: "
  local eu_inst="${val:-$cur_eu_inst}"

  read -r "val?  DB Name${cur_eu_name:+ [$cur_eu_name]}: "
  local eu_name="${val:-$cur_eu_name}"

  read -r "val?  DB User${cur_eu_user:+ [$cur_eu_user]}: "
  local eu_user="${val:-$cur_eu_user}"

  read -rs "val?  DB Password${cur_eu_pass:+ [********]}: "
  echo
  local eu_pass="${val:-$cur_eu_pass}"

  # US
  printf "\n${BOLD}US (us-east-1)${RESET}\n"

  read -r "val?  EC2 Instance ID${cur_us_inst:+ [$cur_us_inst]}: "
  local us_inst="${val:-$cur_us_inst}"

  read -r "val?  DB Name${cur_us_name:+ [$cur_us_name]}: "
  local us_name="${val:-$cur_us_name}"

  read -r "val?  DB User${cur_us_user:+ [$cur_us_user]}: "
  local us_user="${val:-$cur_us_user}"

  read -rs "val?  DB Password${cur_us_pass:+ [********]}: "
  echo

  local us_pass="${val:-$cur_us_pass}"

  # Write config
  cat > "$BASTION_ENV" <<EOF
# Bastion config — generated by 'bastion setup'
export BASTION_DB_NAME_EU="$eu_name"
export BASTION_DB_USER_EU="$eu_user"
export BASTION_DB_PASS_EU="$eu_pass"
export BASTION_DB_NAME_US="$us_name"
export BASTION_DB_USER_US="$us_user"
export BASTION_DB_PASS_US="$us_pass"
export BASTION_EU_INSTANCE="$eu_inst"
export BASTION_US_INSTANCE="$us_inst"
EOF
  chmod 600 "$BASTION_ENV"

  # Reload into current shell
  source "$BASTION_ENV"

  printf "\n${BOLD}Done.${RESET} Config saved to ~/.bastion.env\n"
}

_bastion_alias_to_region() {
  case "$1" in
    eu) echo "eu-west-2" ;;
    us) echo "us-east-1" ;;
    *)  echo "$1" ;;
  esac
}

_bastion_pidfile() { echo "$BASTION_STATE_DIR/$1.pid"; }
_bastion_logfile() { echo "$BASTION_STATE_DIR/$1.log"; }

_bastion_read_ids() {
  local pidfile="$(_bastion_pidfile "$1")" line
  [[ -f "$pidfile" ]] || return 1
  line="$(<"$pidfile")" || return 1
  PID="${line%%:*}"
  PGID="${line#*:}"
  [[ "$PGID" == "$line" ]] && PGID=""
  [[ -n "$PID" ]] || return 1
}

_bastion_is_alive() {
  _bastion_read_ids "$1" || return 1
  kill -0 "$PID" 2>/dev/null
}

_bastion_kill_lingering_port() {
  local port="${BASTION_DB_PORT:-5432}"
  local pids; pids="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null)" || true
  [[ -z "$pids" ]] && return 0
  for p in $pids; do
    if ps -o comm= -p "$p" | grep -qE '(^|/)(aws|session-manager-plugin)$'; then
      kill -9 "$p" 2>/dev/null || true
    fi
  done
}

_bastion_start() {
  local alias="$1"; shift
  local region="$(_bastion_alias_to_region "$alias")"
  local instance_id="$1"; shift
  local reason="$*"

  local pidfile="$(_bastion_pidfile "$alias")"
  local logfile="$(_bastion_logfile "$alias")"

  if _bastion_is_alive "$alias"; then
    echo "[$alias] already running (pid ${PID})."
    return 0
  fi

  nohup aws ssm start-session \
    --region "$region" \
    --target "$instance_id" \
    --document-name "Lopay-StartDBPortForwardingSession" \
    --reason "${reason:-Started via zsh helper}" \
    >>"$logfile" 2>&1 &

  local child_pid=$!
  sleep 0.3
  local pgid; pgid="$(ps -o pgid= -p "$child_pid" 2>/dev/null | tr -d ' ')"
  if [[ -n "$pgid" ]]; then
    echo "${child_pid}:${pgid}" > "$pidfile"
  else
    echo "${child_pid}" > "$pidfile"
  fi

  if ! _bastion_is_alive "$alias"; then
    echo "[$alias] failed to start. See log: $logfile"
    rm -f "$pidfile" 2>/dev/null
    return 1
  fi
  echo "[$alias] session started (pid ${PID}${PGID:+, pgid $PGID}). Log: $logfile"
}

_bastion_status() {
  local alias="$1"
  if _bastion_is_alive "$alias"; then
    echo "[$alias] running (pid ${PID}${PGID:+, pgid $PGID})."
  else
    echo "[$alias] not running."
    rm -f "$(_bastion_pidfile "$alias")" 2>/dev/null
  fi
}

_bastion_terminate() {
  local alias="$1"
  local pidfile="$(_bastion_pidfile "$alias")"

  if ! _bastion_is_alive "$alias"; then
    echo "[$alias] not running."
    rm -f "$pidfile" 2>/dev/null
    _bastion_kill_lingering_port
    return 0
  fi

  echo "[$alias] terminating pid ${PID}${PGID:+ (group $PGID)} ..."
  if [[ -n "$PGID" ]]; then
    kill -TERM -- "-$PGID" 2>/dev/null || true
  else
    kill -TERM "$PID" 2>/dev/null || true
  fi

  for i in {1..25}; do
    _bastion_is_alive "$alias" || break
    sleep 0.1
  done

  if _bastion_is_alive "$alias"; then
    if [[ -n "$PGID" ]]; then
      kill -KILL -- "-$PGID" 2>/dev/null || true
    else
      kill -KILL "$PID" 2>/dev/null || true
    fi
  fi

  rm -f "$pidfile" 2>/dev/null
  _bastion_kill_lingering_port
  echo "[$alias] terminated."
}

bastion() {
  local cmd="$1"
  [[ -n "$cmd" ]] || { echo "usage: bastion <setup|start|status|terminate|gurl> [eu|us] [...]"; return 1; }

  if [[ "$cmd" == "setup" ]]; then
    _bastion_setup
    return $?
  fi

  if [[ "$cmd" == "prompt" ]]; then
    local active=()
    for a in eu us; do
      _bastion_is_alive "$a" && active+="$a"
    done
    (( ${#active[@]} )) && echo "${(j:,:)active}"
    return 0
  fi

  # All other commands require config
  _bastion_require_setup || return 1

  shift || { echo "missing region (eu|us)"; return 1; }
  local alias="$1"; shift || true

  local instance_id
  case "$alias" in
    eu) instance_id="$BASTION_EU_INSTANCE" ;;
    us) instance_id="$BASTION_US_INSTANCE" ;;
  esac

  case "$cmd" in
    start)
      if [[ -z "$instance_id" ]]; then
        instance_id="$1"; shift
        [[ -n "$instance_id" ]] || { echo "missing instance id"; return 1; }
      fi
      _bastion_start "$alias" "$instance_id" "$@"
      ;;
    status) _bastion_status "$alias" ;;
    terminate)
      if [[ "$alias" == "all" ]]; then
        _bastion_terminate eu
        _bastion_terminate us
      else
        _bastion_terminate "$alias"
      fi
      ;;
    gurl)
      if [[ -z "$alias" ]]; then
        echo "Usage: bastion gurl eu|us"
        return 1
      fi
      local dbname dbuser dbpass
      case "$alias" in
        eu)
          dbname="$BASTION_DB_NAME_EU"
          dbuser="$BASTION_DB_USER_EU"
          dbpass="$BASTION_DB_PASS_EU"
          ;;
        us)
          dbname="$BASTION_DB_NAME_US"
          dbuser="$BASTION_DB_USER_US"
          dbpass="$BASTION_DB_PASS_US"
          ;;
        *)
          echo "Unknown alias: $alias"
          return 1
          ;;
      esac
      if [[ -z "$dbname" || -z "$dbuser" || -z "$dbpass" ]]; then
        echo "Missing DB config for $alias"
        return 1
      fi
      local url="postgres://${dbuser}:${dbpass}@${BASTION_DB_HOST}:${BASTION_DB_PORT}/${dbname}"
      printf "%s" "$url" | xclip -selection clipboard
      echo "Copied $alias database URL to clipboard."
      ;;
    *) echo "unknown command: $cmd"; return 1 ;;
  esac
}

############################################################
# PATH additions
############################################################

# Google Cloud SDK
if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then . "$HOME/google-cloud-sdk/path.zsh.inc"; fi
if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/google-cloud-sdk/completion.zsh.inc"; fi

export PATH="$HOME/.local/bin:$PATH"

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
