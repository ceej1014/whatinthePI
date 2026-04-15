#!/bin/bash
# Standalone script to change Raspberry Pi hostname

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Change Raspberry Pi Hostname${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

CURRENT=$(hostname)
echo -e "${BLUE}Current hostname: ${GREEN}$CURRENT${NC}"
echo ""

read -p "Enter new hostname: " NEW_HOSTNAME

if [ -z "$NEW_HOSTNAME" ]; then
    echo -e "${RED}No hostname entered. Exiting.${NC}"
    exit 1
fi

if [ "$NEW_HOSTNAME" = "$CURRENT" ]; then
    echo -e "${YELLOW}Hostname unchanged. Exiting.${NC}"
    exit 0
fi

echo -e "${YELLOW}Changing hostname from $CURRENT to $NEW_HOSTNAME...${NC}"

# Change hostname
echo "$NEW_HOSTNAME" | sudo tee /etc/hostname

# Update hosts file
sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts

# Update avahi/mDNS for .local resolution
if command -v avahi-daemon &> /dev/null; then
    sudo systemctl restart avahi-daemon
fi

echo -e "${GREEN}✓ Hostname changed to $NEW_HOSTNAME${NC}"
echo ""
echo -e "${YELLOW}Reboot required for changes to take effect${NC}"
read -p "Reboot now? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Rebooting...${NC}"
    sudo reboot
else
    echo -e "${YELLOW}Remember to reboot later for hostname change to apply${NC}"
    echo ""
    echo -e "To reboot later, type: ${GREEN}sudo reboot${NC}"
fi
