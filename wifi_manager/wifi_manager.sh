#!/bin/bash

# Raspberry Pi Wi-Fi Manager
# Allows changing, connecting, disconnecting, and controlling Wi-Fi

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display menu
show_menu() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   Raspberry Pi Wi-Fi Manager${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "${BLUE}Current Wi-Fi Status:${NC}"
    
    # Check if Wi-Fi is hardware blocked
    if rfkill list wifi | grep -q "Soft blocked: yes"; then
        echo -e "${RED}Wi-Fi: SOFT BLOCKED (Disabled)${NC}"
    elif rfkill list wifi | grep -q "Hard blocked: yes"; then
        echo -e "${RED}Wi-Fi: HARD BLOCKED (Hardware switch off)${NC}"
    else
        # Check if connected to any network
        if iwgetid -r > /dev/null 2>&1; then
            CURRENT_SSID=$(iwgetid -r)
            CURRENT_IP=$(hostname -I | awk '{print $1}')
            echo -e "${GREEN}Connected to: $CURRENT_SSID${NC}"
            echo -e "${GREEN}IP Address: $CURRENT_IP${NC}"
        else
            echo -e "${YELLOW}Not connected to any network${NC}"
        fi
    fi
    
    echo -e "\n${BLUE}Options:${NC}"
    echo "1) Scan for available networks"
    echo "2) Connect to a Wi-Fi network"
    echo "3) Disconnect from current network"
    echo "4) Turn Wi-Fi ON"
    echo "5) Turn Wi-Fi OFF"
    echo "6) Show current connection details"
    echo "7) Forget a saved network"
    echo "8) List saved networks"
    echo "9) Enable AP mode (Access Point)"
    echo "10) Disable AP mode (Back to client mode)"
    echo "11) Exit"
    echo -e "${GREEN}========================================${NC}"
    read -p "Enter your choice [1-11]: " choice
}

# Function to scan for networks
scan_networks() {
    echo -e "${YELLOW}Scanning for Wi-Fi networks...${NC}"
    sudo iwlist wlan0 scan | grep -E "ESSID|Quality" | sed 's/^[ \t]*//'
    echo -e "\n${GREEN}Scan complete!${NC}"
    read -p "Press Enter to continue..."
}

# Function to connect to a network
connect_network() {
    echo -e "${YELLOW}Available networks:${NC}"
    sudo iwlist wlan0 scan | grep "ESSID" | sort -u | sed 's/^[ \t]*ESSID://g' | tr -d '"'
    
    echo ""
    read -p "Enter SSID (network name): " SSID
    read -s -p "Enter password (leave blank for open network): " PASSWORD
    echo ""
    
    # Create wpa_supplicant entry
    if [ -z "$PASSWORD" ]; then
        # Open network
        echo -e "${YELLOW}Connecting to open network: $SSID${NC}"
        sudo bash -c "cat >> /etc/wpa_supplicant/wpa_supplicant.conf << EOF
network={
    ssid=\"$SSID\"
    key_mgmt=NONE
}
EOF"
    else
        # Secured network
        echo -e "${YELLOW}Connecting to secured network: $SSID${NC}"
        # Generate encrypted password
        ENCRYPTED=$(wpa_passphrase "$SSID" "$PASSWORD" | grep -v "^[[:space:]]*#" | grep -v "^\t" | grep -v "psk=" | head -1)
        sudo bash -c "cat >> /etc/wpa_supplicant/wpa_supplicant.conf << EOF
network={
    ssid=\"$SSID\"
    psk=\"$PASSWORD\"
}
EOF"
    fi
    
    # Restart networking
    sudo systemctl restart wpa_supplicant
    sudo dhclient -r wlan0 2>/dev/null || true
    sudo dhclient wlan0
    
    echo -e "${GREEN}Attempting to connect to $SSID...${NC}"
    sleep 5
    
    if iwgetid -r | grep -q "$SSID"; then
        echo -e "${GREEN}Successfully connected to $SSID!${NC}"
        IP=$(hostname -I | awk '{print $1}')
        echo -e "${GREEN}IP Address: $IP${NC}"
    else
        echo -e "${RED}Failed to connect. Check password and try again.${NC}"
    fi
    read -p "Press Enter to continue..."
}

# Function to disconnect
disconnect_network() {
    echo -e "${YELLOW}Disconnecting from current network...${NC}"
    sudo dhclient -r wlan0
    sudo killall wpa_supplicant 2>/dev/null || true
    sudo ip link set wlan0 down
    echo -e "${GREEN}Disconnected!${NC}"
    read -p "Press Enter to continue..."
}

# Function to turn Wi-Fi ON
wifi_on() {
    echo -e "${YELLOW}Turning Wi-Fi ON...${NC}"
    sudo rfkill unblock wifi
    sudo ip link set wlan0 up
    sudo systemctl restart wpa_supplicant
    echo -e "${GREEN}Wi-Fi is now ON${NC}"
    sleep 2
    if iwgetid -r > /dev/null 2>&1; then
        echo -e "${GREEN}Auto-connected to: $(iwgetid -r)${NC}"
    fi
    read -p "Press Enter to continue..."
}

# Function to turn Wi-Fi OFF
wifi_off() {
    echo -e "${YELLOW}Turning Wi-Fi OFF...${NC}"
    sudo rfkill block wifi
    sudo ip link set wlan0 down
    echo -e "${GREEN}Wi-Fi is now OFF${NC}"
    read -p "Press Enter to continue..."
}

# Function to show connection details
show_details() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}Wi-Fi Connection Details:${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    if iwgetid -r > /dev/null 2>&1; then
        echo -e "SSID: ${GREEN}$(iwgetid -r)${NC}"
        echo -e "Interface: ${GREEN}wlan0${NC}"
        echo -e "IP Address: ${GREEN}$(hostname -I | awk '{print $1}')${NC}"
        echo -e "MAC Address: ${GREEN}$(cat /sys/class/net/wlan0/address)${NC}"
        echo -e "Signal Strength: ${GREEN}$(iwconfig wlan0 | grep -i quality | awk '{print $2}' | cut -d= -f2)${NC}"
        echo -e "Frequency: ${GREEN}$(iwconfig wlan0 | grep -i frequency | awk '{print $2}')${NC}"
    else
        echo -e "${RED}Not connected to any network${NC}"
    fi
    echo -e "${BLUE}========================================${NC}"
    read -p "Press Enter to continue..."
}

# Function to forget a saved network
forget_network() {
    echo -e "${YELLOW}Saved networks:${NC}"
    grep -E "^[[:space:]]*ssid=" /etc/wpa_supplicant/wpa_supplicant.conf | sed 's/.*ssid="\(.*\)"/\1/'
    
    read -p "Enter SSID to forget: " SSID
    sudo sed -i "/ssid=\"$SSID\"/,/^}/d" /etc/wpa_supplicant/wpa_supplicant.conf
    echo -e "${GREEN}Network $SSID forgotten!${NC}"
    read -p "Press Enter to continue..."
}

# Function to list saved networks
list_saved() {
    echo -e "${GREEN}Saved networks:${NC}"
    echo -e "${BLUE}========================================${NC}"
    grep -E "^[[:space:]]*ssid=" /etc/wpa_supplicant/wpa_supplicant.conf | sed 's/.*ssid="\(.*\)"/\1/' | nl
    echo -e "${BLUE}========================================${NC}"
    read -p "Press Enter to continue..."
}

# Function to enable AP mode
enable_ap_mode() {
    echo -e "${YELLOW}WARNING: This will disable client mode and enable Access Point mode${NC}"
    echo -e "${YELLOW}Make sure you have the AP setup script in the same directory${NC}"
    read -p "Continue? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "./setup_ap.sh" ]; then
            echo -e "${GREEN}Running AP setup script...${NC}"
            sudo ./setup_ap.sh
        else
            echo -e "${RED}setup_ap.sh not found in current directory!${NC}"
            echo -e "${YELLOW}Please run the AP setup script manually${NC}"
            read -p "Press Enter to continue..."
        fi
    else
        echo -e "${RED}Cancelled${NC}"
        read -p "Press Enter to continue..."
    fi
}

# Function to disable AP mode (back to client)
disable_ap_mode() {
    echo -e "${YELLOW}Disabling Access Point mode and restoring client mode...${NC}"
    sudo systemctl stop hostapd
    sudo systemctl stop dnsmasq
    sudo systemctl disable hostapd
    sudo systemctl disable dnsmasq
    
    # Restore wpa_supplicant
    sudo systemctl enable wpa_supplicant
    sudo systemctl restart wpa_supplicant
    
    # Restore dhcpcd
    sudo systemctl restart dhcpcd
    
    echo -e "${GREEN}AP mode disabled! Rebooting in 3 seconds...${NC}"
    sleep 3
    sudo reboot
}

# Main loop
while true; do
    show_menu
    case $choice in
        1) scan_networks ;;
        2) connect_network ;;
        3) disconnect_network ;;
        4) wifi_on ;;
        5) wifi_off ;;
        6) show_details ;;
        7) forget_network ;;
        8) list_saved ;;
        9) enable_ap_mode ;;
        10) disable_ap_mode ;;
        11) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid option. Please try again.${NC}"; sleep 2 ;;
    esac
    clear
done
