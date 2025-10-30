#!/usr/bin/env bash
# ==========================================================
# Arch Linux Package Installer
# ----------------------------------------------------------
# Installs base packages and optional packages from one or
# more .txt files.
# Usage: ./pkg_install.sh [file1.txt file2.txt ...]
# ==========================================================

set -euo pipefail

# ----------------------------------------------------------
# Colors for output
# ----------------------------------------------------------
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

# ----------------------------------------------------------
# Logging helpers
# ----------------------------------------------------------
log() { echo -e "${YELLOW}[$(date +'%H:%M:%S')]${RESET} $*"; }
success() { echo -e "${GREEN}✔ $*${RESET}"; }
error_exit() { echo -e "${RED}✘ Error:${RESET} $*" >&2; exit 1; }

# ----------------------------------------------------------
# Internet check
# ----------------------------------------------------------
check_internet() {
    log "Checking internet connection..."
    if ping -c 1 -W 2 archlinux.org &>/dev/null; then
        success "Internet connection OK (ping)."
    elif command -v curl &>/dev/null && curl -s --head "https://archlinux.org" | grep -q "200"; then
        success "Internet connection OK (HTTP)."
    else
        error_exit "No internet connection. Please check your network."
    fi
}
check_internet

# ----------------------------------------------------------
# Base packages
# ----------------------------------------------------------
base_packages=(git firefox vim curl)

# ----------------------------------------------------------
# Update database
# ----------------------------------------------------------
log "Updating package database..."
sudo pacman -Sy --noconfirm || error_exit "Failed to update package database."

# ----------------------------------------------------------
# Install base packages
# ----------------------------------------------------------
log "Installing base packages..."
to_install=()
for pkg in "${base_packages[@]}"; do
    if pacman -Qi "$pkg" &>/dev/null; then
        success "$pkg already installed."
    else
        to_install+=("$pkg")
    fi
done

if [[ ${#to_install[@]} -gt 0 ]]; then
    log "Installing missing base packages: ${to_install[*]}"
    sudo pacman -S --needed --noconfirm "${to_install[@]}" || error_exit "Failed to install base packages."
    success "Base packages installed."
fi

# ----------------------------------------------------------
# Optional packages from multiple .txt files
# ----------------------------------------------------------
if [[ $# -ge 1 ]]; then
    all_packages=()
    for pkg_file in "$@"; do
        [[ ! -f "$pkg_file" ]] && error_exit "File not found: $pkg_file"
        log "Reading packages from $pkg_file..."
        mapfile -t file_packages < <(grep -Ev '^\s*#|^\s*$' "$pkg_file")
        all_packages+=("${file_packages[@]}")
    done

    # Remove duplicates
    mapfile -t all_packages < <(printf "%s\n" "${all_packages[@]}" | sort -u)

    # Determine which packages are missing
    to_install=()
    for pkg in "${all_packages[@]}"; do
        if pacman -Qi "$pkg" &>/dev/null; then
            success "$pkg already installed."
        else
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        log "Installing missing packages from files: ${to_install[*]}"
        sudo pacman -S --needed --noconfirm "${to_install[@]}" || error_exit "Failed to install packages from files."
        success "All packages from files installed."
    else
        log "All packages from files are already installed."
    fi
else
    log "No optional package files provided. Skipping."
fi

# ----------------------------------------------------------
# Final message
# ----------------------------------------------------------
success "All requested packages installed and up-to-date!"
