#!/usr/bin/env bash
set -euo pipefail

BOLD="\033[1m"
GREEN="\033[32m"
CYAN="\033[36m"
RED="\033[31m"
RESET="\033[0m"

info()  { printf "${CYAN}::${RESET} %s\n" "$*"; }
ok()    { printf "${GREEN}::${RESET} %s\n" "$*"; }
warn()  { printf "${RED}::${RESET} %s\n" "$*"; }
step()  { printf "\n${BOLD}%s${RESET}\n" "$*"; }

# Write progress to a file for the userdata progress watcher to pick up
SLOTH_PROGRESS_FILE="${SLOTH_PROGRESS_FILE:-}"
sloth_progress() {
  if [[ -n "$SLOTH_PROGRESS_FILE" ]]; then
    echo "$1 $2" > "$SLOTH_PROGRESS_FILE"
  fi
}

if [[ "$(uname)" != "Linux" ]]; then
  warn "This script is intended for Ubuntu/Debian. Exiting."
  exit 1
fi

ARCH="$(dpkg --print-architecture)"  # amd64 or arm64
DOTFILES_REPO="https://github.com/omr-lopay/omrdotfiles.git"
DOTFILES_DIR="$HOME/omrdotfiles"

############################################################
sloth_progress 5 "Cloning dotfiles repo"
step "Clone dotfiles repo"
############################################################
# If running from a transient location (e.g. /tmp via userdata),
# clone the repo so symlinks have a persistent target.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$SCRIPT_DIR" == /tmp* ]]; then
  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    git -C "$DOTFILES_DIR" pull --ff-only || true
    ok "Dotfiles repo updated"
  else
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    ok "Dotfiles repo cloned to $DOTFILES_DIR"
  fi
  SCRIPT_DIR="$DOTFILES_DIR"
elif [[ -d "$SCRIPT_DIR/.git" ]]; then
  DOTFILES_DIR="$SCRIPT_DIR"
  ok "Running from repo at $SCRIPT_DIR"
fi

############################################################
sloth_progress 8 "Installing system packages"
step "apt packages"
############################################################
sudo apt-get update -qq

sudo apt-get install -y \
  zsh \
  git \
  curl \
  wget \
  unzip \
  jq \
  lsof \
  fzf \
  xclip \
  zsh-syntax-highlighting \
  pipx \
  gpg \
  build-essential \
  tmux \
  htop \
  tree \
  ripgrep

# bat — binary is 'batcat' on Ubuntu, symlink to 'bat'
sudo apt-get install -y bat || true
if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
  sudo ln -sf "$(command -v batcat)" /usr/local/bin/bat
  ok "Symlinked batcat -> bat"
fi

ok "apt packages installed"

############################################################
sloth_progress 18 "Installing Docker"
step "Docker"
############################################################
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor --yes -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  sudo usermod -aG docker "$USER"
  ok "Docker installed"
else
  ok "Docker already installed"
fi

############################################################
sloth_progress 28 "Installing GitHub CLI"
step "GitHub CLI"
############################################################
if ! command -v gh >/dev/null 2>&1; then
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y gh
  ok "GitHub CLI installed"
else
  ok "GitHub CLI already installed"
fi

############################################################
sloth_progress 33 "Installing eza"
step "eza (modern ls)"
############################################################
if ! command -v eza >/dev/null 2>&1; then
  sudo mkdir -p /etc/apt/keyrings
  wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
    | sudo gpg --dearmor --yes -o /etc/apt/keyrings/gierens.gpg
  echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
    | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
  sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
  sudo apt-get update -qq
  sudo apt-get install -y eza
  ok "eza installed"
else
  ok "eza already installed"
fi

############################################################
sloth_progress 38 "Installing Node.js"
step "nvm + Node.js"
############################################################
export NVM_DIR="$HOME/.nvm"
if [[ ! -d "$NVM_DIR" ]]; then
  NVM_VERSION="$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r .tag_name)"
  curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
  ok "nvm $NVM_VERSION installed"
else
  ok "nvm already installed"
fi

# shellcheck source=/dev/null
source "$NVM_DIR/nvm.sh"
nvm install --lts
ok "Node.js LTS installed: $(node --version)"

############################################################
sloth_progress 46 "Installing pnpm"
step "pnpm"
############################################################
if ! command -v pnpm >/dev/null 2>&1; then
  curl -fsSL https://get.pnpm.io/install.sh | sh -
  ok "pnpm installed"
else
  ok "pnpm already installed"
fi

############################################################
sloth_progress 50 "Installing pgcli"
step "pgcli"
############################################################
if ! command -v pgcli >/dev/null 2>&1; then
  pipx install pgcli
  ok "pgcli installed"
else
  ok "pgcli already installed"
fi

############################################################
sloth_progress 54 "Installing AWS CLI"
step "AWS CLI"
############################################################
if ! command -v aws >/dev/null 2>&1; then
  if [[ "$ARCH" == "arm64" ]]; then
    AWS_URL="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
  else
    AWS_URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
  fi
  cd /tmp
  curl -fsSL "$AWS_URL" -o awscliv2.zip
  unzip -qo awscliv2.zip
  sudo ./aws/install
  rm -rf awscliv2.zip aws
  ok "AWS CLI installed"
else
  ok "AWS CLI already installed: $(aws --version 2>&1)"
fi

############################################################
sloth_progress 56 "Installing cloudflared"
step "cloudflared"
############################################################
if ! command -v cloudflared >/dev/null 2>&1; then
  curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
    | sudo gpg --dearmor --yes -o /usr/share/keyrings/cloudflare-main.gpg
  echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/cloudflared.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y cloudflared
  ok "cloudflared installed"
else
  ok "cloudflared already installed"
fi

############################################################
sloth_progress 57 "Installing Caddy"
step "Caddy"
############################################################
if ! command -v caddy >/dev/null 2>&1; then
  sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https >/dev/null 2>&1
  curl -fsSL https://dl.cloudsmith.io/public/caddy/stable/gpg.key | sudo gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" \
    | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y caddy
  ok "Caddy installed"
else
  ok "Caddy already installed"
fi

# Configure Caddy as a port router
sudo tee /etc/caddy/Caddyfile > /dev/null <<'CADDYEOF'
:8888 {
  handle_path /:3000/* {
    reverse_proxy localhost:3000
  }
  handle_path /:3029/* {
    reverse_proxy localhost:3029
  }
  handle_path /:4200/* {
    reverse_proxy localhost:4200
  }
  handle {
    reverse_proxy localhost:8080
  }
}
CADDYEOF
sudo systemctl restart caddy
ok "Caddy configured as port router on :8888"

############################################################
sloth_progress 48 "Installing PostgreSQL"
step "PostgreSQL 16"
############################################################
if ! command -v psql >/dev/null 2>&1; then
  sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
  wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo tee /etc/apt/trusted.gpg.d/pgdg.asc >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y postgresql-16
  ok "PostgreSQL 16 installed"
else
  ok "PostgreSQL already installed"
fi

# Configure: create lopay user and databases
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='lopay'" | grep -q 1; then
  ok "PostgreSQL user 'lopay' already exists"
else
  sudo -u postgres psql -c "CREATE USER lopay WITH PASSWORD 'lopay' CREATEDB;"
  ok "PostgreSQL user 'lopay' created"
fi

sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='lopay_local_db'" | grep -q 1 \
  || sudo -u postgres psql -c "CREATE DATABASE lopay_local_db OWNER lopay;"
sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='test-db'" | grep -q 1 \
  || sudo -u postgres psql -c "CREATE DATABASE \"test-db\" OWNER lopay;"
ok "PostgreSQL databases ready"

############################################################
sloth_progress 52 "Installing Redis"
step "Redis"
############################################################
if ! command -v redis-server >/dev/null 2>&1; then
  sudo apt-get install -y redis-server
  ok "Redis installed"
else
  ok "Redis already installed"
fi

# Configure password
if ! grep -q "^requirepass lopay" /etc/redis/redis.conf 2>/dev/null; then
  sudo sed -i 's/^# *requirepass.*/requirepass lopay/' /etc/redis/redis.conf
  sudo systemctl restart redis-server
  ok "Redis password configured"
else
  ok "Redis already configured"
fi

############################################################
sloth_progress 55 "Installing RabbitMQ"
step "RabbitMQ"
############################################################
if ! command -v rabbitmqctl >/dev/null 2>&1; then
  sudo apt-get install -y rabbitmq-server
  ok "RabbitMQ installed"
else
  ok "RabbitMQ already installed"
fi

# Configure user
if sudo rabbitmqctl list_users | grep -q lopay; then
  ok "RabbitMQ user 'lopay' already exists"
else
  sudo rabbitmqctl add_user lopay lopay
  sudo rabbitmqctl set_permissions -p / lopay ".*" ".*" ".*"
  sudo rabbitmqctl set_user_tags lopay administrator
  ok "RabbitMQ user 'lopay' created"
fi

############################################################
sloth_progress 57 "Installing Stripe CLI"
step "Stripe CLI"
############################################################
if ! command -v stripe >/dev/null 2>&1; then
  curl -fsSL https://packages.stripe.dev/api/security/keypair/stripe-cli-gpg/public | \
    sudo gpg --dearmor --yes -o /usr/share/keyrings/stripe.gpg
  echo "deb [signed-by=/usr/share/keyrings/stripe.gpg] https://packages.stripe.dev/stripe-cli-debian-local stable main" | \
    sudo tee /etc/apt/sources.list.d/stripe.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y stripe
  ok "Stripe CLI installed"
else
  ok "Stripe CLI already installed"
fi

############################################################
sloth_progress 59 "Linking dotfiles"
step "Symlink dotfiles"
############################################################

# .zshrc
if [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
  mv "$HOME/.zshrc" "$HOME/.zshrc.backup"
  info "Backed up existing .zshrc to .zshrc.backup"
fi
ln -sf "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
ok "Linked .zshrc"

# .tmux.conf
if [[ -f "$HOME/.tmux.conf" && ! -L "$HOME/.tmux.conf" ]]; then
  mv "$HOME/.tmux.conf" "$HOME/.tmux.conf.backup"
fi
ln -sf "$SCRIPT_DIR/.tmux.conf" "$HOME/.tmux.conf"
ok "Linked .tmux.conf"

# setup-repos.sh
ln -sf "$SCRIPT_DIR/setup-repos.sh" "$HOME/setup-repos.sh"
ok "Linked setup-repos.sh"

# lpy-init.sh
ln -sf "$SCRIPT_DIR/lpy-init.sh" "$HOME/lpy-init.sh"
ok "Linked lpy-init.sh"

# motd.sh
ln -sf "$SCRIPT_DIR/motd.sh" "$HOME/motd.sh"
ok "Linked motd.sh"

# Claude settings
mkdir -p "$HOME/.claude/statusline"
ln -sf "$SCRIPT_DIR/claude/settings.json" "$HOME/.claude/settings.json"
ln -sf "$SCRIPT_DIR/claude/statusline/ctx_monitor.js" "$HOME/.claude/statusline/ctx_monitor.js"
ok "Linked Claude config"

############################################################
sloth_progress 61 "Configuring shell"
step "Disable Ubuntu default MOTD"
############################################################
# Disable PAM motd entirely (the source of all default MOTD output)
sudo sed -i '/pam_motd/s/^/#/' /etc/pam.d/sshd 2>/dev/null || true
# Disable PrintMotd in sshd (shows /etc/motd)
sudo sed -i 's/^#\?PrintMotd.*/PrintMotd no/' /etc/ssh/sshd_config 2>/dev/null || true
# Also disable PrintLastLog to keep login clean
sudo sed -i 's/^#\?PrintLastLog.*/PrintLastLog no/' /etc/ssh/sshd_config 2>/dev/null || true
# Clear any cached/static motd files
sudo truncate -s 0 /etc/legal 2>/dev/null || true
sudo truncate -s 0 /etc/motd 2>/dev/null || true
sudo truncate -s 0 /run/motd.dynamic 2>/dev/null || true
# Disable motd-news fetcher
sudo sed -i 's/^ENABLED=.*/ENABLED=0/' /etc/default/motd-news 2>/dev/null || true
# Our MOTD is shown from .zshrc instead
ok "Ubuntu default MOTD disabled"

############################################################
sloth_progress 63 "Configuring SSH"
step "SSH config for GitHub"
############################################################
SSH_CONFIG="$HOME/.ssh/config"
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"

# Pre-seed GitHub's SSH host keys so git clone never prompts
ssh-keyscan -t ed25519,rsa github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null || true
ok "GitHub host keys added to known_hosts"

if ! grep -q "Host org-109216428.github.com" "$SSH_CONFIG" 2>/dev/null; then
  cat >> "$SSH_CONFIG" <<'SSHEOF'

Host org-109216428.github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
SSHEOF
  chmod 600 "$SSH_CONFIG"
  ok "SSH config written for org-109216428.github.com"
else
  ok "SSH config already has org-109216428.github.com entry"
fi

############################################################
sloth_progress 65 "Setting default shell"
step "Set default shell to zsh"
############################################################
if [[ "$SHELL" != "$(which zsh)" ]]; then
  sudo chsh -s "$(which zsh)" "$USER"
  ok "Default shell set to zsh (takes effect on next login)"
else
  ok "zsh is already the default shell"
fi

# Mark install as complete (used by AMI to skip re-install)
touch "$HOME/.install-done"

printf "\n${BOLD}${GREEN}Done.${RESET} Open a new shell or run: ${BOLD}exec zsh${RESET}\n"
