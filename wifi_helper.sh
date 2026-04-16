#!/bin/bash
# Wi-Fi Helper Script - Works in both AP and Client modes

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check current mode
is_ap_mode() {
    systemctl is-active --quiet hostapd
}

# Function to turn Wi-Fi ON (fixed)
wifi_on() {
    echo -e "${YELLOW}Turning Wi-Fi ON...${NC}"
    
    # If in AP mode, disable it first
    if is_ap_mode; then
        echo -e "${YELLOW}AP mode is active. Disabling it first...${NC}"
        sudo systemctl stop hostapd dnsmasq
        sudo systemctl disable hostapd dnsmasq
        sudo systemctl unmask wpa_supplicant
    fi
    
    # Enable client mode
    sudo rfkill unblock wifi
    sudo ip link set wlan0 up
    sudo systemctl enable wpa_supplicant
    sudo systemctl restart wpa_supplicant
    
    echo -e "${GREEN}✓ Wi-Fi is now ON (Client mode)${NC}"
    sleep 2
    
    if iwgetid -r > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Connected to: $(iwgetid -r)${NC}"
    else
        echo -e "${YELLOW}✗ Not connected to any network. Run 'wifi scan' to find networks.${NC}"
    fi
}

# Function to turn Wi-Fi OFF (fixed)
wifi_off() {
    echo -e "${YELLOW}Turning Wi-Fi OFF...${NC}"
    sudo rfkill block wifi
    sudo ip link set wlan0 down
    sudo systemctl stop wpa_supplicant
    echo -e "${GREEN}✓ Wi-Fi is now OFF${NC}"
}

# Function to show status (fixed)
show_status() {
    if is_ap_mode; then
        echo -e "${YELLOW}Mode: ACCESS POINT (broadcasting Wi-Fi)${NC}"
        AP_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
        echo -e "  AP IP: ${GREEN}$AP_IP${NC}"
    elif iwgetid -r > /dev/null 2>&1; then
        echo -e "${GREEN}Mode: CLIENT (connected to Wi-Fi)${NC}"
        echo -e "  Connected to: $(iwgetid -r)"
        echo -e "  IP: $(hostname -I | awk '{print $1}')"
    else
        echo -e "${YELLOW}Mode: CLIENT (not connected)${NC}"
    fi
}

# Function to scan (works in both modes)
wifi_scan() {
    if is_ap_mode; then
        echo -e "${RED}Cannot scan while in AP mode. Run 'apoff' first.${NC}"
        return
    fi
    echo -e "${YELLOW}Scanning for Wi-Fi networks...${NC}"
    sudo iwlist wlan0 scan | grep -E "ESSID|Quality"
}

# Function to connect (fixed)
wifi_connect() {
    if is_ap_mode; then
        echo -e "${RED}Cannot connect while in AP mode. Run 'apoff' first.${NC}"
        return
    fi
    
    echo -e "${YELLOW}Available networks:${NC}"
    sudo iwlist wlan0 scan | grep "ESSID" | sort -u | sed 's/^[ \t]*ESSID://g' | tr -d '"'
    
    read -p "Enter SSID: " ssid
    read -s -p "Enter password: " pass
    echo ""
    
    # Use nmcli (works better than wpa_supplicant)
    if [ -z "$pass" ]; then
        sudo nmcli device wifi connect "$ssid"
    else
        sudo nmcli device wifi connect "$ssid" password "$pass"
    fi
    
    sleep 3
    show_status
}

# Main command handler
case "$1" in
    on) wifi_on ;;
    off) wifi_off ;;
    scan) wifi_scan ;;
    status) show_status ;;
    connect) wifi_connect ;;
    *) 
        echo "Wi-Fi Helper Commands:"
        echo "  wifi on      - Turn Wi-Fi ON (Client mode)"
        echo "  wifi off     - Turn Wi-Fi OFF"
        echo "  wifi scan    - Scan for networks"
        echo "  wifi status  - Show current mode and connection"
        echo "  wifi connect - Connect to a network"
        ;;
esac
