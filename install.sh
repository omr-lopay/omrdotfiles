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

if [[ "$(uname)" != "Linux" ]]; then
  warn "This script is intended for Ubuntu/Debian. Exiting."
  exit 1
fi

ARCH="$(dpkg --print-architecture)"  # amd64 or arm64
DOTFILES_REPO="https://github.com/omr-lopay/omrdotfiles.git"
DOTFILES_DIR="$HOME/omrdotfiles"

############################################################
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
step "pnpm"
############################################################
if ! command -v pnpm >/dev/null 2>&1; then
  curl -fsSL https://get.pnpm.io/install.sh | sh -
  ok "pnpm installed"
else
  ok "pnpm already installed"
fi

############################################################
step "pgcli"
############################################################
if ! command -v pgcli >/dev/null 2>&1; then
  pipx install pgcli
  ok "pgcli installed"
else
  ok "pgcli already installed"
fi

############################################################
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
step "Google Cloud SDK"
############################################################
if ! command -v gcloud >/dev/null 2>&1; then
  if [[ ! -d "$HOME/google-cloud-sdk" ]]; then
    curl -fsSL https://sdk.cloud.google.com | bash -s -- --disable-prompts --install-dir="$HOME"
    ok "Google Cloud SDK installed"
  else
    ok "Google Cloud SDK directory exists"
  fi
else
  ok "gcloud already installed: $(gcloud --version 2>&1 | head -1)"
fi

############################################################
step "ngrok"
############################################################
if ! command -v ngrok >/dev/null 2>&1; then
  curl -fsSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
    | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
  echo "deb https://ngrok-agent.s3.amazonaws.com buster main" \
    | sudo tee /etc/apt/sources.list.d/ngrok.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y ngrok
  ok "ngrok installed"
else
  ok "ngrok already installed"
fi

############################################################
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
step "localtunnel"
############################################################
if ! command -v lt >/dev/null 2>&1; then
  npm install -g localtunnel
  ok "localtunnel installed"
else
  ok "localtunnel already installed"
fi

############################################################
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

# Claude settings
mkdir -p "$HOME/.claude/statusline"
ln -sf "$SCRIPT_DIR/claude/settings.json" "$HOME/.claude/settings.json"
ln -sf "$SCRIPT_DIR/claude/statusline/ctx_monitor.js" "$HOME/.claude/statusline/ctx_monitor.js"
ok "Linked Claude config"

############################################################
step "MOTD"
############################################################
sudo chmod -x /etc/update-motd.d/* 2>/dev/null || true
sudo cp "$SCRIPT_DIR/motd.sh" /etc/update-motd.d/99-lopay
sudo chmod +x /etc/update-motd.d/99-lopay
ok "MOTD installed"

############################################################
step "SSH config for GitHub org"
############################################################
SSH_CONFIG="$HOME/.ssh/config"
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
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
step "Set default shell to zsh"
############################################################
if [[ "$SHELL" != "$(which zsh)" ]]; then
  sudo chsh -s "$(which zsh)" "$USER"
  ok "Default shell set to zsh (takes effect on next login)"
else
  ok "zsh is already the default shell"
fi

printf "\n${BOLD}${GREEN}Done.${RESET} Open a new shell or run: ${BOLD}exec zsh${RESET}\n"
