#!/bin/bash
# Unified Wi-Fi Manager – Command-line + Interactive menu
# Uses NetworkManager for both client and AP mode

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration file for hotspot SSID
CONFIG_DIR="/etc/whatinthepi"
HOTSPOT_CONF="$CONFIG_DIR/hotspot.conf"

# Ensure config directory exists
sudo mkdir -p "$CONFIG_DIR"
sudo chmod 755 "$CONFIG_DIR"

# Function to read saved hotspot SSID
get_hotspot_name() {
    if [ -f "$HOTSPOT_CONF" ]; then
        cat "$HOTSPOT_CONF"
    else
        echo ""
    fi
}

# Function to save hotspot SSID
save_hotspot_name() {
    echo "$1" | sudo tee "$HOTSPOT_CONF" > /dev/null
}

# Helper functions
is_ap_mode() {
    nmcli -t -f NAME,DEVICE,TYPE con show --active 2>/dev/null | grep -q ":wlan0:802-11-wireless" && \
    nmcli -t -f 802-11-wireless.mode con show --active 2>/dev/null | grep -q "ap"
}

show_status() {
    # Wi-Fi radio state
    if nmcli radio wifi | grep -q "enabled"; then
        echo -e "  Wi-Fi Radio: ${GREEN}ON${NC}"
    else
        echo -e "  Wi-Fi Radio: ${RED}OFF${NC}"
    fi

    if is_ap_mode; then
        echo -e "  AP Mode:     ${GREEN}ACTIVE${NC}"
        AP_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
        SSID=$(nmcli -t -f 802-11-wireless.ssid con show --active 2>/dev/null | head -1)
        echo -e "  AP SSID:     ${GREEN}${SSID:-unknown}${NC}"
        echo -e "  AP IP:       ${GREEN}${AP_IP:-unknown}${NC}"
    else
        echo -e "  AP Mode:     ${YELLOW}INACTIVE${NC}"
        if iwgetid -r > /dev/null 2>&1; then
            echo -e "  Client Mode: ${GREEN}CONNECTED${NC}"
            echo -e "  Connected to: ${GREEN}$(iwgetid -r)${NC}"
            echo -e "  Wi-Fi IP:     ${GREEN}$(hostname -I | awk '{print $1}')${NC}"
        else
            echo -e "  Client Mode: ${YELLOW}NOT connected to any network${NC}"
        fi
    fi
    # Ethernet IP
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
            HOTSPOT=$(get_hotspot_name)
            [ -n "$HOTSPOT" ] && sudo nmcli connection down "$HOTSPOT" 2>/dev/null
        fi
        sudo nmcli radio wifi on
        sudo systemctl unmask wpa_supplicant 2>/dev/null || true
        sudo systemctl enable wpa_supplicant
        sudo systemctl restart wpa_supplicant
        sudo ip link set wlan0 up
        echo -e "${GREEN}✓ Client mode enabled${NC}"
        ;;
    off)
        echo -e "${YELLOW}Turning Wi-Fi OFF...${NC}"
        if is_ap_mode; then
            HOTSPOT=$(get_hotspot_name)
            [ -n "$HOTSPOT" ] && sudo nmcli connection down "$HOTSPOT" 2>/dev/null
        fi
        sudo nmcli radio wifi off
        sudo ip link set wlan0 down
        echo -e "${GREEN}✓ Wi-Fi OFF${NC}"
        ;;
    ap)
        echo -e "${YELLOW}Switching to AP Mode...${NC}"
        HOTSPOT=$(get_hotspot_name)
        if [ -z "$HOTSPOT" ] || ! nmcli con show "$HOTSPOT" &>/dev/null; then
            echo -e "${RED}Hotspot not configured. Run 'wifi ap-setup' first.${NC}"
            exit 1
        fi
        sudo nmcli radio wifi off
        sudo ip link set wlan0 down
        sudo nmcli connection modify "$HOTSPOT" connection.interface-name wlan0
        sudo nmcli connection up "$HOTSPOT"
        echo -e "${GREEN}✓ AP mode enabled${NC}"
        ;;
    ap-setup)
        echo -e "${YELLOW}Configuring Access Point hotspot...${NC}"
        read -p "Enter SSID for hotspot [RPi_Network]: " ssid
        ssid=${ssid:-RPi_Network}
        read -s -p "Enter password (min 8 chars) [raspberry123]: " pass
        echo ""
        pass=${pass:-raspberry123}
        if [ ${#pass} -lt 8 ]; then
            echo -e "${RED}Password must be at least 8 characters. Using default.${NC}"
            pass="raspberry123"
        fi
        sudo nmcli connection delete "$ssid" 2>/dev/null
        sudo nmcli connection add type wifi ifname wlan0 con-name "$ssid" autoconnect yes ssid "$ssid" mode ap ipv4.method shared wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$pass"
        sudo nmcli connection modify "$ssid" connection.interface-name wlan0
        sudo nmcli connection modify "$ssid" connection.autoconnect-priority 100
        save_hotspot_name "$ssid"
        echo -e "${GREEN}✓ Hotspot configured. Start it with 'wifi ap'${NC}"
        ;;
    ap-off)
        echo -e "${YELLOW}Turning OFF AP Mode...${NC}"
        HOTSPOT=$(get_hotspot_name)
        [ -n "$HOTSPOT" ] && sudo nmcli connection down "$HOTSPOT" 2>/dev/null
        sudo nmcli radio wifi on
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
        # Delete any existing connection profile for this SSID
        sudo nmcli connection delete "$ssid" 2>/dev/null
        # Use the interactive connection method (handles all security types automatically)
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
        echo "  wifi ap        - Switch to AP mode (hotspot)"
        echo "  wifi ap-setup  - Configure hotspot (SSID, password)"
        echo "  wifi ap-off    - Turn off AP mode, back to client"
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
        echo "3)  Configure Hotspot (SSID, password)"
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
                HOTSPOT=$(get_hotspot_name)
                if is_ap_mode; then
                    [ -n "$HOTSPOT" ] && sudo nmcli connection down "$HOTSPOT" 2>/dev/null
                fi
                sudo nmcli radio wifi on
                sudo systemctl unmask wpa_supplicant 2>/dev/null || true
                sudo systemctl enable wpa_supplicant
                sudo systemctl restart wpa_supplicant
                sudo ip link set wlan0 up
                echo -e "${GREEN}✓ Client mode enabled${NC}"
                read -p "Press Enter..."
                ;;
            2)
                echo -e "${YELLOW}Switching to AP Mode...${NC}"
                HOTSPOT=$(get_hotspot_name)
                if [ -z "$HOTSPOT" ] || ! nmcli con show "$HOTSPOT" &>/dev/null; then
                    echo -e "${RED}Hotspot not configured. Please run option 3 first.${NC}"
                else
                    sudo nmcli radio wifi off
                    sudo ip link set wlan0 down
                    sudo nmcli connection modify "$HOTSPOT" connection.interface-name wlan0
                    sudo nmcli connection up "$HOTSPOT"
                    echo -e "${GREEN}✓ AP mode enabled${NC}"
                fi
                read -p "Press Enter..."
                ;;
            3)
                echo -e "${YELLOW}Configuring Hotspot...${NC}"
                read -p "Enter SSID for hotspot [RPi_Network]: " ssid
                ssid=${ssid:-RPi_Network}
                read -s -p "Enter password (min 8 chars) [raspberry123]: " pass
                echo ""
                pass=${pass:-raspberry123}
                if [ ${#pass} -lt 8 ]; then
                    echo -e "${RED}Password must be at least 8 characters. Using default.${NC}"
                    pass="raspberry123"
                fi
                sudo nmcli connection delete "$ssid" 2>/dev/null
                sudo nmcli connection add type wifi ifname wlan0 con-name "$ssid" autoconnect yes ssid "$ssid" mode ap ipv4.method shared wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$pass"
                sudo nmcli connection modify "$ssid" connection.interface-name wlan0
                sudo nmcli connection modify "$ssid" connection.autoconnect-priority 100
                save_hotspot_name "$ssid"
                echo -e "${GREEN}✓ Hotspot configured. Start it with option 2.${NC}"
                read -p "Press Enter..."
                ;;
            4)
                echo -e "${YELLOW}Turning OFF AP Mode...${NC}"
                HOTSPOT=$(get_hotspot_name)
                [ -n "$HOTSPOT" ] && sudo nmcli connection down "$HOTSPOT" 2>/dev/null
                sudo nmcli radio wifi on
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
                    echo -e "${YELLOW}Available networks:${NC}"
                    sudo iwlist wlan0 scan 2>/dev/null | grep "ESSID" | sort -u | sed 's/^[ \t]*ESSID://g' | tr -d '"'
                    echo ""
                    read -p "Enter SSID: " ssid
                    if [ -z "$ssid" ]; then
                        echo -e "${RED}No SSID entered.${NC}"
                    else
                        sudo nmcli connection delete "$ssid" 2>/dev/null
                        echo -e "${YELLOW}Attempting to connect to $ssid...${NC}"
                        sudo nmcli --ask device wifi connect "$ssid"
                        sleep 2
                        if iwgetid -r | grep -q "$ssid"; then
                            echo -e "${GREEN}✓ Connected${NC}"
                        else
                            echo -e "${RED}✗ Connection failed. Check SSID/password.${NC}"
                        fi
                    fi
                fi
                read -p "Press Enter..."
                ;;
            7)
                echo -e "${YELLOW}Turning Wi-Fi OFF...${NC}"
                HOTSPOT=$(get_hotspot_name)
                if is_ap_mode; then
                    [ -n "$HOTSPOT" ] && sudo nmcli connection down "$HOTSPOT" 2>/dev/null
                fi
                sudo nmcli radio wifi off
                sudo ip link set wlan0 down
                echo -e "${GREEN}✓ Wi-Fi OFF${NC}"
                read -p "Press Enter..."
                ;;
            8)
                if is_ap_mode; then
                    echo -e "Mode: ACCESS POINT"
                    SSID=$(nmcli -t -f 802-11-wireless.ssid con show --active 2>/dev/null | head -1)
                    IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
                    echo -e "  SSID: $SSID"
                    echo -e "  IP:   $IP"
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
