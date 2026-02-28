# Macbuntu Testing Guide

**Author:** Manus AI  
**Version:** 1.0

---

## Overview

Consistent, repeatable testing is what separates a reliable installer from a fragile one. Because Macbuntu will be used to set up multiple machines over time, any undetected regression in the installer scripts can waste significant time. This guide describes a layered testing strategy that catches most issues before they reach physical hardware.

The testing pyramid for Macbuntu has three layers, each with a different cost and fidelity:

| Layer | Environment | Speed | Fidelity | When to Use |
|---|---|---|---|---|
| Script linting | Local workstation | Seconds | Low (syntax only) | Every time you edit a script |
| Module unit testing | Ubuntu VM | Minutes | Medium | After updating any module or asset |
| Full integration testing | Ubuntu VM | 30–60 min | High | Before updating production USB drives |
| Hardware acceptance testing | Physical MacBook | 60–90 min | Exact | Before a new major release |

---

## Layer 1: Script Linting

Before running any script on a real machine, run it through `shellcheck`, a static analysis tool for shell scripts. It catches common bugs like unquoted variables, incorrect conditionals, and portability issues.

**Installation:**
```bash
# On macOS
brew install shellcheck

# On Ubuntu/Debian
sudo apt-get install shellcheck
```

**Usage:**
```bash
# Lint all scripts in the project
shellcheck src/install.sh src/modules/*.sh
```

Make it a habit to run `shellcheck` every time you edit a script. A clean `shellcheck` output is a prerequisite for any further testing.

---

## Layer 2: Module Unit Testing in a VM

Each module should be tested in isolation on a clean Ubuntu 24.04 VM before being tested as part of the full installer. This is the fastest way to verify that a module works correctly after an update.

### Setting Up a Test VM

1. Download the [Ubuntu 24.04 LTS ISO](https://ubuntu.com/download/desktop).
2. Create a new VM in VirtualBox or UTM with the following specifications:
   - **RAM:** 4 GB minimum (8 GB recommended for Ollama)
   - **Disk:** 40 GB minimum (Ollama tarball alone is 1.7 GB)
   - **CPU:** 2 cores minimum
   - **Network:** NAT (for internet access during testing)
3. Install Ubuntu 24.04 in the VM using the default settings.
4. After installation, take a **snapshot** of the clean state. Label it `clean-ubuntu-24.04`. You will restore to this snapshot before each test run.

### Running a Module Unit Test

1. Restore the VM to the `clean-ubuntu-24.04` snapshot.
2. Copy the `macbuntu/src/` directory into the VM (e.g., via a shared folder or `scp`).
3. Open a terminal in the VM and navigate to the `src/` directory.
4. Run the specific module script directly:
   ```bash
   sudo bash modules/01_ollama.sh
   ```
5. Verify the expected outcome using the checklist for that module (see below).

### Module Verification Checklists

**Module 01: Ollama**

After running `01_ollama.sh`, verify the following:

```bash
# Check that the binary is installed
which ollama

# Check that the systemd service is running
systemctl status ollama.service

# Check that Ollama is responding on its API port
curl http://localhost:11434/api/version
```

Expected: `ollama` is found in `PATH`, the service shows `active (running)`, and the API returns a JSON response with a version number.

**Module 02: Open WebUI**

After running `02_open_webui.sh`, verify the following:

```bash
# Check that Docker is installed
docker --version

# Check that the Open WebUI container is running
docker ps | grep open-webui

# Check that the web interface is accessible
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000
```

Expected: Docker is installed, the container appears in `docker ps`, and the HTTP status code is `200`.

**Module 03: Tailscale**

After running `03_tailscale.sh` (using a valid auth key), verify the following:

```bash
# Check that Tailscale is installed
tailscale --version

# Check the connection status
tailscale status
```

Expected: Tailscale is installed, and `tailscale status` shows the machine connected to your tailnet with an assigned IP address.

---

## Layer 3: Full Integration Testing in a VM

Full integration testing runs the complete installer — hardware remediation phase plus all modules — from start to finish. Because the VM does not have the MacBook's specific hardware, the hardware remediation phase will fail on driver installation. The recommended approach is to use a **modified integration test script** that skips the hardware-specific steps.

### Creating an Integration Test Configuration

Add a flag to `install.sh` that skips hardware remediation for VM testing:

```bash
# At the top of install.sh, add:
SKIP_HARDWARE=false

# Parse arguments
while [[ "$1" == --* ]]; do
    case "$1" in
        --skip-hardware) SKIP_HARDWARE=true ;;
    esac
    shift
done

# In the main function:
if [ "$SKIP_HARDWARE" = false ]; then
    install_hardware_fixes
fi
```

Then run the full integration test in the VM:

```bash
sudo bash src/install.sh --skip-hardware
```

This will present the full module selection menu and execute all selected modules, giving you confidence that the module discovery, menu, and execution logic all work correctly.

### Integration Test Checklist

After a full integration test run, verify:

- [ ] The module menu displayed all expected modules with correct names.
- [ ] Selecting `all` ran every module without errors.
- [ ] Each module's verification checklist (from Layer 2) passes.
- [ ] No error messages were printed to the terminal.
- [ ] The system is stable after a reboot.

---

## Layer 4: Hardware Acceptance Testing

Hardware acceptance testing is performed on a physical MacBook Pro 2016 and is the final gate before updating production USB drives. This test validates the hardware remediation phase and confirms that the complete end-to-end experience works as expected.

### Hardware Acceptance Test Procedure

1. Begin with a MacBook Pro 2016 that has been wiped (or is available for reinstallation).
2. Boot from the Macbuntu USB drive, holding the **Option (⌥)** key at startup.
3. Select the **EFI Boot** option (yellow drive icon).
4. Install Ubuntu 24.04 using the standard installer. Choose "Erase disk and install Ubuntu".
5. After the first reboot into the new system, connect an Ethernet adapter (USB-C to Ethernet) since WiFi will not work yet.
6. Mount the USB drive and navigate to the `macbuntu/src/` directory.
7. Run the installer: `sudo bash install.sh`
8. Select all modules when prompted.
9. Provide your Tailscale auth key when prompted.
10. After the installer completes, reboot.

### Hardware Acceptance Checklist

After the reboot, verify the following:

| Component | Test | Expected Result |
|---|---|---|
| Keyboard | Type in a terminal | All keys register correctly |
| Trackpad | Move cursor and click | Cursor moves; click registers |
| WiFi | Open Network Settings | WiFi adapter appears; can connect to a network |
| Ollama | `systemctl status ollama` | Service is `active (running)` |
| Open WebUI | Open browser to `http://localhost:3000` | Login page appears |
| Tailscale | `tailscale status` | Machine appears in tailnet |
| Audio | Play a sound | Audio plays through speakers |
| Display | Observe screen | No flickering; brightness control works |

---

## Regression Testing After Updates

When you update a module or asset, you do not need to run the full hardware acceptance test every time. The following table provides guidance on the minimum test level required for each type of change.

| Type of Change | Minimum Test Level |
|---|---|
| Edit a module script | Layer 1 (lint) + Layer 2 (unit test for that module) |
| Update a `.deb` package | Layer 2 (unit test for that module) |
| Update the Ollama binary | Layer 2 (unit test for Ollama module) |
| Add a new module | Layer 1 + Layer 2 + Layer 3 (full integration) |
| Update `install.sh` | Layer 1 + Layer 3 (full integration) |
| Update Ubuntu ISO | Layer 4 (hardware acceptance) |
| Major version bump of any component | Layer 4 (hardware acceptance) |

---

## Keeping a Test Log

Maintain a simple test log in a `TESTLOG.md` file at the root of the project. Record each test run with the date, tester, environment, and result. This provides an audit trail and helps identify patterns in failures.

```markdown
# Test Log

## 2026-02-28 | Full Integration Test | VM (VirtualBox, Ubuntu 24.04) | PASS
- Tester: [your name]
- Modules tested: all
- Notes: All modules installed successfully. Ollama API responding. Open WebUI accessible at :3000.

## 2026-02-28 | Hardware Acceptance Test | MacBook Pro 15" 2016 | PASS
- Tester: [your name]
- Notes: WiFi connected after reboot. Keyboard and trackpad working. Tailscale connected.
```
