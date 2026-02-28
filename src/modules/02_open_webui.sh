#!/bin/bash
# =============================================================================
# Module: Open WebUI
# Version: latest (main tag)
# Purpose: Installs Docker and runs Open WebUI as a persistent container.
# Upstream: https://github.com/open-webui/open-webui
# Notes:    Requires internet access to pull the Docker image.
#           Access the UI at http://localhost:3000 after installation.
# =============================================================================

set -e

echo_green() { echo -e "\033[0;32m$1\033[0m"; }

# --- Install Docker if not present ---
if ! command -v docker &> /dev/null; then
    echo_green "--> Docker not found. Installing from apt..."
    apt-get update -qq
    apt-get install -y docker.io
    systemctl enable docker
    systemctl start docker
else
    echo_green "--> Docker already installed ($(docker --version | head -1)). Skipping."
fi

# --- Guard: skip if container already exists ---
if docker ps -a --format '{{.Names}}' | grep -q "^open-webui$"; then
    echo_green "--> Open WebUI container already exists. Skipping creation."
    # Ensure it is running
    docker start open-webui 2>/dev/null || true
    exit 0
fi

echo_green "--> Pulling Open WebUI Docker image..."
docker pull ghcr.io/open-webui/open-webui:main

echo_green "--> Starting Open WebUI container..."
docker run -d \
    --name open-webui \
    --restart always \
    -p 3000:8080 \
    -v open-webui:/app/backend/data \
    -e OLLAMA_BASE_URL=http://host-gateway:11434 \
    --add-host=host-gateway:host-gateway \
    ghcr.io/open-webui/open-webui:main

echo_green "Open WebUI is running."
echo_green "  Access at:  http://localhost:3000"
echo_green "  The first account you create will be the administrator."
