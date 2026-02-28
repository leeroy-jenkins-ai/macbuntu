# Macbuntu

**Version:** 2026.02.28  
**Target Hardware:** MacBook Pro 15-inch, 2016 (MacBookPro13,3 — Intel Core i7, 16 GB RAM, Intel HD 530)  
**Base OS:** Ubuntu 24.04 LTS (Noble Numbat)

---

## What Is This?

Macbuntu is a modular post-installation framework that lives on a bootable Ubuntu USB drive. It turns a fleet of MacBook Pro 2016 laptops into standardized, fully configured Ubuntu AI lab machines in a single guided session.

After you install Ubuntu from the USB drive, you run one script. That script fixes all MacBook-specific hardware issues automatically, then presents a menu of optional software modules you can install. When it finishes, you have a machine that is identical to every other machine you have set up with the same drive.

This is designed to be maintained and extended over time — like a small internal Linux distribution. The documentation explains not just how to use it, but how it works, how to update it, and how to test it.

---

## Bundled Software

### Core (installed automatically on every machine)

| Software | Version | Purpose |
|---|---|---|
| Ubuntu | 24.04 LTS | Base operating system |
| applespi driver | Latest | SPI keyboard and trackpad support |
| b43-fwcutter | 1:019-11build1 | Broadcom WiFi firmware extraction |
| firmware-b43-installer | 1:019-11ubuntu0.1 | Broadcom BCM43602 WiFi firmware |

### Optional Modules (choose at install time)

| Module | Software | Version | Purpose |
|---|---|---|---|
| `01_ollama` | Ollama | 0.17.4 | Local LLM runtime (runs AI models on-device) |
| `02_open_webui` | Open WebUI | Latest | Browser-based chat UI for Ollama |
| `03_tailscale` | Tailscale | 1.60.1 | Mesh VPN to connect all machines securely |

---

## Quick Start

### Step 1: Create the Bootable USB Drive

Download Ubuntu 24.04 LTS from [ubuntu.com/download/desktop](https://ubuntu.com/download/desktop) and write it to a USB drive (16 GB minimum, 32 GB recommended to fit all assets).

On macOS, use [balenaEtcher](https://etcher.balena.io/) — it is the simplest option.

After writing the ISO, mount the USB drive and copy the entire `macbuntu/` directory to the root of the drive. The drive should now contain both the Ubuntu boot files and the `macbuntu/` folder.

### Step 2: Install Ubuntu on the MacBook

1. Insert the USB drive into the MacBook Pro.
2. Hold **Option (⌥)** while pressing the power button.
3. Select the **EFI Boot** drive (yellow icon) from the boot picker.
4. Follow the Ubuntu installer. Choose **"Erase disk and install Ubuntu"** for a clean setup.
5. When the installer finishes, reboot. Remove the USB drive when prompted, then plug it back in after the machine boots into Ubuntu.

> **WiFi will not work yet** after the first boot. Use a USB-C to Ethernet adapter for internet access during the post-install phase, or rely entirely on the pre-staged offline assets on the USB drive.

### Step 3: Run the Post-Install Script

Open a terminal and run:

```bash
# Find the USB drive mount point (usually /media/$USER/Ubuntu 24.04 LTS)
ls /media/$USER/

# Navigate to the Macbuntu source directory
cd /media/$USER/Ubuntu\ 24.04\ LTS/macbuntu/src/

# Run the installer as root
sudo bash install.sh
```

The installer will:
1. Automatically fix the keyboard, trackpad, and WiFi.
2. Present a menu of optional software modules.
3. Install your selected modules.

### Step 4: Reboot

After the installer completes, reboot the machine. WiFi will now work. All installed services (Ollama, Open WebUI) will start automatically on every boot.

---

## Documentation

| Document | Description |
|---|---|
| [Architecture Guide](./docs/01_architecture.md) | How the framework is structured and how the components interact |
| [Maintenance Guide](./docs/02_maintenance.md) | How to update software, add new modules, and manage the USB fleet |
| [Testing Guide](./docs/03_testing.md) | How to validate the installer using a layered testing strategy |

---

## Project Structure

```
macbuntu/
├── README.md                        # This file
├── CHANGELOG.md                     # Version history
├── TESTLOG.md                       # Record of test runs
├── docs/
│   ├── 01_architecture.md
│   ├── 02_maintenance.md
│   └── 03_testing.md
└── src/
    ├── install.sh                   # Core entry-point script
    ├── modules/
    │   ├── 01_ollama.sh
    │   ├── 02_open_webui.sh
    │   └── 03_tailscale.sh
    └── assets/
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

---

## Frequently Asked Questions

**Q: Do I need an internet connection to use this?**  
A: For the core hardware fixes and Tailscale, no — all required files are pre-staged on the USB drive. For Open WebUI, Docker must pull the image from the internet. Ollama itself is pre-staged, but AI models must be downloaded separately after installation using `ollama pull <model-name>`.

**Q: What if I want to install a model automatically?**  
A: Add an `ollama pull` command to the end of `src/modules/01_ollama.sh`. For example, `ollama pull llama3.2` will download the 3B Llama model. Be aware that models range from 2 GB to over 40 GB, so this requires a reliable internet connection and sufficient drive space.

**Q: Can I use this on other MacBook models?**  
A: The hardware remediation phase is specifically written for the MacBook Pro 2016 (MacBookPro13,3). Other Intel MacBook models may need different drivers or configurations. The software modules (Ollama, Open WebUI, Tailscale) are hardware-agnostic and will work on any Ubuntu machine.

**Q: How do I add a new machine to Tailscale automatically?**  
A: Generate a **reusable auth key** from the [Tailscale admin console](https://login.tailscale.com/admin/settings/keys). A reusable key can be used to enroll multiple machines. For fully unattended enrollment (no prompt), you can hard-code the key in `src/modules/03_tailscale.sh` — but be aware that anyone with access to the USB drive will be able to read the key.

**Q: Where do I pull AI models from?**  
A: After Ollama is installed and running, use `ollama pull <model>` to download models. The full list of available models is at [ollama.com/library](https://ollama.com/library). Good starting points for 16 GB RAM machines are `llama3.2` (3B), `mistral` (7B), and `phi4` (14B).
