#!/bin/bash

# Define packages to check and install
packages=("lynis")
arch_packages=()
deb_packages=()
installed=()
not_installed=()
failed=()

# Check if running on Arch or Debian
if [ -f "/etc/arch-release" ]; then
    # Arch Linux
    package_manager="pacman"
    package_suffix="-Sy"
    arch_packages=("${packages[@]}")
elif [ -f "/etc/debian_version" ]; then
    # Debian-based Linux
    package_manager="apt"
    package_suffix="install"
    deb_packages=("${packages[@]}")
else
    echo "Unsupported distribution"
    exit 1
fi

# Check and install packages
for package in "${packages[@]}"; do
    if command -v "$package" >/dev/null 2>&1; then
        installed+=("$package")
    else
        if [ "$package_manager" = "pacman" ]; then
            if sudo "$package_manager" "$package_suffix" "$package"; then
                installed+=("$package")
            else
                failed+=("$package")
            fi
        else
            if sudo "$package_manager" "$package_suffix" -y "$package"; then
                installed+=("$package")
            else
                # Try using pamac if apt fails
                if [ "$package_manager" = "apt" ]; then
                    if pamac install -y "$package"; then
                        installed+=("$package")
                    else
                        failed+=("$package")
                    fi
                else
                    failed+=("$package")
                fi
            fi
        fi
    fi
done

# Display results using dialog
if [ ${#installed[@]} -gt 0 ]; then
    message="The following packages were already installed:\n"
    for package in "${installed[@]}"; do
        message+="$package\n"
    done
    message+="\n"
fi

if [ ${#not_installed[@]} -gt 0 ]; then
    message+="The following packages were installed:\n"
    for package in "${not_installed[@]}"; do
        message+="$package\n"
    done
    message+="\n"
fi

if [ ${#failed[@]} -gt 0 ]; then
    message+="The following packages failed to install:\n"
    for package in "${failed[@]}"; do
        message+="$package\n"
    done
fi

if [ ${#installed[@]} -eq 0 ] && [ ${#not_installed[@]} -eq 0 ] && [ ${#failed[@]} -eq 0 ]; then
    message="No packages checked"
fi

dialog --title "Package Installation Results" --msgbox "$message" 12 50
