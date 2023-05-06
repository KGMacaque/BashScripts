#!/bin/bash

# List of programs to check and install
programs=("ENTER_YOUR_PACKAGES_HERE" "IN_QUOTES" "SEPARATED_BY_A_SPACE")

# Check if user is root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Function to check if program is installed and install if needed
function check_and_install {
  echo "Checking for $1..."
  if pacman -Qi $1 &>/dev/null; then
    echo "$1 is already installed"
  else
    if pacman -Sy $1 --noconfirm; then
      echo "$1 has been installed successfully"
    elif pamac install $1 --no-confirm; then
      echo "$1 has been installed successfully with pamac"
    else
      echo "Failed to install $1"
      exit 1
    fi
  fi
}

# Loop through programs and check/install them
for program in "${programs[@]}"; do
  check_and_install $program
done

# Display installation status using dialog
dialog --title "Program Installation Status" --msgbox "Installation complete. See terminal for details." 10 60
