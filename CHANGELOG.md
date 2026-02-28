# Changelog

All notable changes to the Macbuntu project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/). Versions use date-based tags in the format `YYYY.MM.DD`.

---

## [2026.02.28] — Initial Release

### Added

- Core installer (`src/install.sh`) with automatic hardware remediation for MacBookPro13,3, including SPI keyboard/trackpad driver (applespi via DKMS) and Broadcom BCM43602 WiFi firmware.
- Systemd service (`set-wifi-power.service`) to stabilize WiFi transmit power on every boot.
- Module `01_ollama.sh`: Installs Ollama v0.17.4 as a systemd service from a pre-staged tarball.
- Module `02_open_webui.sh`: Installs Docker and runs Open WebUI (latest) as a persistent Docker container on port 3000.
- Module `03_tailscale.sh`: Installs Tailscale v1.60.1 from a pre-staged `.deb` and connects to your tailnet using an auth key.
- Pre-staged assets: `b43-fwcutter` 1:019-11build1, `firmware-b43-installer` 1:019-11ubuntu0.1, `tailscale` 1.60.1, `ollama-linux-amd64.tar.zst` v0.17.4, `applespi` driver zip.
- Documentation: Architecture Guide, Maintenance Guide, Testing Guide.
