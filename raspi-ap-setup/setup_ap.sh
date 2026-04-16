#!/bin/bash
# AP setup using NetworkManager hotspot (persistent)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Raspberry Pi 4B - Access Point Setup (NetworkManager)${NC}"
echo -e "${GREEN}========================================${NC}"

DEFAULT_SSID="RPi_Network"
DEFAULT_PASS="raspberry123"

read -p "Enter SSID [$DEFAULT_SSID]: " SSID
SSID=${SSID:-$DEFAULT_SSID}
read -s -p "Enter password (min 8 chars) [$DEFAULT_PASS]: " PASS
echo ""
PASS=${PASS:-$DEFAULT_PASS}
if [ ${#PASS} -lt 8 ]; then
    echo -e "${RED}Password too short, using default.${NC}"
    PASS=$DEFAULT_PASS
fi

# Remove old profile if exists
sudo nmcli connection delete "$SSID" 2>/dev/null

# Create hotspot
sudo nmcli connection add type wifi ifname wlan0 con-name "$SSID" autoconnect yes ssid "$SSID" mode ap ipv4.method shared wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$PASS"
sudo nmcli connection modify "$SSID" connection.autoconnect-priority 100

echo -e "${GREEN}✓ Hotspot configured. Start it with 'wifi ap' or 'sudo nmcli connection up "$SSID"'${NC}"
