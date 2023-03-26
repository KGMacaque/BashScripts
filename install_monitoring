#!/bin/bash

##  This script installs packages listed below,
#    after determining which package manager
#    to use between = Arch, Debian, OpenSUSE. 

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

# Determine the package manager
if [ -x "$(command -v pacman)" ]; then
    # Arch Linux
    PKG_MANAGER="pacman -Sy --noconfirm"
elif [ -x "$(command -v apt-get)" ]; then
    # Debian/Ubuntu
    PKG_MANAGER="apt-get update && apt-get install -y"
elif [ -x "$(command -v zypper)" ]; then
    # openSUSE
    PKG_MANAGER="zypper --non-interactive install"
else
    echo "Unsupported distribution"
    exit 1
fi

# Install the packages
SUCCESS=()
FAILED=()
for package in "${PACKAGES[@]}"; do
    echo "Installing $package..."
    if $PKG_MANAGER "$package"; then
        SUCCESS+=("$package")
    else
        FAILED+=("$package")
    fi
done

# Display the results
MESSAGE="Installed packages:\n"
MESSAGE+="-------------------\n"
for package in "${SUCCESS[@]}"; do
    MESSAGE+="$package\n"
done
if [ ${#FAILED[@]} -ne 0 ]; then
    MESSAGE+="\nFailed packages:\n"
    MESSAGE+="----------------\n"
    for package in "${FAILED[@]}"; do
        MESSAGE+="$package\n"
    done
fi

# Display the message box
zenity --info --text="$MESSAGE" --title="Installation Monitoring"
