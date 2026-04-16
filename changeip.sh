#!/bin/bash
# Change Access Point IP Address (NetworkManager compatible)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Change Access Point IP Address${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

if ! systemctl is-active --quiet hostapd; then
    echo -e "${RED}AP mode is not currently active!${NC}"
    echo -e "To enable AP mode, run: ${GREEN}apsetup${NC}"
    exit 1
fi

CURRENT_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
echo -e "${BLUE}Current AP IP: ${GREEN}$CURRENT_IP${NC}"
echo ""

read -p "Enter new static IP address for AP [192.168.50.1]: " NEW_IP
NEW_IP=${NEW_IP:-192.168.50.1}

if [ "$NEW_IP" = "$CURRENT_IP" ]; then
    echo -e "${YELLOW}IP unchanged. Exiting.${NC}"
    exit 0
fi

echo -e "${YELLOW}Changing AP IP from $CURRENT_IP to $NEW_IP...${NC}"

# Stop AP services
sudo systemctl stop hostapd dnsmasq

# Update dnsmasq config
NETWORK_PREFIX="${NEW_IP%.*}"
sudo sed -i "s|^dhcp-range=.*|dhcp-range=${NETWORK_PREFIX}.10,${NETWORK_PREFIX}.100,255.255.255.0,24h|" /etc/dnsmasq.conf
sudo sed -i "s|^dhcp-option=3,.*|dhcp-option=3,$NEW_IP|" /etc/dnsmasq.conf
sudo sed -i "s|^dhcp-option=6,.*|dhcp-option=6,$NEW_IP|" /etc/dnsmasq.conf

# Update wlan0 IP (immediate)
sudo ip addr flush dev wlan0
sudo ip addr add "${NEW_IP}/24" dev wlan0

# Persist via NetworkManager (Bookworm)
if command -v nmcli &>/dev/null; then
    # Remove any existing connection for wlan0
    sudo nmcli connection delete "wlan0" 2>/dev/null
    # Create new static connection
    sudo nmcli connection add type ethernet con-name "wlan0" ifname wlan0 ipv4.method manual ipv4.addresses "${NEW_IP}/24"
fi

# Restart AP services
sudo systemctl start hostapd dnsmasq

echo -e "${GREEN}✓ AP IP changed to $NEW_IP${NC}"
echo -e "${YELLOW}Note: You may need to reconnect to the AP with the new IP${NC}"
echo -e "SSH command: ${GREEN}ssh $(whoami)@$NEW_IP${NC}"
