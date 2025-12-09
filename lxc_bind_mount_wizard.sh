#!/bin/bash
# LXC Bind Mount Wizard: Sets up a shared bind mount for an unprivileged
# container with correct permissions using a dedicated host group, setgid,
# and Access Control Lists (ACLs) for cross-container read/write execute access.

# --- Configuration Constants ---
HOST_GROUP="bind-storage"
LXC_GROUP="shared-data"
LXC_GID=999 # Standard GID to use inside the container for the shared group
# Note: For unprivileged containers (Proxmox default), the GID 999 maps to 100999 on the host.
MAPPED_LXC_GID=$((100000 + LXC_GID))
MAPPED_LXC_ROOT_UID=100000 # The UID the container's root (0) maps to on the host
CURRENT_USER=$(whoami)

echo "--- Proxmox Shared Storage Mount Setup Wizard ---"
echo "-------------------------------------------------"

# Function to find the next available mpX: index (X=0, 1, 2, ...)
get_next_mp_index() {
    local conf_file="$1"
    local max_index=-1 # Start with -1 so the first index is 0
    local current_max # SC2155 fix: Declare and assign separately
    
    # Search for all lines starting with 'mp' followed by digits and a colon
    if [ -f "$conf_file" ]; then
        # Use grep to find, sed to extract the number, sort to get max, head -n 1
        current_max=$(grep -E '^mp[0-9]+:' "$conf_file" 2>/dev/null | sed -E 's/^mp([0-9]+):.*/\1/' | sort -rn | head -n 1)
        if [ -n "$current_max" ]; then
            max_index="$current_max"
        fi
    fi
    # The next index is one higher than the current maximum found.
    echo $((max_index + 1))
}

# --- NEW FUNCTION: Resolve user input (name or UID) and ensure existence ---
# This is mainly used for host users, where we need the username for 'usermod'.
resolve_user_to_name() {
    local user_input="$1"
    local username

    # 1. Check if the input is a number (UID)
    if [[ "$user_input" =~ ^[0-9]+$ ]]; then
        # It's a UID, get the username
        username=$(getent passwd "$user_input" | cut -d: -f1)
    else
        # It's a potential username, check if it exists
        username=$(getent passwd "$user_input" | cut -d: -f1)
    fi

    # 2. Check if a username was successfully resolved
    if [ -n "$username" ]; then
        echo "$username"
    else
        # Return empty (no output) and fail (return 1) if user is not found
        return 1
    fi
}
# --------------------------------------------------------------------------


# 1. Essential Tool Checks
echo "Checking for required tools..."
# Ensure the 'acl' package is installed for 'setfacl' command
if ! command -v setfacl &> /dev/null; then
    echo "ERROR: 'acl' package not found. Please install it with 'apt install acl -y' and try again."
    exit 1
fi
echo "Tools check complete."
echo "-------------------------------------------------"


# --- PART A: Interactive Input and LXC Configuration ---

# 1. Ask for Container ID
read -r -p "Enter LXC Container ID (e.g., 100): " CT_ID
if ! pct status "$CT_ID" &> /dev/null; then # SC2086 applied
    echo "ERROR: Container ID $CT_ID does not exist or 'pct' command failed. Exiting."
    exit 1
fi

# 2. Ask for Host Mount Point
read -r -e -p "Enter the absolute shared directory path on the Proxmox host (e.g., /mnt/data/shared): " HOST_PATH
if [ -z "$HOST_PATH" ]; then
    echo "ERROR: Host path cannot be empty. Exiting."
    exit 1
fi

# 3. Check for ACL support now that we have the path
if ! mount | grep -q "$HOST_PATH.*acl" 2>/dev/null; then
    echo "WARNING: The filesystem for the host path might not explicitly show 'acl' in mount options. Proceeding, but permissions may fail."
fi


# 4. Ask for LXC Mount Point (with default)
DEFAULT_LXC_PATH="/mnt/pve-pools"
read -r -e -i "$DEFAULT_LXC_PATH" -p "Enter the mount point inside the LXC (Default: $DEFAULT_LXC_PATH): " LXC_PATH
LXC_PATH=${LXC_PATH:-$DEFAULT_LXC_PATH}

# 5. Ask for Host Users to add to the new shared group
# The prompt is updated to explicitly allow name or UID.
read -r -p "Enter comma-separated list of host users (name or UID) to add to '$HOST_GROUP' (Default: $CURRENT_USER): " HOST_USERS_INPUT
HOST_USERS_INPUT=${HOST_USERS_INPUT:-$CURRENT_USER}

# Convert comma-separated string to an array
IFS=',' read -r -a HOST_USERS_RAW_ARRAY <<< "$HOST_USERS_INPUT"
HOST_USERS_ARRAY=() # Array to store resolved usernames
HOST_USERS_LIST=""  # String list for the echo statement

echo "Resolving Host User Inputs..."
for USER_INPUT in "${HOST_USERS_RAW_ARRAY[@]}"; do
    USER_INPUT=$(echo "$USER_INPUT" | xargs) # Trim whitespace
    if [ -n "$USER_INPUT" ]; then
        RESOLVED_USER=$(resolve_user_to_name "$USER_INPUT")
        # FIX SC2181: Check if the command substitution returned a value, not the explicit exit code $?
        if [ -n "$RESOLVED_USER" ]; then 
            HOST_USERS_ARRAY+=("$RESOLVED_USER")
            HOST_USERS_LIST+="$RESOLVED_USER "
        else
            echo "  -> WARNING: Host user/UID '$USER_INPUT' not found on this system. Skipping."
        fi
    fi
done

# Check if any valid host users were found
if [ ${#HOST_USERS_ARRAY[@]} -eq 0 ]; then
    echo "ERROR: No valid host users were specified or resolved. Exiting to prevent group setup failure."
    exit 1
fi
echo "Host Users resolved: ${HOST_USERS_LIST}"
echo "-------------------------------------------------"


# 6. Ask for LXC Users to add to the new shared group inside the container
read -r -p "Enter comma-separated list of additional LXC users to add to '$LXC_GROUP' (e.g., gk_sftp, mediauser): " LXC_USERS_INPUT
# Convert comma-separated string to an array
IFS=',' read -r -a LXC_USERS_ARRAY <<< "$LXC_USERS_INPUT"

# 7. Create Host Mount Point if it does not exist
if [ ! -d "$HOST_PATH" ]; then
    echo "Host path '$HOST_PATH' not found. Creating it now."
    if ! mkdir -p "$HOST_PATH"; then # SC2181 applied: direct check on mkdir exit status
        echo "ERROR: Failed to create host directory '$HOST_PATH'. Check permissions. Exiting."
        exit 1
    fi
fi


# 8. Create LXC Mount Point inside the container
echo "Creating mount point '$LXC_PATH' inside container $CT_ID..."
# Use 'pct exec' to run commands inside the container
if pct exec "$CT_ID" -- mkdir -p "$LXC_PATH"; then # SC2086 applied
    echo "LXC mount point created/verified."
else
    echo "WARNING: Failed to create directory inside LXC. The container may be stopped, or 'pct exec' failed."
fi


# 9. Add the bind mount line to the LXC config file
CONF_FILE="/etc/pve/lxc/$CT_ID.conf"
MOUNT_PATH_SUFFIX="$HOST_PATH,mp=$LXC_PATH"

# Check if a mount line with this exact host/lxc path combo already exists
if grep -qF "$MOUNT_PATH_SUFFIX" "$CONF_FILE"; then
    echo "WARNING: A bind mount for Host Path '$HOST_PATH' and LXC Path '$LXC_PATH' already exists in $CONF_FILE."
    echo "Skipping configuration line addition."
else
    # If the specific host/lxc path combo does NOT exist, use the next available index
    NEXT_MP_INDEX=$(get_next_mp_index "$CONF_FILE")
    MP_KEY="mp${NEXT_MP_INDEX}"
    MOUNT_LINE="${MP_KEY}: $MOUNT_PATH_SUFFIX"

    echo "Adding mount line with new key '$MP_KEY' to $CONF_FILE: $MOUNT_LINE"
    
    # Check if the echo command succeeded
    if ! echo "$MOUNT_LINE" >> "$CONF_FILE"; then
        echo "ERROR: Failed to write to config file $CONF_FILE. Check permissions. Exiting."
        exit 1
    fi
    echo "Mount line successfully added. Reboot required later to activate mount and permissions."
fi # End of mount configuration block

echo "-------------------------------------------------"
# --- PART B: Permission Configuration (SetGID and ACLs) ---


# 1. Create and configure the dedicated Host Group
if ! getent group "$HOST_GROUP" &> /dev/null; then
    echo "Creating host group '$HOST_GROUP'..."
    groupadd "$HOST_GROUP"
fi

echo "Adding host users to the '$HOST_GROUP' group: ${HOST_USERS_LIST}"
for USER in "${HOST_USERS_ARRAY[@]}"; do
    # Since HOST_USERS_ARRAY only contains RESOLVED usernames, we just add them
    usermod -aG "$HOST_GROUP" "$USER"
    echo "  -> Host user '$USER' added."
done


# 2. Apply setgid and group ownership on the Host Mount Point
echo "Setting permissions on host path '$HOST_PATH'..."
# Set group ownership recursively
chgrp -R "$HOST_GROUP" "$HOST_PATH"
# Set setgid flag (g+s) so new files/dirs inherit the group
chmod g+s "$HOST_PATH"
# Ensure the group has full R/W/X access
chmod -R ug+rwx "$HOST_PATH"
echo "Host permissions (setgid) applied successfully."


# 3. Configure LXC Group and Permissions (REMOVED FAILING CHGRP/CHMOD)
echo -e "\nConfiguring group '$LXC_GROUP' (GID $LXC_GID) inside LXC $CT_ID..."
# Check if group exists inside LXC, if not, create it
if ! pct exec "$CT_ID" -- getent group "$LXC_GROUP" &> /dev/null; then
    pct exec "$CT_ID" -- groupadd -g $LXC_GID "$LXC_GROUP"
fi

# 3a. Define users to add: always include root, the default user (if found), and any user-provided users
LXC_USERS_TO_ADD_RAW=("root")

# Check for the default user (UID 1000)
LXC_DEFAULT_USER=$(pct exec "$CT_ID" -- grep -E 'x:1000:' /etc/passwd | cut -d: -f1)
if [ -n "$LXC_DEFAULT_USER" ]; then
    LXC_USERS_TO_ADD_RAW+=("$LXC_DEFAULT_USER")
fi

# Add user-provided LXC users to the array
LXC_USERS_TO_ADD_RAW+=("${LXC_USERS_ARRAY[@]}")

# Use printf/sort/uniq to get a unique list of users (to avoid trying to add the same user twice)
UNIQUE_LXC_USERS=$(printf "%s\n" "${LXC_USERS_TO_ADD_RAW[@]}" | sort -u)

# Iterate over the unique list and add them to the shared group
for LXC_USER in $UNIQUE_LXC_USERS; do
    LXC_USER=$(echo "$LXC_USER" | xargs) # Trim whitespace
    if [ -n "$LXC_USER" ]; then
        # IMPORTANT: We cannot resolve LXC users by UID here because the host 'getent' doesn't know about them.
        # We must rely on the LXC user input being a name, or the built-in LXC users (root, UID 1000).
        if pct exec "$CT_ID" -- id -u "$LXC_USER" &> /dev/null; then
            pct exec "$CT_ID" -- usermod -aG "$LXC_GID" "$LXC_USER"
            echo "  -> LXC user '$LXC_USER' added to $LXC_GROUP (GID 999)."
        else
            echo "  -> WARNING: LXC user '$LXC_USER' not found inside container $CT_ID. Skipping group modification."
        fi
    fi
done

echo "LXC internal permissions applied successfully (group assignments completed)."


# 4. Apply ACLs and Ownership on Host for Mapped LXC Root
echo -e "\nApplying ACLs and FORCING Ownership on host path '$HOST_PATH'..."

# CRITICAL FIX 1: Explicitly set ownership to the LXC Root's mapped UID/GID (100000:100000)
# This ensures the container's main user is the *owner* of the files, bypassing most traversal issues.
echo "  -> Forcing recursive ownership to LXC Root UID ($MAPPED_LXC_ROOT_UID) and LXC Root GID ($MAPPED_LXC_ROOT_UID)."
chown -R "$MAPPED_LXC_ROOT_UID":"$MAPPED_LXC_ROOT_UID" "$HOST_PATH"

# 1. Clear all existing ACLs (recursively) to remove old, restrictive masks
setfacl -R -b "$HOST_PATH"
echo "  -> Existing ACLs cleared."

# 2. Set the default and current ACL for the mapped LXC group (100999)
setfacl -R -m g:$MAPPED_LXC_GID:rwx "$HOST_PATH"
setfacl -R -d -m g:$MAPPED_LXC_GID:rwx "$HOST_PATH"
echo "  -> ACLs for GID $MAPPED_LXC_GID applied."

# 3. Explicitly set the mask to rwx recursively. This is the critical step to prevent traversal caps.
setfacl -R -m m:rwx "$HOST_PATH"
echo "  -> ACL Mask set to rwx."

# 4. Re-apply setgid and standard perms (group access is critical for host users)
chmod -R g+s "$HOST_PATH"
chmod -R u=rwx,g=rwx,o=rwx "$HOST_PATH"

echo "ACLs and ownership applied successfully."
echo "-------------------------------------------------"

# --- PART C: FINAL REBOOT AND VERIFICATION ---
echo -e "\n--- PART C: Final Reboot and Verification ---"
CT_STATUS=$(pct status "$CT_ID")
REBOOT_ACTION="Rebooting"
# Determine if we need to reboot or start, but we will run the command regardless
if [[ "$CT_STATUS" == "status: running" ]]; then
    echo "Finalizing setup: Rebooting container $CT_ID to activate the bind mount and apply new group memberships to running services."
    pct reboot "$CT_ID"
elif [[ "$CT_STATUS" == "status: stopped" ]]; then
    echo "Finalizing setup: Container $CT_ID is stopped. Starting container to activate the bind mount and apply new group memberships."
    pct start "$CT_ID"
    REBOOT_ACTION="Starting"
else
    echo "WARNING: Container $CT_ID status is unknown ($CT_STATUS). Skipping automatic restart."
    REBOOT_ACTION="Skipping Restart"
fi

if [[ "$REBOOT_ACTION" != "Skipping Restart" ]]; then
    echo "Waiting 10 seconds for container $CT_ID to fully $REBOOT_ACTION..."
    sleep 10
fi


echo -e "\n--- Setup Complete for LXC $CT_ID! ---"
echo "Host Directory: $HOST_PATH"
echo "LXC Directory: $LXC_PATH"
echo "Verification Commands (Actual Output Below):"

# 1. Host: Get ACLs
echo -e "\n--- Host Verification: Get ACLs for $HOST_PATH ---"
getfacl "$HOST_PATH" 2>&1 || echo "ERROR: Failed to run 'getfacl'. Check Host Path or ACL setup."

# 2. LXC: Check group ID
echo -e "\n--- LXC $CT_ID Verification: Check group $LXC_GROUP ID (should show GID 999) ---"
pct exec "$CT_ID" -- getent group "$LXC_GROUP" 2>&1 || echo "WARNING: Could not check LXC group. Container might be booting or down."

# 3. LXC: Check mount
echo -e "\n--- LXC $CT_ID Verification: Check mount permissions at $LXC_PATH ---"
echo "Mount Directory Permissions (ls -ld):"
pct exec "$CT_ID" -- ls -ld "$LXC_PATH" 2>&1 || echo "WARNING: Could not check LXC mount directory. Container might be booting or down."
echo "Mount Contents Listing (ls -l):"
pct exec "$CT_ID" -- ls -l "$LXC_PATH" 2>&1 || echo "WARNING: Could not list contents of LXC mount. Permissions or container issue."

date

exit 0
