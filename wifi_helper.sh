#!/bin/bash
# Wi-Fi Helper - Works in both AP and Client modes, shows Ethernet IP

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

is_ap_mode() { systemctl is-active --quiet hostapd 2>/dev/null && [ -f /etc/hostapd/hostapd.conf ]; }

case "$1" in
    on)
        echo -e "${YELLOW}Switching to Client Mode...${NC}"
        if is_ap_mode; then
            sudo systemctl stop hostapd dnsmasq 2>/dev/null || true
            sudo systemctl disable hostapd dnsmasq 2>/dev/null || true
        fi
        sudo systemctl unmask wpa_supplicant 2>/dev/null || true
        sudo systemctl enable wpa_supplicant
        sudo systemctl restart wpa_supplicant
        sudo rfkill unblock wifi
        sudo ip link set wlan0 up
        echo -e "${GREEN}✓ Client mode enabled${NC}"
        ;;
    off)
        echo -e "${YELLOW}Turning Wi-Fi OFF...${NC}"
        sudo systemctl stop wpa_supplicant hostapd dnsmasq 2>/dev/null || true
        sudo rfkill block wifi
        sudo ip link set wlan0 down
        echo -e "${GREEN}✓ Wi-Fi OFF${NC}"
        ;;
    ap)
        echo -e "${YELLOW}Switching to AP Mode...${NC}"
        if ! [ -f /etc/hostapd/hostapd.conf ]; then
            echo -e "${RED}AP not configured yet. Run 'apsetup' first.${NC}"
            exit 1
        fi
        sudo systemctl stop wpa_supplicant 2>/dev/null || true
        sudo systemctl mask wpa_supplicant
        sudo systemctl unmask hostapd
        sudo systemctl enable hostapd dnsmasq
        sudo systemctl start hostapd dnsmasq
        echo -e "${GREEN}✓ AP mode enabled${NC}"
        ;;
    status)
        if is_ap_mode; then
            echo -e "${YELLOW}Mode: ACCESS POINT${NC}"
            AP_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
            SSID=$(sudo grep "^ssid" /etc/hostapd/hostapd.conf 2>/dev/null | cut -d= -f2)
            echo -e "  AP SSID: ${GREEN}${SSID:-unknown}${NC}"
            echo -e "  AP IP:   ${GREEN}${AP_IP:-unknown}${NC}"
        elif iwgetid -r > /dev/null 2>&1; then
            echo -e "${GREEN}Mode: CLIENT (connected)${NC}"
            echo -e "  Connected to: ${GREEN}$(iwgetid -r)${NC}"
            echo -e "  Wi-Fi IP:     ${GREEN}$(hostname -I | awk '{print $1}')${NC}"
        elif systemctl is-active --quiet wpa_supplicant; then
            echo -e "${YELLOW}Mode: CLIENT (not connected)${NC}"
        else
            echo -e "${RED}Wi-Fi is OFF${NC}"
        fi
        # Show Ethernet IP regardless of Wi-Fi mode
        if ip link show eth0 | grep -q "state UP"; then
            ETH_IP=$(ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
            echo -e "  Ethernet IP:  ${GREEN}$ETH_IP${NC}"
        else
            echo -e "  Ethernet:     ${RED}Not connected${NC}"
        fi
        ;;
    scan)
        if is_ap_mode; then
            echo -e "${RED}Cannot scan in AP mode. Run 'wifi off' first.${NC}"
            exit 1
        fi
        echo -e "${YELLOW}Scanning for networks...${NC}"
        sudo iwlist wlan0 scan 2>/dev/null | grep -E "ESSID|Quality|Encryption" | sed 's/^[ \t]*//'
        ;;
    connect)
        if is_ap_mode; then
            echo -e "${RED}Cannot connect in AP mode. Run 'wifi off' first.${NC}"
            exit 1
        fi
        echo -e "${YELLOW}Available networks:${NC}"
        sudo iwlist wlan0 scan 2>/dev/null | grep "ESSID" | sort -u | sed 's/^[ \t]*ESSID://g' | tr -d '"'
        echo ""
        read -p "Enter SSID: " ssid
        if [ -z "$ssid" ]; then
            echo -e "${RED}No SSID entered.${NC}"
            exit 1
        fi
        # Use interactive connection (most reliable, handles passwords correctly)
        echo -e "${YELLOW}Attempting to connect to $ssid...${NC}"
        sudo nmcli --ask device wifi connect "$ssid"
        sleep 3
        if iwgetid -r 2>/dev/null | grep -q "$ssid"; then
            echo -e "${GREEN}✓ Connected to $ssid${NC}"
        else
            echo -e "${RED}✗ Failed to connect. Check SSID/password.${NC}"
        fi
        ;;
    help|--help|-h|"")
        echo -e "${BLUE}Wi-Fi Helper Commands:${NC}"
        echo "  wifi on      - Switch to Client mode"
        echo "  wifi off     - Turn Wi-Fi OFF completely"
        echo "  wifi ap      - Switch to AP mode (hotspot)"
        echo "  wifi status  - Show current mode, Wi-Fi IP, and Ethernet IP"
        echo "  wifi scan    - Scan for networks (client mode only)"
        echo "  wifi connect - Connect to a network (client mode only)"
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo "Run 'wifi help' for available commands"
        exit 1
        ;;
esac
