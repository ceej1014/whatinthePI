#!/bin/bash
# Unified Wi-Fi Manager – Command-line + Interactive menu
# Usage:
#   wifi               → opens interactive menu
#   wifi on|off|ap|ap-setup|status|scan|connect → quick commands

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------
is_ap_mode() {
    systemctl is-active --quiet hostapd 2>/dev/null && [ -f /etc/hostapd/hostapd.conf ]
}

show_status() {
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
    # Show Ethernet IP
    if ip link show eth0 | grep -q "state UP"; then
        ETH_IP=$(ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
        echo -e "  Ethernet IP:  ${GREEN}$ETH_IP${NC}"
    else
        echo -e "  Ethernet:     ${RED}Not connected${NC}"
    fi
}

# ------------------------------------------------------------
# Command-line actions
# ------------------------------------------------------------
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
            echo -e "${RED}AP not configured yet. Run 'wifi ap-setup' first.${NC}"
            exit 1
        fi
        sudo systemctl stop wpa_supplicant 2>/dev/null || true
        sudo systemctl mask wpa_supplicant
        sudo systemctl unmask hostapd
        sudo systemctl enable hostapd dnsmasq
        sudo systemctl start hostapd dnsmasq
        echo -e "${GREEN}✓ AP mode enabled${NC}"
        ;;
    ap-setup)
        echo -e "${YELLOW}Running Access Point setup...${NC}"
        if [ -f ~/whatinthePI/raspi-ap-setup/setup_ap.sh ]; then
            sudo ~/whatinthePI/raspi-ap-setup/setup_ap.sh
        else
            echo -e "${RED}AP setup script not found. Please reinstall whatinthePI.${NC}"
            exit 1
        fi
        ;;
    ap-off)
        echo -e "${YELLOW}Turning OFF AP Mode...${NC}"
        sudo systemctl stop hostapd dnsmasq 2>/dev/null || true
        sudo systemctl disable hostapd dnsmasq 2>/dev/null || true
        sudo systemctl unmask wpa_supplicant
        sudo systemctl enable wpa_supplicant
        sudo systemctl restart wpa_supplicant
        echo -e "${GREEN}✓ AP mode disabled, client mode restored${NC}"
        ;;
    status)
        show_status
        ;;
    scan)
        if is_ap_mode; then
            echo -e "${RED}Cannot scan in AP mode. Run 'wifi ap-off' first.${NC}"
            exit 1
        fi
        echo -e "${YELLOW}Scanning for networks...${NC}"
        sudo iwlist wlan0 scan 2>/dev/null | grep -E "ESSID|Quality|Encryption" | sed 's/^[ \t]*//'
        ;;
    connect)
        if is_ap_mode; then
            echo -e "${RED}Cannot connect in AP mode. Run 'wifi ap-off' first.${NC}"
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
        # Use interactive connection (most reliable)
        echo -e "${YELLOW}Attempting to connect to $ssid...${NC}"
        sudo nmcli --ask device wifi connect "$ssid"
        sleep 3
        if iwgetid -r 2>/dev/null | grep -q "$ssid"; then
            echo -e "${GREEN}✓ Connected to $ssid${NC}"
        else
            echo -e "${RED}✗ Failed to connect. Check SSID/password.${NC}"
        fi
        ;;
    help|--help|-h)
        echo -e "${BLUE}Unified Wi-Fi Manager Commands:${NC}"
        echo "  wifi           - Open interactive menu"
        echo "  wifi on        - Switch to Client mode"
        echo "  wifi off       - Turn Wi-Fi OFF completely"
        echo "  wifi ap        - Switch to AP mode (hotspot) – requires configured AP"
        echo "  wifi ap-setup  - Run the AP configuration script"
        echo "  wifi ap-off    - Turn OFF AP mode, back to client"
        echo "  wifi status    - Show current mode and IPs"
        echo "  wifi scan      - Scan for networks (client mode only)"
        echo "  wifi connect   - Connect to a network (client mode only)"
        echo "  wifi help      - Show this help"
        ;;
    "")
        # No arguments – launch interactive menu
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo "Run 'wifi help' for available commands"
        exit 1
        ;;
esac

# ------------------------------------------------------------
# Interactive menu (if no arguments were given)
# ------------------------------------------------------------
if [ -z "$1" ]; then
    while true; do
        clear
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}      Unified Wi-Fi Manager${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo -e "${BLUE}Current Status:${NC}"
        show_status
        echo ""
        echo -e "${BLUE}Options:${NC}"
        echo "1)  Switch to Client Mode (connect to Wi-Fi)"
        echo "2)  Switch to AP Mode (create hotspot)"
        echo "3)  Run AP Setup (configure hotspot)"
        echo "4)  Turn OFF AP Mode (back to client)"
        echo "5)  Scan for networks"
        echo "6)  Connect to a network"
        echo "7)  Turn Wi-Fi OFF"
        echo "8)  Show connection details"
        echo "9)  Exit"
        echo -e "${GREEN}========================================${NC}"
        read -p "Enter your choice [1-9]: " choice

        case $choice in
            1)
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
                read -p "Press Enter..."
                ;;
            2)
                echo -e "${YELLOW}Switching to AP Mode...${NC}"
                if ! [ -f /etc/hostapd/hostapd.conf ]; then
                    echo -e "${RED}AP not configured yet. Please run option 3 first.${NC}"
                else
                    sudo systemctl stop wpa_supplicant 2>/dev/null || true
                    sudo systemctl mask wpa_supplicant
                    sudo systemctl unmask hostapd
                    sudo systemctl enable hostapd dnsmasq
                    sudo systemctl start hostapd dnsmasq
                    echo -e "${GREEN}✓ AP mode enabled${NC}"
                fi
                read -p "Press Enter..."
                ;;
            3)
                echo -e "${YELLOW}Running AP Setup...${NC}"
                if [ -f ~/whatinthePI/raspi-ap-setup/setup_ap.sh ]; then
                    sudo ~/whatinthePI/raspi-ap-setup/setup_ap.sh
                else
                    echo -e "${RED}AP setup script not found.${NC}"
                fi
                read -p "Press Enter..."
                ;;
            4)
                echo -e "${YELLOW}Turning OFF AP Mode...${NC}"
                sudo systemctl stop hostapd dnsmasq 2>/dev/null || true
                sudo systemctl disable hostapd dnsmasq 2>/dev/null || true
                sudo systemctl unmask wpa_supplicant
                sudo systemctl enable wpa_supplicant
                sudo systemctl restart wpa_supplicant
                echo -e "${GREEN}✓ AP mode disabled, client mode restored${NC}"
                read -p "Press Enter..."
                ;;
            5)
                if is_ap_mode; then
                    echo -e "${RED}Cannot scan in AP mode. Switch to Client Mode first.${NC}"
                else
                    echo -e "${YELLOW}Scanning...${NC}"
                    sudo iwlist wlan0 scan 2>/dev/null | grep -E "ESSID|Quality" | sed 's/^[ \t]*//'
                fi
                read -p "Press Enter..."
                ;;
            6)
                if is_ap_mode; then
                    echo -e "${RED}Cannot connect in AP mode. Switch to Client Mode first.${NC}"
                else
                    read -p "Enter SSID: " ssid
                    if [ -n "$ssid" ]; then
                        sudo nmcli --ask device wifi connect "$ssid"
                        sleep 2
                        if iwgetid -r | grep -q "$ssid"; then
                            echo -e "${GREEN}✓ Connected${NC}"
                        else
                            echo -e "${RED}✗ Connection failed${NC}"
                        fi
                    fi
                fi
                read -p "Press Enter..."
                ;;
            7)
                echo -e "${YELLOW}Turning Wi-Fi OFF...${NC}"
                sudo systemctl stop wpa_supplicant hostapd dnsmasq 2>/dev/null || true
                sudo rfkill block wifi
                sudo ip link set wlan0 down
                echo -e "${GREEN}✓ Wi-Fi OFF${NC}"
                read -p "Press Enter..."
                ;;
            8)
                if is_ap_mode; then
                    echo -e "Mode: ACCESS POINT"
                    echo -e "AP IP: $(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)"
                    echo -e "SSID: $(sudo grep "^ssid" /etc/hostapd/hostapd.conf | cut -d= -f2)"
                elif iwgetid -r > /dev/null 2>&1; then
                    echo -e "Connected to: $(iwgetid -r)"
                    echo -e "IP Address: $(hostname -I | awk '{print $1}')"
                else
                    echo -e "Not connected"
                fi
                read -p "Press Enter..."
                ;;
            9)
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
fi
