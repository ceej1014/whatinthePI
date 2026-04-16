#!/bin/bash
# Change Access Point IP Address (NetworkManager version)
# Updates the IP of the currently selected hotspot profile

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

# Get current hotspot profile
CONFIG_DIR="/etc/whatinthepi"
CURRENT_PROFILE_FILE="$CONFIG_DIR/current_profile"
if [ -f "$CURRENT_PROFILE_FILE" ]; then
    CURRENT_PROFILE=$(cat "$CURRENT_PROFILE_FILE")
else
    CURRENT_PROFILE=""
fi

if [ -z "$CURRENT_PROFILE" ]; then
    echo -e "${RED}No hotspot profile selected. Please run 'wifi ap-setup' first.${NC}"
    exit 1
fi

# Check if the profile exists in NetworkManager
if ! nmcli con show "$CURRENT_PROFILE" &>/dev/null; then
    echo -e "${RED}Hotspot profile '$CURRENT_PROFILE' not found in NetworkManager.${NC}"
    echo -e "${YELLOW}Please reconfigure with 'wifi ap-setup'.${NC}"
    exit 1
fi

# Get current IP from the connection
CURRENT_IP=$(nmcli -t -f ipv4.addresses con show "$CURRENT_PROFILE" | cut -d: -f2 | cut -d/ -f1)
if [ -z "$CURRENT_IP" ]; then
    # Fallback to wlan0 IP if not set in profile
    CURRENT_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
fi
echo -e "${BLUE}Current AP IP: ${GREEN}$CURRENT_IP${NC}"
echo ""

read -p "Enter new static IP address for AP [192.168.50.1]: " NEW_IP
NEW_IP=${NEW_IP:-192.168.50.1}

if [ "$NEW_IP" = "$CURRENT_IP" ]; then
    echo -e "${YELLOW}IP unchanged. Exiting.${NC}"
    exit 0
fi

echo -e "${YELLOW}Changing AP IP from $CURRENT_IP to $NEW_IP...${NC}"

# Stop the AP connection if it's active
WAS_ACTIVE=false
if nmcli -t -f NAME con show --active | grep -q "^$CURRENT_PROFILE$"; then
    WAS_ACTIVE=true
    echo -e "${YELLOW}Stopping AP mode...${NC}"
    sudo nmcli connection down "$CURRENT_PROFILE"
    sleep 1
fi

# Update the connection's IPv4 address
sudo nmcli connection modify "$CURRENT_PROFILE" ipv4.addresses "$NEW_IP/24"
sudo nmcli connection modify "$CURRENT_PROFILE" ipv4.gateway "$NEW_IP"
sudo nmcli connection modify "$CURRENT_PROFILE" ipv4.method shared

# Restart the AP if it was active
if [ "$WAS_ACTIVE" = true ]; then
    echo -e "${YELLOW}Restarting AP mode with new IP...${NC}"
    sudo nmcli connection up "$CURRENT_PROFILE"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ AP restarted successfully.${NC}"
    else
        echo -e "${RED}✗ Failed to restart AP. You may need to run 'wifi ap' manually.${NC}"
    fi
else
    echo -e "${YELLOW}AP mode was not active. Changes will apply next time you start it.${NC}"
fi

echo -e "${GREEN}✓ AP IP changed to $NEW_IP${NC}"
echo ""
echo -e "${YELLOW}Note: If the AP was running, it has been restarted.${NC}"
echo -e "${YELLOW}You may need to reconnect to the AP with the new IP.${NC}"
echo -e "SSH command: ${GREEN}ssh $(whoami)@$NEW_IP${NC}"
