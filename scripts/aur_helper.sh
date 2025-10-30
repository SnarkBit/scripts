#!/usr/bin/env bash
# ==========================================================
# Arch Linux AUR Helper Installer
# ----------------------------------------------------------
# Installs yay AUR helper safely using sudo when needed.
# ==========================================================

set -euo pipefail

# ----------------------------------------------------------
# Colors for output
# ----------------------------------------------------------
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

log() { echo -e "${YELLOW}[$(date +'%H:%M:%S')]${RESET} $*"; }
success() { echo -e "${GREEN}✔ $*${RESET}"; }
error_exit() { echo -e "${RED}✘ Error:${RESET} $*" >&2; exit 1; }

# ----------------------------------------------------------
# Internet check
# ----------------------------------------------------------
check_internet() {
    local host="archlinux.org"
    local retries=3
    local delay=2

    log "Checking internet connection to $host..."
    for ((i=1; i<=retries; i++)); do
        if ping -c 1 -W 2 "$host" &>/dev/null; then
            success "Internet connection OK (ping)."
            return 0
        fi
        if command -v curl &>/dev/null; then
            if curl -s --head "https://$host" | grep -q "200"; then
                success "Internet connection OK (HTTP)."
                return 0
            fi
        fi
        log "Attempt $i/$retries failed. Retrying in $delay seconds..."
        sleep $delay
    done
    error_exit "No internet connection."
}

check_internet

# ----------------------------------------------------------
# Install dependencies (asks for sudo password)
# ----------------------------------------------------------
log "Installing dependencies: base-devel, git, curl..."
sudo pacman -S --needed --noconfirm base-devel git curl || error_exit "Failed to install dependencies."

# ----------------------------------------------------------
# Build directory in /tmp
# ----------------------------------------------------------
BUILD_DIR="/tmp/yay-build"

cleanup() {
    log "Cleaning up build directory..."
    rm -rf "$BUILD_DIR"
}
# Ensure cleanup happens even if script exits with error
trap cleanup EXIT

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# ----------------------------------------------------------
# Clone, build, and install yay
# ----------------------------------------------------------
log "Cloning yay from AUR..."
git clone https://aur.archlinux.org/yay.git || error_exit "Failed to clone yay."
cd yay

log "Building and installing yay (this may ask for sudo password)..."
makepkg -si --noconfirm || error_exit "Failed to build/install yay."

success "yay has been installed successfully!"
