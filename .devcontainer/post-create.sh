#!/bin/bash
set -e

echo "=== Installing Azure CLI ==="
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

echo "=== Installing Azure Developer CLI (azd) ==="
curl -fsSL https://aka.ms/install-azd.sh | bash

echo "=== Installing Bicep CLI ==="
az bicep install
sudo ln -sf /home/vscode/.azure/bin/bicep /usr/local/bin/bicep

echo "=== Verifying installations ==="
az --version
azd version
bicep --version

echo "=== All tools installed successfully ==="
