#!/bin/bash

# Define the packages to be installed
PACKAGES=(
    gotop
    nmon
    mytop
    bpytop
    bashtop
    atop
    iotop
    iotop-c
    smem
    memstat
    sar
    pmap
)

# Determine which package manager to use
if command -v pacman &> /dev/null; then
    PACKAGE_MANAGER="pacman -Sy"
elif command -v apt-get &> /dev/null; then
    PACKAGE_MANAGER="apt-get update"
elif command -v zypper &> /dev/null; then
    PACKAGE_MANAGER="zypper refresh"
else
    echo "Unsupported package manager"
    exit 1
fi

# Install the packages
for PACKAGE in "${PACKAGES[@]}"; do
    if ! $PACKAGE_MANAGER install -y "$PACKAGE"; then
        echo "Failed to install $PACKAGE"
        if command -v yay &> /dev/null; then
            if ! yay -S --noconfirm "$PACKAGE"; then
                echo "Failed to install $PACKAGE with yay"
            fi
        fi
    fi
done

# Display the outcome using kdialog
if [[ -n $DISPLAY ]] && command -v kdialog &> /dev/null; then
    if grep -q "Failed" <<< "$OUTCOME"; then
        kdialog --error "Installation failed for some packages."
    else
        kdialog --info "All packages installed successfully."
    fi
fi
