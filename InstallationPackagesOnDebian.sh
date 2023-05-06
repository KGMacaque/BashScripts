#!/bin/bash

# List of packages to install
PACKAGES=("ENTER_YOUR_PACKAGES_HERE" "IN_QUOTES" "SEPARATED_BY_A_SPACE")

# Initialize dialog
dialog --clear --title "Package Installer" --infobox "Checking package installation..." 3 50

# Loop through packages and check if they're installed
for PACKAGE in "${PACKAGES[@]}"; do
    if ! dpkg -s "$PACKAGE" &> /dev/null; then
        # If the package is not installed, install it using apt-get
        dialog --clear --title "Package Installer" --infobox "$PACKAGE is not installed. Installing now..." 3 50
        sudo apt-get update && sudo apt-get install -y "$PACKAGE" || \
            # If installation fails, try installing using pamac
            (sudo apt-get install -y pamac && sudo pamac install -y "$PACKAGE" || \
            # If installation still fails, show error message
            dialog --clear --title "Package Installer" --msgbox "$PACKAGE installation failed." 3 50)
    else
        # If the package is already installed, show message
        dialog --clear --title "Package Installer" --infobox "$PACKAGE is already installed." 3 50
    fi
done

# All packages have been checked and installed (if necessary), show completion message
dialog --clear --title "Package Installer" --msgbox "Package installation complete." 3 50
