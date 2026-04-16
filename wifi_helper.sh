#!/bin/bash
# Wi-Fi Helper - Works in both AP and Client modes
# Fixed AP detection - only shows AP mode if hostapd is actually running

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Fixed AP detection - checks if hostapd is actually running AND has config
is_ap_mode() { 
    systemctl is-active --quiet hostapd 2>/dev/null && [ -f /etc/hostapd/hostapd.conf ]
}

# Fixed client mode detection
is_client_mode() {
    systemctl is-active --quiet wpa_supplicant 2>/dev/null
}

case "$1" in
    on)
        echo -e "${YELLOW}Switching to Client Mode...${NC}"
        if is_ap_mode; then
            sudo systemctl stop hostapd dnsmasq
            sudo systemctl disable hostapd dnsmasq
        fi
        sudo systemctl unmask wpa_supplicant 2>/dev/null
        sudo systemctl enable wpa_supplicant
        sudo systemctl restart wpa_supplicant
        sudo rfkill unblock wifi
        sudo ip link set wlan0 up
        echo -e "${GREEN}✓ Client mode enabled${NC}"
        ;;
    off)
        echo -e "${YELLOW}Turning Wi-Fi OFF...${NC}"
        sudo rfkill block wifi
        sudo ip link set wlan0 down
        sudo systemctl stop wpa_supplicant
        echo -e "${GREEN}✓ Wi-Fi OFF${NC}"
        ;;
    ap)
        echo -e "${YELLOW}Switching to AP Mode...${NC}"
        sudo systemctl stop wpa_supplicant
        sudo systemctl mask wpa_supplicant
        sudo systemctl unmask hostapd
        sudo systemctl enable hostapd
        sudo systemctl start hostapd
        sudo systemctl start dnsmasq
        echo -e "${GREEN}✓ AP mode enabled${NC}"
        ;;
    status)
        if is_ap_mode; then
            echo -e "${YELLOW}Mode: ACCESS POINT (broadcasting Wi-Fi)${NC}"
            AP_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
            echo -e "  AP IP: ${GREEN}$AP_IP${NC}"
            SSID=$(sudo grep "^ssid" /etc/hostapd/hostapd.conf | cut -d= -f2)
            echo -e "  SSID: ${GREEN}$SSID${NC}"
        elif iwgetid -r > /dev/null 2>&1; then
            echo -e "${GREEN}Mode: CLIENT (connected to Wi-Fi)${NC}"
            echo -e "  Connected to: ${GREEN}$(iwgetid -r)${NC}"
            echo -e "  IP: ${GREEN}$(hostname -I | awk '{print $1}')${NC}"
        elif is_client_mode; then
            echo -e "${YELLOW}Mode: CLIENT (not connected to any network)${NC}"
        else
            echo -e "${RED}Wi-Fi is disabled${NC}"
        fi
        ;;
    scan)
        if is_ap_mode; then
            echo -e "${RED}Cannot scan while in AP mode. Run 'wifi off' first.${NC}"
        else
            echo -e "${YELLOW}Scanning for Wi-Fi networks...${NC}"
            sudo iwlist wlan0 scan | grep -E "ESSID|Quality|Encryption" | sed 's/^[ \t]*//'
        fi
        ;;
    connect)
        if is_ap_mode; then
            echo -e "${RED}Cannot connect while in AP mode. Run 'wifi off' first.${NC}"
        else
            echo -e "${YELLOW}Available networks:${NC}"
            sudo iwlist wlan0 scan | grep "ESSID" | sort -u | sed 's/^[ \t]*ESSID://g' | tr -d '"'
            echo ""
            read -p "Enter SSID: " ssid
            read -s -p "Enter password (press Enter for open network): " pass
            echo ""
            if [ -z "$pass" ]; then
                sudo nmcli device wifi connect "$ssid"
            else
                sudo nmcli device wifi connect "$ssid" password "$pass"
            fi
            sleep 3
            if iwgetid -r | grep -q "$ssid"; then
                echo -e "${GREEN}✓ Connected to $ssid${NC}"
            else
                echo -e "${RED}✗ Failed to connect${NC}"
            fi
        fi
        ;;
    disable)
        echo -e "${YELLOW}Disabling Wi-Fi completely...${NC}"
        sudo rfkill block wifi
        sudo ip link set wlan0 down
        sudo systemctl stop wpa_supplicant hostapd dnsmasq 2>/dev/null
        echo -e "${GREEN}✓ Wi-Fi disabled${NC}"
        ;;
    enable)
        echo -e "${YELLOW}Enabling Wi-Fi...${NC}"
        sudo rfkill unblock wifi
        sudo ip link set wlan0 up
        echo -e "${GREEN}✓ Wi-Fi enabled${NC}"
        ;;
    help|--help|-h)
        echo -e "${BLUE}Wi-Fi Helper Commands:${NC}"
        echo "  wifi on      - Switch to Client mode (connect to Wi-Fi)"
        echo "  wifi off     - Turn Wi-Fi OFF completely"
        echo "  wifi ap      - Switch to AP mode (create Wi-Fi hotspot)"
        echo "  wifi status  - Show current mode and connection"
        echo "  wifi scan    - Scan for networks (client mode only)"
        echo "  wifi connect - Connect to a network (client mode only)"
        echo "  wifi enable  - Enable Wi-Fi radio"
        echo "  wifi disable - Disable Wi-Fi radio"
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo "Run 'wifi help' for available commands"
        ;;
esac
