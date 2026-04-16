#!/bin/bash
# Raspberry Pi 4B - Access Point Setup using NetworkManager (persistent after reboot)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Raspberry Pi 4B - Access Point Setup (Persistent)${NC}"
echo -e "${GREEN}========================================${NC}"

# Default values
DEFAULT_HOSTNAME="ceejay"
DEFAULT_USERNAME="ceej"
DEFAULT_SSID="RPi_Network"
DEFAULT_PASSWORD="raspberry123"

echo -e "${YELLOW}This setup uses NetworkManager hotspot (survives reboots).${NC}"
echo ""

# Get user input
read -p "Enter hostname [$DEFAULT_HOSTNAME]: " HOSTNAME
HOSTNAME=${HOSTNAME:-$DEFAULT_HOSTNAME}

read -p "Enter username for SSH login [$DEFAULT_USERNAME]: " USERNAME
USERNAME=${USERNAME:-$DEFAULT_USERNAME}

read -p "Enter Wi-Fi SSID (network name) [$DEFAULT_SSID]: " SSID
SSID=${SSID:-$DEFAULT_SSID}

while true; do
    read -s -p "Enter Wi-Fi password (min 8 chars) [$DEFAULT_PASSWORD]: " PASSWORD
    echo ""
    PASSWORD=${PASSWORD:-$DEFAULT_PASSWORD}
    if [ ${#PASSWORD} -ge 8 ]; then
        break
    fi
    echo -e "${RED}Password must be at least 8 characters.${NC}"
done

# Confirm
echo -e "\n${YELLOW}Confirm settings:${NC}"
echo -e "  Hostname:  ${GREEN}$HOSTNAME${NC}"
echo -e "  Username:  ${GREEN}$USERNAME${NC}"
echo -e "  SSID:      ${GREEN}$SSID${NC}"
echo -e "  Password:  ${GREEN}${PASSWORD:0:4}***${NC}"
echo ""

read -p "Continue? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Cancelled${NC}"
    exit 1
fi

# Create user if needed
if ! id "$USERNAME" &>/dev/null; then
    echo -e "${YELLOW}Creating user $USERNAME...${NC}"
    sudo useradd -m -s /bin/bash "$USERNAME"
    echo -e "${YELLOW}Set password for $USERNAME:${NC}"
    sudo passwd "$USERNAME"
    sudo usermod -aG sudo "$USERNAME"
fi

# --- Remove old hostapd/dnsmasq (if any) to avoid conflicts ---
echo -e "\n${GREEN}[1/4] Removing legacy AP services...${NC}"
sudo systemctl stop hostapd dnsmasq 2>/dev/null || true
sudo systemctl disable hostapd dnsmasq 2>/dev/null || true
sudo systemctl mask hostapd dnsmasq 2>/dev/null || true
sudo apt remove -y hostapd dnsmasq 2>/dev/null || true

# --- Create NetworkManager hotspot (persistent) ---
echo -e "\n${GREEN}[2/4] Creating NetworkManager hotspot...${NC}"
# Delete any existing connection with the same SSID to avoid conflict
sudo nmcli connection delete "$SSID" 2>/dev/null || true

# Create the hotspot (autoconnect = yes ensures it starts on boot)
sudo nmcli connection add type wifi ifname wlan0 con-name "$SSID" autoconnect yes ssid "$SSID" mode ap ipv4.method shared wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$PASSWORD"

# Set high priority so it doesn't get overridden
sudo nmcli connection modify "$SSID" connection.autoconnect-priority 100

# --- Set hostname ---
echo -e "\n${GREEN}[3/4] Setting hostname...${NC}"
echo "$HOSTNAME" | sudo tee /etc/hostname > /dev/null
sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME/" /etc/hosts
sudo hostnamectl set-hostname "$HOSTNAME" 2>/dev/null || true

# --- Enable SSH ---
echo -e "\n${GREEN}[4/4] Enabling SSH...${NC}"
sudo systemctl enable ssh
sudo systemctl start ssh

# --- Start the hotspot ---
echo -e "\n${GREEN}Starting hotspot...${NC}"
sudo nmcli connection up "$SSID"

# --- Done ---
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Wi-Fi Network: ${GREEN}$SSID${NC}"
echo -e "Password:      ${GREEN}$PASSWORD${NC}"
echo -e "AP IP:         ${GREEN}10.42.0.1${NC} (default, managed by NetworkManager)"
echo ""
echo -e "${BLUE}SSH Access:${NC}"
echo -e "  ${GREEN}ssh $USERNAME@$HOSTNAME.local${NC}"
echo ""
echo -e "${YELLOW}The hotspot will automatically start after every reboot.${NC}"
echo -e "${YELLOW}To stop it temporarily: sudo nmcli connection down '$SSID'${NC}"
echo -e "${YELLOW}To restart it: sudo nmcli connection up '$SSID'${NC}"
echo ""
read -p "Reboot now? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo reboot
fi
