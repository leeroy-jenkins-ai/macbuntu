#!/bin/bash
# =============================================================================
# Module: Tailscale
# Version: 1.60.1
# Purpose: Installs Tailscale from a pre-staged .deb and joins your tailnet.
# Upstream: https://pkgs.tailscale.com/stable/
# Asset:    assets/packages/tailscale_*.deb
# Notes:    You will need a Tailscale auth key. Generate one at:
#           https://login.tailscale.com/admin/settings/keys
#           Use a "Reusable" key to enroll multiple machines with one key.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="$SCRIPT_DIR/../assets"

echo_green() { echo -e "\033[0;32m$1\033[0m"; }
echo_red()   { echo -e "\033[0;31m$1\033[0m"; }

# --- Guard: skip installation if already installed ---
if command -v tailscale &> /dev/null; then
    echo_green "--> Tailscale already installed ($(tailscale --version | head -1)). Skipping package install."
else
    echo_green "--> Installing Tailscale from pre-staged package..."
    dpkg -i "$ASSETS_DIR/packages/tailscale_"*.deb
    systemctl enable tailscaled
    systemctl start tailscaled
fi

# --- Guard: skip auth if already connected ---
if tailscale status &> /dev/null 2>&1; then
    echo_green "--> Tailscale is already connected to a tailnet. Skipping auth."
    tailscale status
    exit 0
fi

# --- Authenticate ---
echo
echo_green "To connect this machine to your Tailscale network, you need an auth key."
echo "Generate a reusable key at: https://login.tailscale.com/admin/settings/keys"
echo
read -rp "Paste your Tailscale auth key (or press Enter to skip): " TAILSCALE_AUTH_KEY

if [[ -z "$TAILSCALE_AUTH_KEY" ]]; then
    echo_red "No auth key provided. Tailscale is installed but not connected."
    echo "Run 'sudo tailscale up' later to connect."
    exit 0
fi

tailscale up --authkey="$TAILSCALE_AUTH_KEY"

echo_green "Tailscale connected."
tailscale status
