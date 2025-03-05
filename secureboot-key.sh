#!/bin/bash

# Set the path to the new key files
KEY_DIR="/root/new_keys"
KEY_NAME="my_key"
PRIVATE_KEY="$KEY_DIR/$KEY_NAME.key"
PUBLIC_KEY="$KEY_DIR/$KEY_NAME.crt"

# Generate a new key pair
openssl req -new -x509 -newkey rsa:2048 -keyout "$PRIVATE_KEY" -out "$PUBLIC_KEY" -subj "/CN=$KEY_NAME"

# Convert the public key to a format that can be imported into the UEFI firmware
cert-to-efi-sig-list "$PUBLIC_KEY" "$PUBLIC_KEY.esl" "$(uuidgen)"

# Use the mokutil utility to enroll the new key in the firmware
mokutil --import "$PUBLIC_KEY.esl"

# Set the key to be the default for Secure Boot
mokutil --set-default "$PUBLIC_KEY.esl"

# Reboot the system to activate the new key
reboot
