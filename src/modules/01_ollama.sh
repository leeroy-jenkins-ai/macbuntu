#!/bin/bash
# =============================================================================
# Module: Ollama
# Version: 0.17.4
# Purpose: Installs Ollama as a systemd service from a pre-staged tarball.
# Upstream: https://github.com/ollama/ollama/releases
# Asset:    assets/bin/ollama-linux-amd64.tar.zst
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="$SCRIPT_DIR/../assets"

echo_green() { echo -e "\033[0;32m$1\033[0m"; }

# --- Guard: skip if already installed ---
if command -v ollama &> /dev/null; then
    echo_green "Ollama is already installed ($(ollama --version)). Skipping."
    exit 0
fi

echo_green "--> Extracting Ollama from pre-staged tarball..."
tar --use-compress-program=unzstd -xf "$ASSETS_DIR/bin/ollama-linux-amd64.tar.zst" -C /usr/local
chmod +x /usr/local/bin/ollama

# --- Create a dedicated system user for Ollama ---
if ! id -u ollama &> /dev/null; then
    useradd -r -s /bin/false -m -d /usr/share/ollama ollama
fi

# --- Install the systemd service ---
cat <<'EOF' > /etc/systemd/system/ollama.service
[Unit]
Description=Ollama Local LLM Service
Documentation=https://ollama.com
After=network-online.target

[Service]
ExecStart=/usr/local/bin/ollama serve
User=ollama
Group=ollama
Restart=always
RestartSec=3
Environment="HOME=/usr/share/ollama"
Environment="OLLAMA_HOST=0.0.0.0"

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ollama.service
systemctl start ollama.service

echo_green "Ollama installed and running."
echo_green "  API endpoint:  http://localhost:11434"
echo_green "  Pull a model:  ollama pull llama3.2"
echo_green "  List models:   ollama list"
