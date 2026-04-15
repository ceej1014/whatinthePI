#!/bin/bash
# Wi-Fi Helper Script - Quick Wi-Fi commands for Raspberry Pi
# Usage: wifi [on|off|scan|status|connect|disconnect|list|forget]

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to show current status
show_status() {
    if iwgetid -r > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Connected to: $(iwgetid -r)${NC}"
        echo -e "${GREEN}✓ IP Address: $(hostname -I | awk '{print $1}')${NC}"
        echo -e "${GREEN}✓ Signal: $(iwconfig wlan0 2>/dev/null | grep -i quality | awk '{print $2}' | cut -d= -f2)${NC}"
    else
        echo -e "${RED}✗ Not connected to any network${NC}"
    fi
}

# Function to turn Wi-Fi ON
wifi_on() {
    echo -e "${YELLOW}Turning Wi-Fi ON...${NC}"
    sudo rfkill unblock wifi
    sudo ip link set wlan0 up
    sudo systemctl restart wpa_supplicant
    sleep 2
    echo -e "${GREEN}✓ Wi-Fi is now ON${NC}"
    show_status
}

# Function to turn Wi-Fi OFF
wifi_off() {
    echo -e "${YELLOW}Turning Wi-Fi OFF...${NC}"
    sudo rfkill block wifi
    sudo ip link set wlan0 down
    echo -e "${GREEN}✓ Wi-Fi is now OFF${NC}"
}

# Function to scan for networks
wifi_scan() {
    echo -e "${YELLOW}Scanning for Wi-Fi networks...${NC}"
    echo -e "${BLUE}========================================${NC}"
    sudo iwlist wlan0 scan | grep -E "ESSID|Quality|Encryption" | sed 's/^[ \t]*//' | while read line; do
        if [[ $line == ESSID* ]]; then
            echo -e "${GREEN}$line${NC}"
        elif [[ $line == Quality* ]]; then
            echo -e "  $line"
        elif [[ $line == Encryption* ]]; then
            echo -e "  $line"
        fi
    done
    echo -e "${BLUE}========================================${NC}"
}

# Function to connect to a network
wifi_connect() {
    echo -e "${YELLOW}Connect to Wi-Fi Network${NC}"
    read -p "Enter SSID (network name): " ssid
    
    # Check if network already exists in wpa_supplicant
    if grep -q "ssid=\"$ssid\"" /etc/wpa_supplicant/wpa_supplicant.conf; then
        echo -e "${YELLOW}Network '$ssid' already saved. Connecting...${NC}"
        sudo systemctl restart wpa_supplicant
        sleep 3
        show_status
        return
    fi
    
    read -s -p "Enter password (press Enter for open network): " pass
    echo ""
    
    if [ -z "$pass" ]; then
        # Open network
        echo -e "${YELLOW}Connecting to open network: $ssid${NC}"
        sudo bash -c "cat >> /etc/wpa_supplicant/wpa_supplicant.conf << EOF

network={
    ssid=\"$ssid\"
    key_mgmt=NONE
}
EOF"
    else
        # Secured network
        echo -e "${YELLOW}Connecting to secured network: $ssid${NC}"
        sudo bash -c "cat >> /etc/wpa_supplicant/wpa_supplicant.conf << EOF

network={
    ssid=\"$ssid\"
    psk=\"$pass\"
}
EOF"
    fi
    
    # Restart Wi-Fi to apply changes
    sudo systemctl restart wpa_supplicant
    sudo dhclient -r wlan0 2>/dev/null || true
    sudo dhclient wlan0 2>/dev/null || true
    
    sleep 5
    
    # Check if connected
    if iwgetid -r | grep -q "$ssid"; then
        echo -e "${GREEN}✓ Successfully connected to $ssid!${NC}"
        show_status
    else
        echo -e "${RED}✗ Failed to connect to $ssid${NC}"
        echo -e "${YELLOW}Tips:${NC}"
        echo "  - Check your password"
        echo "  - Make sure the network is in range"
        echo "  - Try running: sudo wifi scan"
    fi
}

# Function to disconnect
wifi_disconnect() {
    echo -e "${YELLOW}Disconnecting from current network...${NC}"
    CURRENT=$(iwgetid -r)
    sudo dhclient -r wlan0
    sudo ip link set wlan0 down
    sudo ip link set wlan0 up
    echo -e "${GREEN}✓ Disconnected from $CURRENT${NC}"
}

# Function to list saved networks
wifi_list() {
    echo -e "${GREEN}Saved Networks:${NC}"
    echo -e "${BLUE}========================================${NC}"
    sudo grep -E "^[[:space:]]*ssid=" /etc/wpa_supplicant/wpa_supplicant.conf | sed 's/.*ssid="\(.*\)"/\1/' | nl
    echo -e "${BLUE}========================================${NC}"
}

# Function to forget a network
wifi_forget() {
    wifi_list
    echo ""
    read -p "Enter the SSID to forget: " ssid
    
    if grep -q "ssid=\"$ssid\"" /etc/wpa_supplicant/wpa_supplicant.conf; then
        sudo sed -i "/ssid=\"$ssid\"/,/^}/d" /etc/wpa_supplicant/wpa_supplicant.conf
        echo -e "${GREEN}✓ Network '$ssid' forgotten${NC}"
        
        # If currently connected to this network, disconnect
        if iwgetid -r | grep -q "$ssid"; then
            wifi_disconnect
        fi
    else
        echo -e "${RED}✗ Network '$ssid' not found${NC}"
    fi
}

# Function to show signal strength
wifi_signal() {
    if iwgetid -r > /dev/null 2>&1; then
        QUALITY=$(iwconfig wlan0 2>/dev/null | grep -i quality | awk '{print $2}' | cut -d= -f2)
        SIGNAL=$(iwconfig wlan0 2>/dev/null | grep -i signal | awk '{print $4}' | cut -d= -f2)
        
        echo -e "${GREEN}Current Signal:${NC}"
        echo -e "  Quality: $QUALITY"
        echo -e "  Signal: $SIGNAL"
        
        # Visual signal bar
        if [[ $QUALITY =~ ([0-9]+)/([0-9]+) ]]; then
            CURRENT=${BASH_REMATCH[1]}
            MAX=${BASH_REMATCH[2]}
            PERCENT=$((CURRENT * 100 / MAX))
            
            echo -n "  Signal: ["
            for i in $(seq 1 10); do
                if [ $i -le $((PERCENT / 10)) ]; then
                    echo -n "#"
                else
                    echo -n "."
                fi
            done
            echo -e "] $PERCENT%"
        fi
    else
        echo -e "${RED}Not connected to any network${NC}"
    fi
}

# Function to show help
show_help() {
    echo -e "${GREEN}Wi-Fi Helper Commands${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "  ${YELLOW}wifi on${NC}         - Turn Wi-Fi ON"
    echo -e "  ${YELLOW}wifi off${NC}        - Turn Wi-Fi OFF"
    echo -e "  ${YELLOW}wifi scan${NC}       - Scan for available networks"
    echo -e "  ${YELLOW}wifi status${NC}     - Show current connection status"
    echo -e "  ${YELLOW}wifi connect${NC}    - Connect to a Wi-Fi network"
    echo -e "  ${YELLOW}wifi disconnect${NC} - Disconnect from current network"
    echo -e "  ${YELLOW}wifi list${NC}       - List saved networks"
    echo -e "  ${YELLOW}wifi forget${NC}     - Forget a saved network"
    echo -e "  ${YELLOW}wifi signal${NC}     - Show signal strength"
    echo -e "  ${YELLOW}wifi help${NC}       - Show this help message"
    echo -e "${BLUE}========================================${NC}"
}

# Main command handler
case "$1" in
    on)
        wifi_on
        ;;
    off)
        wifi_off
        ;;
    scan)
        wifi_scan
        ;;
    status)
        show_status
        ;;
    connect)
        wifi_connect
        ;;
    disconnect)
        wifi_disconnect
        ;;
    list)
        wifi_list
        ;;
    forget)
        wifi_forget
        ;;
    signal)
        wifi_signal
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        if [ -z "$1" ]; then
            show_help
        else
            echo -e "${RED}Unknown command: $1${NC}"
            echo ""
            show_help
        fi
        ;;
esac

exit 0
