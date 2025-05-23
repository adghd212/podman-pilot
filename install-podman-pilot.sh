#!/bin/bash

# Podman Pilot Installation Script

# Default installation directories
DEFAULT_INSTALL_BASE_DIR_SYSTEM="/opt/podman-pilot"
DEFAULT_SCRIPT_DIR_SYSTEM="${DEFAULT_INSTALL_BASE_DIR_SYSTEM}/scripts"
DEFAULT_BIN_DIR_SYSTEM="/usr/local/bin"

DEFAULT_INSTALL_BASE_DIR_USER="${HOME}/.local/share/podman-pilot"
DEFAULT_SCRIPT_DIR_USER="${DEFAULT_INSTALL_BASE_DIR_USER}/scripts"
DEFAULT_BIN_DIR_USER="${HOME}/.local/bin" # Ensure this is in user's PATH

EXECUTABLE_NAME="podman-pilot"
GITHUB_REPO_URL="https://github.com/adghd212/podman-pilot.git"
MIN_BASH_VERSION="4.0"

# --- Helper Functions ---
check_bash_version() {
    if [ -z "${BASH_VERSION}" ]; then
        echo "Error: This script must be run with Bash."
        exit 1
    fi
    # Strip suffix like -release
    local current_bash_version
    current_bash_version=$(echo "${BASH_VERSION}" | cut -d'.' -f1,2)
    if ! printf '%s\n' "$MIN_BASH_VERSION" "$current_bash_version" | sort -V -C; then
        echo "Error: Bash version ${MIN_BASH_VERSION} or higher is required. You have ${BASH_VERSION}."
        echo "Please upgrade Bash to run this script."
        exit 1
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to install packages if they don't exist
install_packages() {
    local missing_pkgs=()
    for pkg in "$@"; do
        if ! command_exists "$pkg" && ! dpkg -s "$pkg" &> /dev/null; then
             # For dialog, dpkg -s dialog might fail if dialog is a symlink to whiptail from a different package
            if [[ "$pkg" == "dialog" ]] && (command_exists "dialog" || command_exists "whiptail"); then
                continue
            fi
            missing_pkgs+=("$pkg")
        fi
    done

    if [ ${#missing_pkgs[@]} -gt 0 ]; then
        echo "The following required packages are missing: ${missing_pkgs[*]}"
        if [ "$EUID" -eq 0 ]; then
            read -p "Do you want to try installing them now? (y/N): " choice
            if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
                echo "Attempting to install missing packages..."
                apt update && apt install -y "${missing_pkgs[@]}"
                # Re-check after installation attempt
                for pkg in "${missing_pkgs[@]}"; do
                    if ! command_exists "$pkg" && ! dpkg -s "$pkg" &> /dev/null; then
                         if [[ "$pkg" == "dialog" ]] && (command_exists "dialog" || command_exists "whiptail"); then
                            continue
                        fi
                        echo "Error: Failed to install '$pkg'. Please install it manually and re-run the script."
                        exit 1
                    fi
                done
                echo "Packages installed successfully."
            else
                echo "Installation aborted. Please install the missing packages manually."
                exit 1
            fi
        else
            echo "Please run this script as root (sudo) to install missing packages, or install them manually: sudo apt install ${missing_pkgs[*]}"
            exit 1
        fi
    fi
}

# --- Main Installation Logic ---
check_bash_version
echo "Starting Podman Pilot installation..."

INSTALL_TYPE="system" # Default to system-wide installation
if [ "$1" == "user" ]; then
    INSTALL_TYPE="user"
    INSTALL_BASE_DIR="$DEFAULT_INSTALL_BASE_DIR_USER"
    SCRIPT_DIR="$DEFAULT_SCRIPT_DIR_USER"
    BIN_DIR="$DEFAULT_BIN_DIR_USER"
    echo "Performing user-specific installation to $INSTALL_BASE_DIR"
    if [ "$EUID" -eq 0 ]; then
        echo "Warning: Running user installation as root. This is generally not recommended."
        echo "         Files will be installed in root's home directory if paths are relative (e.g., ~/.local)."
        echo "         Consider running without sudo for user installation."
        read -p "Continue? (y/N): " choice
        if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
            echo "Installation aborted."
            exit 1
        fi
    fi
else
    INSTALL_BASE_DIR="$DEFAULT_INSTALL_BASE_DIR_SYSTEM"
    SCRIPT_DIR="$DEFAULT_SCRIPT_DIR_SYSTEM"
    BIN_DIR="$DEFAULT_BIN_DIR_SYSTEM"
    echo "Performing system-wide installation to $INSTALL_BASE_DIR"
    if [ "$EUID" -ne 0 ]; then
        echo "Error: System-wide installation requires root privileges. Please run with sudo."
        exit 1
    fi
fi

# 1. Check dependencies
echo "Checking dependencies: dialog, curl, git (recommended), jq..."
dependencies_to_check=("dialog" "curl" "git" "jq")
if [ "$EUID" -eq 0 ] || [ "$INSTALL_TYPE" == "user" ]; then # Allow user to install deps if they run sudo for user mode or are root
    install_packages "${dependencies_to_check[@]}"
else
    # If system install and not root, just warn and exit
    for pkg in "${dependencies_to_check[@]}"; do
        if ! command_exists "$pkg" && ! dpkg -s "$pkg" &> /dev/null; then
            echo "Error: Missing dependency '$pkg'. Please install it first or run installer with sudo."
            exit 1
        fi
    done
fi
echo "Dependency check passed."

# 2. Create installation directories
echo "Creating installation directory: $SCRIPT_DIR"
mkdir -p "$SCRIPT_DIR"
if [ "$INSTALL_TYPE" == "user" ]; then
    mkdir -p "$BIN_DIR" # Ensure $HOME/.local/bin exists for user install
fi
# For system install, /usr/local/bin should exist.

# 3. Download/Clone script files
SOURCE_DIR_NAME="podman-pilot-source" # Temp name for cloned/downloaded files

# Check if running from within a git clone of podman-pilot
if [ -d ".git" ] && [ -f "podman-pilot.sh" ]; then
    echo "Running from a local git clone. Copying files..."
    # Ensure we are in the script's directory for rsync source
    SCRIPT_SOURCE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    # Copy all files except .git and the installer itself
    rsync -av --progress --exclude=".git/" --exclude="$(basename "${BASH_SOURCE[0]}")" "${SCRIPT_SOURCE_PATH}/" "$SCRIPT_DIR/"
    if [ $? -ne 0 ]; then
        echo "Error copying files from local clone. Aborting."
        exit 1
    fi
elif command_exists git; then
    echo "Cloning Podman Pilot from GitHub repository to a temporary location..."
    TEMP_CLONE_DIR=$(mktemp -d)
    git clone --depth 1 "$GITHUB_REPO_URL" "$TEMP_CLONE_DIR"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to clone repository. Please check your internet connection and git setup."
        rm -rf "$TEMP_CLONE_DIR"
        exit 1
    fi
    echo "Copying files from cloned repository..."
    # Copy all files except .git
    rsync -av --progress --exclude=".git/" "${TEMP_CLONE_DIR}/" "$SCRIPT_DIR/"
    if [ $? -ne 0 ]; then
        echo "Error copying files from temporary clone. Aborting."
        rm -rf "$TEMP_CLONE_DIR"
        exit 1
    fi
    rm -rf "$TEMP_CLONE_DIR"
else
    echo "Error: Git is not installed, and not running from a local clone."
    echo "Please install git (sudo apt install git) and try again, or manually download the project files."
    exit 1
fi

if [ ! -f "${SCRIPT_DIR}/podman-pilot.sh" ]; then
    echo "Error: Main script 'podman-pilot.sh' not found after download/copy."
    exit 1
fi

# 4. Set permissions
echo "Setting permissions..."
chmod +x "${SCRIPT_DIR}/podman-pilot.sh"
# If modules need to be executable (they are sourced, so usually not, but good practice)
find "${SCRIPT_DIR}/modules" -name "*.sh" -exec chmod +x {} \;

# 5. Create symbolic link
SYMLINK_PATH="${BIN_DIR}/${EXECUTABLE_NAME}"
echo "Creating symbolic link: $SYMLINK_PATH -> ${SCRIPT_DIR}/podman-pilot.sh"
# Use -f to overwrite if it exists (e.g., during re-installation)
ln -sf "${SCRIPT_DIR}/podman-pilot.sh" "$SYMLINK_PATH"
if [ $? -ne 0 ]; then
    echo "Error: Failed to create symbolic link. You might need to run with sudo or check permissions for $BIN_DIR."
    # Attempt to create BIN_DIR if it doesn't exist and this is a user install without sudo
    if [ "$INSTALL_TYPE" == "user" ] && [ ! -d "$BIN_DIR" ]; then
        mkdir -p "$BIN_DIR"
        ln -sf "${SCRIPT_DIR}/podman-pilot.sh" "$SYMLINK_PATH"
        if [ $? -ne 0 ]; then
            echo "Still failed to create symlink after creating $BIN_DIR. Please check permissions."
            exit 1
        fi
    elif [ "$EUID" -ne 0 ]; then
        echo "Try running: sudo ln -sf \"${SCRIPT_DIR}/podman-pilot.sh\" \"$SYMLINK_PATH\""
        exit 1
    fi
fi


echo ""
echo "Podman Pilot has been successfully installed!"
echo "You can now run it by typing: $EXECUTABLE_NAME"
echo ""
if [ "$INSTALL_TYPE" == "user" ]; then
    if [[ ":$PATH:" != *":${BIN_DIR}:"* ]]; then
        echo "Note: The directory '$BIN_DIR' is not in your PATH."
        echo "Please add it to your PATH by adding the following line to your ~/.bashrc or ~/.zshrc:"
        echo "  export PATH=\"${BIN_DIR}:\$PATH\""
        echo "Then, run 'source ~/.bashrc' (or your shell's equivalent) or open a new terminal."
    fi
fi
echo "Enjoy using Podman Pilot!"

exit 0
