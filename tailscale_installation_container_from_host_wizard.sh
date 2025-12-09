#!/bin/bash

# --- Tailscale LXC Deployment Script ---
# Configures the host, installs Tailscale on the guest (Debian 12/Bookworm), 
# and runs the authentication command after a final reboot.

echo "Enter the ID of the LXC container to install Tailscale on (e.g., 216):"
read -r CTID

if [ -z "$CTID" ]; then
    echo "Container ID cannot be empty. Exiting."
    exit 1
fi

CONF_FILE="/etc/pve/lxc/${CTID}.conf"

echo "## 1. Checking and Configuring Container $CTID on Proxmox Host"
echo "---------------------------------------------------"

if [ ! -f "$CONF_FILE" ]; then
    echo "Error: Configuration file $CONF_FILE not found. Check the CTID."
    exit 1
fi

# Required lines for /dev/net/tun access in an unprivileged LXC (Proxmox 7+)
LXC_CGROUP="lxc.cgroup2.devices.allow: c 10:200 rwm"
LXC_MOUNT="lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file"

# Add config if missing
if grep -Fxq "$LXC_CGROUP" "$CONF_FILE" && grep -Fxq "$LXC_MOUNT" "$CONF_FILE"; then
    echo "Configuration lines already present. Skipping file edit."
else
    echo "Adding required TUN device entries to $CONF_FILE..."
    cat <<EOF >> "$CONF_FILE"

# Required for Tailscale in unprivileged containers
$LXC_CGROUP
$LXC_MOUNT
EOF
fi

echo "## 2. Installing Tailscale inside Container $CTID (Debian Bookworm)"
echo "---------------------------------------------------"

# Ensure curl is present for the installation commands
echo "Updating package lists and installing curl (if needed)..."
pct exec "$CTID" -- apt update || true
pct exec "$CTID" -- apt install -y curl -qq

# Manually execute the official Bookworm installation steps inside the container
echo "Setting up Tailscale APT repository for Debian Bookworm..."
pct exec "$CTID" -- bash -c "curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null"
pct exec "$CTID" -- bash -c "curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list >/dev/null"

echo "Installing tailscale package..."
pct exec "$CTID" -- apt update
pct exec "$CTID" -- apt install -y tailscale

echo "## 3. Rebooting Container to Activate TUN Device"
echo "---------------------------------------------------"
# This step mirrors the successful final fix you performed.
pct reboot "$CTID"

echo "Waiting 10 seconds for container to restart and services to initialize..."
sleep 10

echo "## 4. Starting Tailscale and Generating Auth Link"
echo "---------------------------------------------------"

# Running 'tailscale up' with the robust execution method
echo "Running '/usr/bin/tailscale up'. COPY THE URL BELOW to authenticate:"
pct exec "$CTID" -- sh -c '/usr/bin/tailscale up'

echo "---"
echo "Deployment Complete. Use the link above to authorize $CTID."
echo "---"

