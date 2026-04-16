#!/bin/bash
# Change Access Point IP Address

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

# Check if AP mode is enabled
if ! systemctl is-active --quiet hostapd; then
    echo -e "${RED}AP mode is not currently active!${NC}"
    echo ""
    echo -e "${YELLOW}This script only works when AP mode is enabled.${NC}"
    echo -e "To enable AP mode, run: ${GREEN}apsetup${NC}"
    echo ""
    exit 1
fi

# Get current IP
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

# Stop services
sudo systemctl stop hostapd dnsmasq

# Update dhcpcd.conf
sudo sed -i "s/static ip_address=.*/static ip_address=$NEW_IP\/24/" /etc/dhcpcd.conf

# Update dnsmasq.conf
NETWORK_PREFIX="${NEW_IP%.*}"
sudo sed -i "s|^dhcp-range=.*|dhcp-range=${NETWORK_PREFIX}.10,${NETWORK_PREFIX}.100,255.255.255.0,24h|" /etc/dnsmasq.conf
sudo sed -i "s/dhcp-option=3,.*/dhcp-option=3,$NEW_IP/" /etc/dnsmasq.conf
sudo sed -i "s/dhcp-option=6,.*/dhcp-option=6,$NEW_IP/" /etc/dnsmasq.conf
sudo sed -i "s/listen-address=.*/listen-address=$NEW_IP/" /etc/dnsmasq.conf

# Restart services
sudo systemctl restart dhcpcd
sudo systemctl start hostapd dnsmasq

echo -e "${GREEN}✓ AP IP changed to $NEW_IP${NC}"
echo ""
echo -e "${YELLOW}Note: You may need to reconnect to the AP with the new IP${NC}"
echo -e "SSH command: ${GREEN}ssh $(whoami)@$NEW_IP${NC}"
echo ""
