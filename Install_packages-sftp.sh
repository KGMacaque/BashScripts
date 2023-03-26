#!/bin/bash

##     The script is designed to determine which package manager to use out of Debian open source or arch and then use that package manager the packages listed.
##     After the installation of packages, the script will then install and setup SSH & SFTP under the current user

# Determine the Linux distribution
if [ -f /etc/arch-release ]; then
    package_manager="pacman"
elif [ -f /etc/debian_version ]; then
    package_manager="apt-get"
elif [ -f /etc/SuSE-release ]; then
    package_manager="zypper"
else
    echo "Unsupported Linux distribution"
    exit 1
fi

# Define a function to install packages
install_packages() {
    local packages=("$@")  # Store the package names in an array
    local success=()       # Store the names of successfully installed packages
    local failed=()        # Store the names of failed installations

    # Loop through the package names and install them
    for package in "${packages[@]}"; do
        # Use the appropriate package manager to install the package
        sudo $package_manager install -y "$package" >/dev/null 2>&1

        # Check the exit status of the package manager
        if [ $? -eq 0 ]; then
            success+=("$package")  # Add the package name to the success list
        else
            failed+=("$package")   # Add the package name to the failed list
        fi
    done

    # Display the results of the package installation
    if [ ${#success[@]} -gt 0 ]; then
        echo "Successfully installed: ${success[*]}"
    fi
    if [ ${#failed[@]} -gt 0 ]; then
        echo "Failed to install: ${failed[*]}"
    fi

    # Display a message box with the installation results
    zenity --info --text "Package installation complete\n\n\
Successfully installed:\n${success[*]}\n\n\
Failed to install:\n${failed[*]}"
}

# Install SSH and SFTP services
sudo $package_manager install -y openssh-server openssh-sftp-server

# Add current user to the ssh and sftp groups
sudo usermod -aG ssh,sftp $(whoami)

# Enable SSH daemon
sudo systemctl enable ssh

# Install Tailscale
curl -fsSL https://pkgs.tailscale.com/stable/tailscale_1.14.0_amd64.tgz | sudo tar -C /usr/local/bin -xzf -

# Start Tailscale
sudo tailscale up

# Install Firefox web browser
install_packages firefox

# Install Yakuake terminal emulator
install_packages yakuake

# Install Fish shell
install_packages fish

# Install Ventoy bootable USB drive creator
install_packages ventoy

# Install tldr simplified man pages
install_packages tldr
