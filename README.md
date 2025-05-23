# Podman Pilot 🚀

Podman Pilot is a shell-based TUI (Text User Interface) management script for Podman on Debian-based systems. It aims to simplify common Podman operations like installation, managing registries, pods, images, containers, and deploying predefined applications with a single click.

The script is designed to be modular and extensible, with support for internationalization (i18n).

**Project GitHub:** [https://github.com/adghd212/podman-pilot](https://github.com/adghd212/podman-pilot)

## ✨ Features

* **Podman Management:**
    * Install Podman using `apt`.
    * Uninstall Podman.
    * Check Podman status.
* **Image Registry Configuration:**
    * View current registries (`~/.config/containers/registries.conf`).
    * Set default search registries.
    * Add/Remove registries with pre-defined options (e.g., `docker.io`, `quay.io`) or custom input.
* **Pod Management:**
    * List, Create, Delete, Inspect, Start, Stop Pods.
* **Image Management:**
    * List, Pull, Remove, Search Images.
    * Prune unused images.
* **Container Management:**
    * List (all/running), Create, Delete, Start, Stop, Restart Containers.
    * View container logs, inspect containers, execute commands within containers.
    * Prune stopped containers.
* **One-Click Application Deployments:**
    * Easily deploy common applications like Nginx, PHP-FPM, Apache, Alist, WordPress.
    * Extensible: Add your own applications via simple configuration files.
* **Self-Update:**
    * Update the script to the latest version directly from GitHub.
* **Internationalization (i18n):**
    * Currently supports English and 简体中文 (Chinese Simplified).
    * Easy to add more languages.
* **User-Friendly TUI:**
    * Powered by `dialog` for an accessible command-line interface.

## 📋 Requirements

* A Debian-based Linux system (e.g., Debian, Ubuntu).
* `bash` (typically pre-installed).
* `podman`
* `dialog` (TUI utility): Install with `sudo apt install dialog`.
* `curl` (for downloading/updating): Install with `sudo apt install curl`.
* `git` (optional, for cloning/updating): Install with `sudo apt install git`.

## 🚀 Installation

1.  **Clone the repository (Recommended):**
    ```bash
    git clone [https://github.com/adghd212/podman-pilot.git](https://github.com/adghd212/podman-pilot.git)
    cd podman-pilot
    ```
    Or download the `install-podman-pilot.sh` script directly:
    ```bash
    curl -sSL https://raw..githubusercontent.com/adghd212/podman-pilot/main/install-podman-pilot.sh](https://raw.githubusercontent.com/adghd212/podman-pilot/main/install-podman-pilot.sh) -o install-podman-pilot.sh
    chmod +x install-podman-pilot.sh
    ```

2.  **Run the installer script:**
    ```bash
    sudo ./install-podman-pilot.sh
    ```
    This will:
    * Check and offer to install dependencies like `dialog` and `curl`.
    * Copy the script files to a designated directory (e.g., `/opt/podman-pilot` or `~/.local/share/podman-pilot`).
    * Create a symbolic link for easy execution (e.g., `/usr/local/bin/podman-pilot`).

## 🛠️ Usage

Once installed, you can run Podman Pilot by simply typing:

```bash
podman-pilot
