# Macbuntu Architecture Guide

**Author:** Manus AI  
**Version:** 1.0  
**Target Hardware:** MacBook Pro 15-inch, 2016 (MacBookPro13,3)  
**Target OS:** Ubuntu 24.04 LTS (Noble Numbat)

---

## Overview

Macbuntu is a self-contained, modular post-installation framework that lives on a bootable Ubuntu USB drive. Its purpose is to transform a freshly installed Ubuntu system on a MacBook Pro 2016 into a fully configured, standardized AI lab node — with all hardware quirks resolved and all desired software installed — in a single, guided session.

The design philosophy is that of a **distribution overlay**: rather than building a custom Ubuntu ISO (which is complex to maintain), Macbuntu uses the official Ubuntu 24.04 LTS ISO as its foundation and adds a `macbuntu/` directory to the USB drive. After the OS installs and the machine reboots, the operator mounts the USB drive and runs a single entry-point script. From that point, the system is fully automated.

This approach has several advantages. The Ubuntu ISO itself is maintained by Canonical and can be replaced with a newer version at any time without touching the Macbuntu scripts. The Macbuntu layer is independently versioned and can be updated, tested, and distributed separately.

---

## Directory Structure

The entire Macbuntu framework lives in a single directory that is copied to the root of the USB drive alongside the Ubuntu ISO files.

```
macbuntu/
├── README.md                        # Quick-start overview
├── docs/
│   ├── 01_architecture.md           # This document
│   ├── 02_maintenance.md            # How to update and extend
│   └── 03_testing.md                # How to validate the installer
└── src/
    ├── install.sh                   # Core entry-point script
    ├── modules/                     # Optional software modules
    │   ├── 01_ollama.sh             # Ollama local LLM runtime
    │   ├── 02_open_webui.sh         # Open WebUI browser interface
    │   └── 03_tailscale.sh          # Tailscale mesh VPN
    └── assets/                      # Pre-staged offline assets
        ├── drivers/
        │   └── macbook12-spi-driver-touchbar-driver-hid-driver.zip
        ├── packages/
        │   ├── b43-fwcutter_019-11build1_amd64.deb
        │   ├── firmware-b43-installer_019-11ubuntu0.1_all.deb
        │   └── tailscale_1.60.1_amd64.deb
        ├── bin/
        │   └── ollama-linux-amd64.tar.zst
        └── config/
            └── set-wifi-power.service
```

The separation between `src/modules/` (scripts) and `src/assets/` (binary files) is deliberate and important. Scripts are small, human-readable, and easy to update in a text editor. Assets are large binary blobs that need to be downloaded from the internet and replaced when new versions are released. Keeping them separate makes the maintenance workflow clear and predictable.

---

## Component Roles

The following table summarizes the role of each major component in the framework.

| Component | Type | Role |
|---|---|---|
| `src/install.sh` | Shell script | Entry point; runs hardware fixes, then presents the module menu |
| `src/modules/01_ollama.sh` | Shell script | Installs Ollama as a systemd service from the pre-staged tarball |
| `src/modules/02_open_webui.sh` | Shell script | Installs Docker and runs Open WebUI as a persistent container |
| `src/modules/03_tailscale.sh` | Shell script | Installs Tailscale from the pre-staged `.deb` and connects to your tailnet |
| `src/assets/drivers/` | Binary | SPI keyboard/trackpad driver source code (compiled on-device via DKMS) |
| `src/assets/packages/` | Binary | Pre-downloaded `.deb` packages for offline installation |
| `src/assets/bin/` | Binary | Pre-downloaded application binaries (Ollama) |
| `src/assets/config/` | Config | systemd unit files and other configuration snippets |

---

## Execution Flow

When the operator runs `sudo bash src/install.sh` from the mounted USB drive, the following sequence occurs:

**Phase 1 — Hardware Remediation (automatic, no user input)**

The MacBook Pro 2016 has three hardware components that do not work out of the box with the Ubuntu kernel: the SPI-based keyboard and trackpad, the Broadcom BCM43602 WiFi chip, and a WiFi transmit power instability issue. The core installer addresses all three automatically before presenting any menus.

The SPI keyboard/trackpad driver (`applespi`) is compiled from source using DKMS, which means it will automatically rebuild itself whenever the kernel is updated — a critical property for long-term maintainability. The Broadcom WiFi firmware is installed from the pre-staged `.deb` packages, and a systemd service is installed to set the WiFi transmit power to a stable value on every boot.

**Phase 2 — Module Selection (interactive)**

After hardware remediation, the installer scans the `src/modules/` directory, reads the filenames, and presents a numbered menu to the operator. The operator can select any combination of modules by number, or type `all` to install everything. This is the key interaction point of the entire process.

**Phase 3 — Module Execution (automatic, per-module prompts)**

Each selected module runs in sequence. Modules that require user input (such as the Tailscale auth key) will prompt at the appropriate moment. All other installation steps are fully automated. Modules are designed to be idempotent — running a module twice will not break the system.

**Phase 4 — Completion**

The installer prints a summary and recommends a reboot. After the reboot, the machine is fully configured and ready to use.

---

## Hardware Compatibility Notes

The MacBook Pro 15-inch 2016 (MacBookPro13,3) has the following Linux compatibility profile, which informed the design of the hardware remediation phase.

| Hardware Component | Linux Driver | Status | Notes |
|---|---|---|---|
| CPU (Intel Core i7 Skylake) | `intel_pstate` | Native | Works out of the box |
| Intel HD Graphics 530 | `i915` | Native | Works out of the box; no proprietary driver needed |
| NVMe SSD | `nvme` | Native | Works out of the box |
| USB-C / Thunderbolt 3 | `thunderbolt` | Native | Works out of the box |
| Keyboard / Trackpad (SPI) | `applespi` (DKMS) | Requires install | Pre-staged in `assets/drivers/` |
| WiFi (Broadcom BCM43602) | `b43` + firmware | Requires install | Pre-staged in `assets/packages/` |
| Audio (Cirrus Logic CS8409) | `snd_hda_intel` | Partial | Headphone jack may need ALSA config; speakers generally work |
| Bluetooth | `btusb` | Native | Works out of the box |
| Camera (FaceTime HD) | `uvcvideo` | Native | Works out of the box |
| Touch Bar (if present) | `applespi` (DKMS) | Requires install | Same driver as keyboard; shows as function keys |

---

## Module Design Contract

Every file in `src/modules/` must follow this contract to be compatible with the core installer:

1. **Filename convention:** `NN_name.sh` where `NN` is a zero-padded two-digit number that controls execution order (e.g., `01_ollama.sh`). The name portion becomes the display label in the menu.
2. **Executable:** The script must be executable (`chmod +x`).
3. **Self-contained:** The script must not depend on variables or functions defined in other module scripts. It may source `../install.sh` for shared helper functions if needed.
4. **Relative paths:** All references to assets must use paths relative to the `src/` directory (e.g., `../assets/packages/tailscale_*.deb`), since modules are executed from within the `src/` directory.
5. **Idempotent:** Running the script a second time must not cause errors or data loss. Use `if ! command -v foo; then ...` guards before installing software.
6. **Exit on error:** The script should begin with `set -e` so that any failed command halts the module immediately rather than silently continuing.

---

## Adding a New Module

To add a new software module — for example, a module that installs `code-server` (VS Code in the browser) — the process is:

1. Create `src/modules/04_code_server.sh` following the module design contract above.
2. Download any required offline assets (`.deb` files, binaries, etc.) and place them in the appropriate `src/assets/` subdirectory.
3. Document the new module's purpose, version, and upstream download URL in `docs/02_maintenance.md`.
4. Test the module in isolation on a clean Ubuntu VM before testing the full installer.

The core installer requires no modification — it auto-discovers all `*.sh` files in the `src/modules/` directory at runtime.

---

## Software Stack Summary

| Software | Version Included | Role | Installed As |
|---|---|---|---|
| Ubuntu | 24.04 LTS | Base operating system | Bootable ISO |
| applespi | Latest (DKMS) | SPI keyboard/trackpad driver | DKMS module |
| b43-fwcutter | 1:019-11build1 | Broadcom firmware extraction tool | `.deb` package |
| firmware-b43-installer | 1:019-11ubuntu0.1 | Broadcom WiFi firmware | `.deb` package |
| Tailscale | 1.60.1 | Mesh VPN | `.deb` package |
| Ollama | 0.17.4 | Local LLM runtime | Binary tarball + systemd service |
| Open WebUI | Latest (main) | Browser UI for Ollama | Docker container |
| Docker | Latest (apt) | Container runtime for Open WebUI | `apt` package |
