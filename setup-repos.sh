#!/bin/bash
set -euo pipefail

mkdir -p ~/code
cd ~/code

echo "Cloning repositories..."
git clone git@org-109216428.github.com:lopay-limited/lopay-api.git

echo "Done! Your repos are ready in ~/code"
