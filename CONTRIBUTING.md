# Contributing to Macbuntu

First off, thank you for considering contributing! This project thrives on community effort, and every contribution — from a typo fix to a new hardware profile — is appreciated.

## How Can I Contribute?

### Reporting Bugs

If you find a bug, please open an issue and use the "Bug Report" template. The more detail you can provide, the better:
- Which MacBook model and year are you using?
- Which version of Ubuntu are you running?
- What are the steps to reproduce the bug?
- What did you expect to happen, and what actually happened?

### Suggesting Enhancements

If you have an idea for a new module or a way to improve the installer, open an issue using the "Feature Request" template. This is the best way to start a discussion about a new idea.

### Submitting Pull Requests

If you want to contribute code, please follow this process:

1. **Fork the repository** and create a new branch from `main`.
2. **Make your changes.** Please adhere to the existing code style.
3. **Test your changes.** See the [Testing Guide](./docs/03_testing.md) for the full process. At a minimum, run `shellcheck` on any scripts you modify.
4. **Update the documentation.** If you add a new module or change a significant behavior, please update the relevant documentation in the `docs/` directory.
5. **Submit a pull request** with a clear description of your changes.

## Module Design Contract

To be accepted, a new module must follow the design contract outlined in the [Architecture Guide](./docs/01_architecture.md#module-design-contract).

Key requirements:
- **Filename:** `NN_name.sh` (e.g., `04_code_server.sh`)
- **Idempotent:** The script must be safe to run multiple times.
- **Self-contained:** The script should not depend on other modules.
- **Relative paths:** Use relative paths to access files in the `assets/` directory.

## Hardware Profiles

If you want to add support for a new MacBook model, please create a new directory under `hardware/` (e.g., `hardware/macbookpro-2019/`) and add a `fixes.sh` script that contains the necessary hardware remediation steps for that model. The core `install.sh` script will be updated to detect the model and source the correct script.
