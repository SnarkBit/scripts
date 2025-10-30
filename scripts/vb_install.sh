#!/usr/bin/env bash
# ==========================================================
# VirtualBox Installer for Arch Linux (with Extension Pack)
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
# Detect current user (for sudo commands)
# ----------------------------------------------------------
USER_NAME=${SUDO_USER:-$USER}

# ----------------------------------------------------------
# Check internet connection
# ----------------------------------------------------------
check_internet() {
    local host="archlinux.org"
    log "Checking internet connection..."
    if ping -c 1 -W 2 "$host" &>/dev/null; then
        success "Internet connection OK (ping)."
    elif command -v curl &>/dev/null && curl -s --head "https://$host" | grep -q "200"; then
        success "Internet connection OK (HTTP)."
    else
        error_exit "No internet connection. Please check your network."
    fi
}
check_internet

# ----------------------------------------------------------
# Ask user if they want to install VirtualBox
# ----------------------------------------------------------
read -rp "Do you want to install VirtualBox? [y/N]: " install_vb
install_vb=${install_vb:-N}
[[ ! "$install_vb" =~ ^[Yy]$ ]] && { log "Skipping VirtualBox installation."; exit 0; }

# ----------------------------------------------------------
# Check CPU virtualization support
# ----------------------------------------------------------
log "Checking CPU virtualization support..."
if ! egrep -q 'vmx|svm' /proc/cpuinfo; then
    error_exit "CPU virtualization not supported or disabled in BIOS/UEFI."
fi
success "CPU supports virtualization."

# ----------------------------------------------------------
# Update system packages
# ----------------------------------------------------------
log "Updating system packages..."
sudo pacman -Syu --noconfirm || error_exit "Failed to update system."

# ----------------------------------------------------------
# Detect kernel and headers
# ----------------------------------------------------------
KERNEL_NAME=$(uname -r)
KERNEL_HEADERS="linux-headers"

if [[ $KERNEL_NAME == *lts* ]]; then
    KERNEL_HEADERS="linux-lts-headers"
elif [[ $KERNEL_NAME == *zen* ]]; then
    KERNEL_HEADERS="linux-zen-headers"
fi

log "Installing prerequisites: base-devel, dkms, $KERNEL_HEADERS..."
sudo pacman -S --needed --noconfirm base-devel dkms "$KERNEL_HEADERS" || error_exit "Failed to install prerequisites."

# ----------------------------------------------------------
# Install VirtualBox
# ----------------------------------------------------------
if [[ $KERNEL_NAME == *lts* ]]; then
    log "Installing VirtualBox for LTS kernel..."
    sudo pacman -S --needed --noconfirm virtualbox virtualbox-host-dkms || error_exit "Failed to install VirtualBox."
else
    log "Installing VirtualBox for default/Zen kernel..."
    sudo pacman -S --needed --noconfirm virtualbox virtualbox-host-modules-arch || error_exit "Failed to install VirtualBox."
fi
success "VirtualBox installed."

# ----------------------------------------------------------
# Load kernel modules
# ----------------------------------------------------------
log "Loading VirtualBox kernel modules..."
for module in vboxdrv vboxnetadp vboxnetflt vboxpci; do
    sudo modprobe "$module" || true
done

sudo tee /etc/modules-load.d/virtualbox.conf >/dev/null <<EOF
vboxdrv
vboxnetadp
vboxnetflt
vboxpci
EOF
success "Kernel modules loaded and configured for boot."

# ----------------------------------------------------------
# Add user to vboxusers group
# ----------------------------------------------------------
log "Adding user '$USER_NAME' to vboxusers group..."
sudo usermod -aG vboxusers "$USER_NAME"
success "User added to vboxusers group."

# ----------------------------------------------------------
# Install VirtualBox Extension Pack via yay
# ----------------------------------------------------------
if command -v yay &>/dev/null; then
    read -rp "Do you want to install the VirtualBox Extension Pack? [y/N]: " install_ext
    install_ext=${install_ext:-N}
    if [[ "$install_ext" =~ ^[Yy]$ ]]; then
        log "Installing VirtualBox Extension Pack via yay..."
        sudo -u "$USER_NAME" yay -S --noconfirm virtualbox-ext-oracle || error_exit "Failed to install Extension Pack."
        success "VirtualBox Extension Pack installed."
    else
        log "Skipping VirtualBox Extension Pack installation."
    fi
else
    log "yay not found. Skipping Extension Pack installation."
fi

# ----------------------------------------------------------
# Final message
# ----------------------------------------------------------
success "VirtualBox installation completed!"
echo -e "${YELLOW}Log out and back in for group changes to take effect.${RESET}"
