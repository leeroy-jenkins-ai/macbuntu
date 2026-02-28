#!/bin/bash
# =============================================================================
# Macbuntu Core Installer
# Version: 2026.02.28
# Target:  MacBook Pro 15-inch 2016 (MacBookPro13,3) running Ubuntu 24.04 LTS
#
# Usage:
#   sudo bash install.sh              # Full install (hardware + modules)
#   sudo bash install.sh --skip-hardware  # Skip hardware fixes (for VM testing)
# =============================================================================

set -e

# --- Paths (relative to this script's location) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"
ASSETS_DIR="$SCRIPT_DIR/assets"

# --- Flags ---
SKIP_HARDWARE=false

# --- Parse arguments ---
for arg in "$@"; do
    case "$arg" in
        --skip-hardware) SKIP_HARDWARE=true ;;
    esac
done

# =============================================================================
# Helper Functions
# =============================================================================

echo_green() { echo -e "\033[0;32m$1\033[0m"; }
echo_red()   { echo -e "\033[0;31m$1\033[0m"; }
echo_blue()  { echo -e "\033[0;34m$1\033[0m"; }
echo_bold()  { echo -e "\033[1m$1\033[0m"; }

# =============================================================================
# Phase 1: Hardware Remediation
# =============================================================================

install_hardware_fixes() {
    echo_blue "\n============================================================"
    echo_bold " Phase 1: Hardware Remediation"
    echo_blue "============================================================"
    echo "Applying hardware-specific fixes for MacBookPro13,3..."

    # Install build dependencies
    echo_green "--> Installing build dependencies..."
    apt-get update -qq
    apt-get install -y dkms git unzip zstd wireless-tools

    # --- Keyboard and Trackpad (applespi DKMS driver) ---
    echo_green "--> Installing SPI keyboard/trackpad driver (applespi)..."
    DRIVER_ZIP="$ASSETS_DIR/drivers/macbook12-spi-driver-touchbar-driver-hid-driver.zip"
    DRIVER_SRC="/usr/src/applespi-0.1"

    if [ -d "$DRIVER_SRC" ]; then
        echo "    applespi source already present at $DRIVER_SRC, skipping extraction."
    else
        unzip -q "$DRIVER_ZIP" -d /tmp/applespi_build
        mv /tmp/applespi_build/macbook12-spi-driver-touchbar-driver-hid-driver "$DRIVER_SRC"
    fi

    if dkms status applespi/0.1 | grep -q "installed"; then
        echo "    applespi DKMS module already installed, skipping."
    else
        dkms install applespi/0.1
    fi
    echo_green "    Keyboard/trackpad driver installed."

    # --- WiFi (Broadcom BCM43602) ---
    echo_green "--> Installing Broadcom BCM43602 WiFi firmware..."
    if dpkg -s b43-fwcutter &> /dev/null; then
        echo "    b43-fwcutter already installed, skipping."
    else
        dpkg -i "$ASSETS_DIR/packages/b43-fwcutter_"*.deb
    fi

    if dpkg -s firmware-b43-installer &> /dev/null; then
        echo "    firmware-b43-installer already installed, skipping."
    else
        dpkg -i "$ASSETS_DIR/packages/firmware-b43-installer_"*.deb
    fi

    # --- WiFi Power Stability Fix ---
    echo_green "--> Installing WiFi power stability service..."
    if [ ! -f /etc/systemd/system/set-wifi-power.service ]; then
        cp "$ASSETS_DIR/config/set-wifi-power.service" /etc/systemd/system/
        systemctl daemon-reload
        systemctl enable set-wifi-power.service
    else
        echo "    WiFi power service already installed, skipping."
    fi
    echo_green "    WiFi firmware and stability fix installed."

    echo_green "\nHardware remediation complete."
}

# =============================================================================
# Phase 2: Module Selection and Execution
# =============================================================================

run_modules() {
    echo_blue "\n============================================================"
    echo_bold " Phase 2: Optional Software Modules"
    echo_blue "============================================================"

    # Discover all module scripts, sorted by filename
    mapfile -t module_files < <(find "$MODULES_DIR" -maxdepth 1 -name "*.sh" | sort)

    if [ ${#module_files[@]} -eq 0 ]; then
        echo_red "No modules found in $MODULES_DIR. Nothing to install."
        return
    fi

    echo "The following optional software modules are available:"
    echo
    for i in "${!module_files[@]}"; do
        # Extract a human-readable name from the filename (e.g., "01_ollama.sh" -> "ollama")
        module_label=$(basename "${module_files[$i]}" .sh | sed 's/^[0-9]*_//')
        printf "  %2d) %s\n" "$((i+1))" "$module_label"
    done
    echo
    echo "  Enter numbers separated by spaces (e.g., 1 3), or type 'all' to install everything."
    echo "  Press Enter with no input to skip all modules."
    echo
    read -rp "Your selection: " selection

    if [[ -z "$selection" ]]; then
        echo "No modules selected. Skipping."
        return
    fi

    if [[ "$selection" == "all" ]]; then
        selected_indices=($(seq 0 $((${#module_files[@]} - 1))))
    else
        selected_indices=()
        for num in $selection; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#module_files[@]}" ]; then
                selected_indices+=($((num - 1)))
            else
                echo_red "Invalid selection: '$num' — ignoring."
            fi
        done
    fi

    if [ ${#selected_indices[@]} -eq 0 ]; then
        echo "No valid modules selected. Skipping."
        return
    fi

    echo
    for index in "${selected_indices[@]}"; do
        module_file="${module_files[$index]}"
        module_label=$(basename "$module_file" .sh | sed 's/^[0-9]*_//')

        echo_blue "\n------------------------------------------------------------"
        echo_bold " Installing module: $module_label"
        echo_blue "------------------------------------------------------------"

        # Run the module from the src/ directory so relative asset paths work
        (cd "$SCRIPT_DIR" && bash "$module_file")

        echo_green " Module '$module_label' complete."
    done
}

# =============================================================================
# Main
# =============================================================================

main() {
    # Ensure the script is run as root
    if [ "$EUID" -ne 0 ]; then
        echo_red "This script must be run as root. Please use: sudo bash install.sh"
        exit 1
    fi

    echo_bold "\n============================================================"
    echo_bold " Macbuntu Installer — Version 2026.02.28"
    echo_bold " Target: MacBook Pro 15-inch 2016 / Ubuntu 24.04 LTS"
    echo_bold "============================================================"

    if [ "$SKIP_HARDWARE" = true ]; then
        echo_red "\n[--skip-hardware] Hardware remediation phase SKIPPED (VM/test mode)."
    else
        install_hardware_fixes
    fi

    run_modules

    echo_blue "\n============================================================"
    echo_bold " Macbuntu installation complete!"
    echo_blue "============================================================"
    echo "A reboot is recommended to ensure all drivers and services are active."
    echo
    read -rp "Reboot now? [y/N]: " reboot_choice
    if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
        reboot
    fi
}

main "$@"
