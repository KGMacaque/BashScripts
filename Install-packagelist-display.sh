#!/bin/bash

# Define package list
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

# Determine package manager and update package lists
if [ -x "$(command -v pacman)" ]; then
    sudo pacman -Sy
elif [ -x "$(command -v apt)" ]; then
    sudo apt update
elif [ -x "$(command -v zypper)" ]; then
    sudo zypper refresh
else
    echo "Error: No supported package manager found on the system."
    exit 1
fi

# Install packages
failed_packages=()
for package in "${PACKAGES[@]}"; do
    if ! sudo pacman -S --noconfirm "$package"; then
        if ! sudo yay -S --noconfirm "$package"; then
            failed_packages+=("$package")
        fi
    fi
done

# Display outcome using yad
if [ ${#failed_packages[@]} -eq 0 ]; then
    yad --title "Installation Success" --text "All packages were installed successfully." --button=OK:0
else
    failed_packages_list=$(printf "%s\n" "${failed_packages[@]}")
    yad --title "Installation Failed" --text "The following packages could not be installed:\n\n$failed_packages_list" --button=OK:0
fi
