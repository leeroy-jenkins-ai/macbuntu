# Macbuntu Maintenance Guide

**Author:** Manus AI  
**Version:** 1.0

---

## Overview

Macbuntu is designed to be maintained like a small software project. It has a clear structure, versioned assets, and a separation of concerns that makes updates predictable. This guide covers the complete lifecycle of maintaining the framework: updating individual software components, updating the Ubuntu base, managing the USB drive, and keeping a changelog.

The most important principle is: **never modify assets in place without testing**. Always update a component, test it on a VM or spare machine, and only then copy the updated `macbuntu/` directory to your production USB drives.

---

## Recommended Tooling

You do not need any special tools beyond what is available on any modern Mac or Linux machine.

| Tool | Purpose |
|---|---|
| `git` | Version-controlling the `macbuntu/` directory (strongly recommended) |
| `balenaEtcher` or `dd` | Writing the Ubuntu ISO to the USB drive |
| VirtualBox or UTM | Testing the installer in a VM before deploying to hardware |
| A text editor | Editing module scripts |
| `wget` or `curl` | Downloading updated asset files |

It is strongly recommended to keep the `macbuntu/` directory in a Git repository. This gives you a full history of every change, the ability to roll back to a previous version, and a clear record of which asset versions are in use. A private GitHub or GitLab repository works well for this.

---

## Versioning Strategy

Each release of the Macbuntu framework should be tagged in Git with a version number following the format `YYYY.MM.DD` (e.g., `2026.02.28`). This date-based versioning makes it immediately clear how old a given USB drive's installer is, which is useful when you have multiple drives in circulation.

The `README.md` at the root of the project should always reflect the current version and the versions of all bundled software assets. This serves as the single source of truth for what is on any given USB drive.

---

## Updating the Ubuntu Base ISO

The Ubuntu ISO on the USB drive is completely independent of the `macbuntu/` directory. To update to a new Ubuntu release or point release:

1. Download the new Ubuntu ISO from [ubuntu.com/download/desktop](https://ubuntu.com/download/desktop).
2. Write the new ISO to the USB drive using balenaEtcher or `dd`, which will erase the existing content.
3. After writing, mount the USB drive and copy the `macbuntu/` directory back onto it.

There is no need to modify any Macbuntu scripts when updating the Ubuntu ISO, unless the new Ubuntu version introduces a hardware compatibility change that requires a different driver approach.

---

## Updating Individual Software Components

### Updating Ollama

Ollama releases new versions frequently. To update:

1. Visit the [Ollama GitHub Releases page](https://github.com/ollama/ollama/releases) and identify the latest release tag (e.g., `v0.18.0`).
2. Download the new Linux amd64 tarball:
   ```bash
   wget https://github.com/ollama/ollama/releases/download/v0.18.0/ollama-linux-amd64.tar.zst \
     -O src/assets/bin/ollama-linux-amd64.tar.zst
   ```
3. Update the version number in `docs/01_architecture.md` and `README.md`.
4. Commit the change to Git with a message like `chore: update Ollama to v0.18.0`.
5. Test the updated module on a VM before deploying.

> **Note on file size:** The Ollama tarball is approximately 1.7 GB. On a USB drive with sufficient space this is not a problem, but be aware that updating it will take time to download and copy.

### Updating Tailscale

Tailscale publishes stable `.deb` packages at `pkgs.tailscale.com`. To update:

1. Visit [pkgs.tailscale.com/stable](https://pkgs.tailscale.com/stable/) and identify the latest version.
2. Download the new package:
   ```bash
   wget https://pkgs.tailscale.com/stable/tailscale_1.70.0_amd64.deb \
     -O src/assets/packages/tailscale_1.70.0_amd64.deb
   ```
3. Delete the old `.deb` file from `src/assets/packages/`.
4. Update the version number in `docs/01_architecture.md` and `README.md`.
5. Commit and test.

### Updating WiFi Firmware (`b43-fwcutter` / `firmware-b43-installer`)

These packages are updated infrequently and are tied to the Ubuntu release cycle. To check for updates:

1. Visit [packages.ubuntu.com/noble/b43-fwcutter](https://packages.ubuntu.com/noble/b43-fwcutter) and [packages.ubuntu.com/noble/firmware-b43-installer](https://packages.ubuntu.com/noble/firmware-b43-installer).
2. If new versions are available, download them from the Ubuntu security or updates repository.
3. Replace the old `.deb` files in `src/assets/packages/`.
4. The glob pattern `*.deb` in the installer script will automatically pick up the new filenames.

### Updating the SPI Driver (`applespi`)

The `applespi` driver is installed from source via DKMS, which means it rebuilds automatically on kernel updates. The source is downloaded as a zip from the GitHub repository. To update:

1. Check the [macbook12-spi-driver GitHub repository](https://github.com/roadrunner2/macbook12-spi-driver) for new commits on the `touchbar-driver-hid-driver` branch.
2. If there are significant changes, download the new zip:
   ```bash
   wget https://github.com/roadrunner2/macbook12-spi-driver/archive/refs/heads/touchbar-driver-hid-driver.zip \
     -O src/assets/drivers/macbook12-spi-driver-touchbar-driver-hid-driver.zip
   ```
3. Commit and test.

### Updating Open WebUI

Open WebUI is installed as a Docker container using the `main` tag, which always pulls the latest version at the time of installation. This means the Open WebUI module does not need to be updated for new Open WebUI releases — the `docker pull` command in the module script will always fetch the current latest image.

If you want to pin to a specific version for reproducibility, modify the image tag in `src/modules/02_open_webui.sh`:

```bash
# Change this:
docker pull ghcr.io/open-webui/open-webui:main
# To this (example):
docker pull ghcr.io/open-webui/open-webui:v0.6.0
```

---

## Adding a New Module

The module system is designed so that adding new software requires no changes to the core installer. The process is:

**Step 1: Create the module script**

Create a new file in `src/modules/` following the naming convention `NN_name.sh`. Choose a number that places it in a logical position relative to existing modules (e.g., `04_code_server.sh`). Use the following template:

```bash
#!/bin/bash
# Module: <Name>
# <One-line description of what this module installs>
# Version: <version of the software>
# Upstream: <URL where new versions can be found>

set -e

echo_green() { echo -e "\033[0;32m$1\033[0m"; }
echo_red()   { echo -e "\033[0;31m$1\033[0m"; }

echo_green "Installing <Name>..."

# Guard: skip if already installed
if command -v <binary> &> /dev/null; then
    echo_green "<Name> is already installed. Skipping."
    exit 0
fi

# --- Installation steps ---
# ...

echo_green "<Name> installation complete."
```

**Step 2: Stage any required assets**

Download any `.deb` packages, binaries, or configuration files the module needs and place them in the appropriate `src/assets/` subdirectory.

**Step 3: Document the module**

Add a row to the Software Stack Summary table in `docs/01_architecture.md` and document the upstream URL for future updates in this file.

**Step 4: Test**

See `docs/03_testing.md` for the full testing procedure.

---

## Maintaining the USB Drive Fleet

When you have multiple USB drives in circulation, it is important to have a clear process for keeping them synchronized.

The recommended approach is to maintain a single "master" copy of the `macbuntu/` directory in a Git repository. When you need to update a USB drive, you:

1. Pull the latest version from the Git repository onto your workstation.
2. Mount the USB drive.
3. Delete the old `macbuntu/` directory from the USB drive.
4. Copy the updated `macbuntu/` directory to the USB drive.
5. Eject the drive.

This process ensures that every USB drive is running the same version of the installer. You can verify this by checking the `README.md` on any drive, which should always reflect the current version tag.

---

## Changelog Template

Maintain a `CHANGELOG.md` at the root of the project. Use the following format:

```markdown
# Changelog

## [2026.02.28] - Initial Release
### Added
- Core installer with hardware remediation for MacBookPro13,3
- Module: Ollama v0.17.4
- Module: Open WebUI (latest)
- Module: Tailscale v1.60.1
- Pre-staged assets: b43-fwcutter, firmware-b43-installer, applespi driver

## [YYYY.MM.DD] - <Description>
### Added
- ...
### Changed
- ...
### Fixed
- ...
```
