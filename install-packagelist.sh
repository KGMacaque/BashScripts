#!/bin/bash

# Define packages to be installed
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

# Install packages depending on the Linux distribution
if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y "${PACKAGES[@]}"
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf update
    sudo dnf install -y "${PACKAGES[@]}"
elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy "${PACKAGES[@]}"
elif command -v zypper >/dev/null 2>&1; then
    sudo zypper refresh
    sudo zypper install -y "${PACKAGES[@]}"
else
    echo "Error: Unsupported Linux distribution." >&2
    exit 1
fi

# Check which packages were installed successfully and which failed
SUCCESS=()
FAILED=()
for pkg in "${PACKAGES[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1 || rpm -q "$pkg" >/dev/null 2>&1; then
        SUCCESS+=("$pkg")
    else
        FAILED+=("$pkg")
    fi
done

# Print the results
echo "Packages installed successfully: ${SUCCESS[*]}"
echo "Packages failed to install: ${FAILED[*]}"
