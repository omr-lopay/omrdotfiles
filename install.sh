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
  gpg

# bat — binary is 'batcat' on Ubuntu, symlink to 'bat'
sudo apt-get install -y bat || true
if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
  sudo ln -sf "$(command -v batcat)" /usr/local/bin/bat
  ok "Symlinked batcat -> bat"
fi

ok "apt packages installed"

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
  # Fetch latest nvm release tag
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
step "AWS Session Manager Plugin"
############################################################
if ! command -v session-manager-plugin >/dev/null 2>&1; then
  if [[ "$ARCH" == "arm64" ]]; then
    SSM_URL="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_arm64/session-manager-plugin.deb"
  else
    SSM_URL="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb"
  fi
  cd /tmp
  curl -fsSL "$SSM_URL" -o session-manager-plugin.deb
  sudo dpkg -i session-manager-plugin.deb
  rm -f session-manager-plugin.deb
  ok "Session Manager Plugin installed"
else
  ok "Session Manager Plugin already installed"
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
step "Symlink dotfiles"
############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# .zshrc
if [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
  mv "$HOME/.zshrc" "$HOME/.zshrc.backup"
  info "Backed up existing .zshrc to .zshrc.backup"
fi
ln -sf "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
ok "Linked .zshrc"

# Claude settings
mkdir -p "$HOME/.claude/statusline"
ln -sf "$SCRIPT_DIR/claude/settings.json" "$HOME/.claude/settings.json"
ln -sf "$SCRIPT_DIR/claude/statusline/ctx_monitor.js" "$HOME/.claude/statusline/ctx_monitor.js"
ok "Linked Claude config"

############################################################
step "Set default shell to zsh"
############################################################
if [[ "$SHELL" != "$(which zsh)" ]]; then
  chsh -s "$(which zsh)"
  ok "Default shell set to zsh (takes effect on next login)"
else
  ok "zsh is already the default shell"
fi

printf "\n${BOLD}${GREEN}Done.${RESET} Open a new shell or run: ${BOLD}exec zsh${RESET}\n"
