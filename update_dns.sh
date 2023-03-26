#!/bin/bash

# Set the new DNS server addresses
DNSv4="45.90.28.41"
DNSv6="2a07:a8c0::2c:3656"

# Set the network profile to use
PROFILE="wired.network" # Change this to the name of your network profile

# Backup the original network profile
sudo cp /etc/systemd/network/${PROFILE} /etc/systemd/network/${PROFILE}.bak

# Modify the network profile with the new DNS settings
sudo sed -i "/\[Network\]/a DNS=${DNSv4}\nDNS=${DNSv6}" /etc/systemd/network/${PROFILE}

# Reload the systemd network configuration
sudo systemctl daemon-reload
sudo systemctl restart systemd-networkd.service
