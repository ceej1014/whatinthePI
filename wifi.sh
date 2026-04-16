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

# Helper functions - FIXED is_ap_mode
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
        AP_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1 2>/dev/null || echo "unknown")
        SSID=$(nmcli -t -f 802-11-wireless.ssid con show --active 2>/dev/null | head -1)
        echo -e "  AP SSID:     ${GREEN}${SSID:-unknown}${NC}"
        echo -e "  AP IP:       ${GREEN}${AP_IP:-unknown}${NC}"
    else
        echo -e "  AP Mode:     ${YELLOW}INACTIVE${NC}"
        # Check client connection using nmcli instead of iwgetid
        CLIENT_SSID=$(nmcli -t -f NAME,DEVICE,TYPE con show --active 2>/dev/null | grep ":wlan0:802-11-wireless" | cut -d: -f1)
        if [ -n "$CLIENT_SSID" ]; then
            echo -e "  Client Mode: ${GREEN}CONNECTED${NC}"
            echo -e "  Connected to: ${GREEN}$CLIENT_SSID${NC}"
            CLIENT_IP=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "none")
            echo -e "  Wi-Fi IP:     ${GREEN}$CLIENT_IP${NC}"
        else
            echo -e "  Client Mode: ${YELLOW}NOT connected to any network${NC}"
        fi
    fi
    # Ethernet IP
    if ip link show eth0 2>/dev/null | grep -q "state UP"; then
        ETH_IP=$(ip addr show eth0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
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
        # Turn off AP if active
        if is_ap_mode; then
            HOTSPOT=$(get_hotspot_name)
            [ -n "$HOTSPOT" ] && sudo nmcli connection down "$HOTSPOT" 2>/dev/null
        fi
        sudo nmcli radio wifi on
        sudo ip link set wlan0 up 2>/dev/null
        echo -e "${GREEN}✓ Client mode enabled${NC}"
        ;;
    off)
        echo -e "${YELLOW}Turning Wi-Fi OFF...${NC}"
        if is_ap_mode; then
            HOTSPOT=$(get_hotspot_name)
            [ -n "$HOTSPOT" ] && sudo nmcli connection down "$HOTSPOT" 2>/dev/null
        fi
        sudo nmcli radio wifi off
        sudo ip link set wlan0 down 2>/dev/null
        echo -e "${GREEN}✓ Wi-Fi OFF${NC}"
        ;;
    ap)
        echo -e "${YELLOW}Switching to AP Mode...${NC}"
        HOTSPOT=$(get_hotspot_name)
        if [ -z "$HOTSPOT" ] || ! nmcli con show "$HOTSPOT" &>/dev/null; then
            echo -e "${RED}Hotspot not configured. Run 'wifi ap-setup' first.${NC}"
            exit 1
        fi
        # FIXED: Don't turn off Wi-Fi - just disconnect any client connection
        sudo nmcli device disconnect wlan0 2>/dev/null
        sudo nmcli connection down "$HOTSPOT" 2>/dev/null
        # Delete and recreate to ensure clean state
        sudo nmcli connection delete "$HOTSPOT" 2>/dev/null
        # Recreate hotspot with correct settings
        HOTSPOT_PASS=$(sudo nmcli -s -t connection show "$HOTSPOT" 2>/dev/null | grep wifi-sec.psk | cut -d: -f2)
        sudo nmcli connection add type wifi ifname wlan0 con-name "$HOTSPOT" autoconnect no ssid "$HOTSPOT" mode ap ipv4.method shared wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$HOTSPOT_PASS"
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
        # Delete any existing profile with the same name
        sudo nmcli connection delete "$ssid" 2>/dev/null
        # Create hotspot with explicit interface binding
        sudo nmcli connection add type wifi ifname wlan0 con-name "$ssid" autoconnect no ssid "$ssid" mode ap ipv4.method shared wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$pass"
        sudo nmcli connection modify "$ssid" connection.interface-name wlan0
        # Save the SSID for future use
        save_hotspot_name "$ssid"
        echo -e "${GREEN}✓ Hotspot configured. Start it with 'wifi ap'${NC}"
        ;;
    ap-off)
        echo -e "${YELLOW}Turning OFF AP Mode...${NC}"
        HOTSPOT=$(get_hotspot_name)
        [ -n "$HOTSPOT" ] && sudo nmcli connection down "$HOTSPOT" 2>/dev/null
        sudo nmcli radio wifi on
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
        sudo nmcli device wifi rescan
        sleep 2
        nmcli -f SSID,SIGNAL,SECURITY device wifi list
        ;;
    connect)
        if is_ap_mode; then
            echo -e "${RED}Cannot connect in AP mode. Run 'wifi ap-off' first.${NC}"
            exit 1
        fi
        echo -e "${YELLOW}Available networks:${NC}"
        nmcli -f SSID device wifi list | tail -n +2 | sort -u
        echo ""
        read -p "Enter SSID: " ssid
        if [ -z "$ssid" ]; then
            echo -e "${RED}No SSID entered.${NC}"
            exit 1
        fi
        read -s -p "Enter password (press Enter for open network): " pass
        echo ""

        # Delete any existing connection with the same SSID to avoid conflicts
        sudo nmcli connection delete "$ssid" 2>/dev/null

        if [ -z "$pass" ]; then
            echo -e "${YELLOW}Connecting to open network: $ssid${NC}"
            sudo nmcli device wifi connect "$ssid"
        else
            echo -e "${YELLOW}Connecting to secured network: $ssid${NC}"
            sudo nmcli device wifi connect "$ssid" password "$pass"
        fi

        sleep 3
        if nmcli -t -f NAME con show --active | grep -q "$ssid"; then
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
                sudo ip link set wlan0 up 2>/dev/null
                echo -e "${GREEN}✓ Client mode enabled${NC}"
                read -p "Press Enter..."
                ;;
            2)
                echo -e "${YELLOW}Switching to AP Mode...${NC}"
                HOTSPOT=$(get_hotspot_name)
                if [ -z "$HOTSPOT" ] || ! nmcli con show "$HOTSPOT" &>/dev/null; then
                    echo -e "${RED}Hotspot not configured. Please run option 3 first.${NC}"
                else
                    # FIXED: Don't turn off Wi-Fi - just disconnect
                    sudo nmcli device disconnect wlan0 2>/dev/null
                    sudo nmcli connection down "$HOTSPOT" 2>/dev/null
                    # Get the password from the saved profile
                    HOTSPOT_PASS=$(sudo nmcli -s -t connection show "$HOTSPOT" 2>/dev/null | grep wifi-sec.psk | cut -d: -f2)
                    # Delete old and recreate fresh
                    sudo nmcli connection delete "$HOTSPOT" 2>/dev/null
                    sudo nmcli connection add type wifi ifname wlan0 con-name "$HOTSPOT" autoconnect no ssid "$HOTSPOT" mode ap ipv4.method shared wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$HOTSPOT_PASS"
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
                sudo nmcli connection add type wifi ifname wlan0 con-name "$ssid" autoconnect no ssid "$ssid" mode ap ipv4.method shared wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$pass"
                sudo nmcli connection modify "$ssid" connection.interface-name wlan0
                save_hotspot_name "$ssid"
                echo -e "${GREEN}✓ Hotspot configured. Start it with option 2.${NC}"
                read -p "Press Enter..."
                ;;
            4)
                echo -e "${YELLOW}Turning OFF AP Mode...${NC}"
                HOTSPOT=$(get_hotspot_name)
                [ -n "$HOTSPOT" ] && sudo nmcli connection down "$HOTSPOT" 2>/dev/null
                sudo nmcli radio wifi on
                echo -e "${GREEN}✓ AP mode disabled, client mode restored${NC}"
                read -p "Press Enter..."
                ;;
            5)
                if is_ap_mode; then
                    echo -e "${RED}Cannot scan in AP mode. Switch to Client Mode first.${NC}"
                else
                    echo -e "${YELLOW}Scanning...${NC}"
                    sudo nmcli device wifi rescan
                    sleep 2
                    nmcli -f SSID,SIGNAL,SECURITY device wifi list
                fi
                read -p "Press Enter..."
                ;;
            6)
                if is_ap_mode; then
                    echo -e "${RED}Cannot connect in AP mode. Switch to Client Mode first.${NC}"
                else
                    echo -e "${YELLOW}Available networks:${NC}"
                    nmcli -f SSID device wifi list | tail -n +2 | sort -u
                    echo ""
                    read -p "Enter SSID: " ssid
                    if [ -z "$ssid" ]; then
                        echo -e "${RED}No SSID entered.${NC}"
                    else
                        read -s -p "Enter password (press Enter for open network): " pass
                        echo ""
                        sudo nmcli connection delete "$ssid" 2>/dev/null
                        if [ -z "$pass" ]; then
                            sudo nmcli device wifi connect "$ssid"
                        else
                            sudo nmcli device wifi connect "$ssid" password "$pass"
                        fi
                        sleep 2
                        if nmcli -t -f NAME con show --active | grep -q "$ssid"; then
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
                sudo ip link set wlan0 down 2>/dev/null
                echo -e "${GREEN}✓ Wi-Fi OFF${NC}"
                read -p "Press Enter..."
                ;;
            8)
                if is_ap_mode; then
                    echo -e "Mode: ACCESS POINT"
                    SSID=$(nmcli -t -f 802-11-wireless.ssid con show --active 2>/dev/null | head -1)
                    IP=$(ip addr show wlan0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
                    echo -e "  SSID: $SSID"
                    echo -e "  IP:   $IP"
                else
                    CLIENT_SSID=$(nmcli -t -f NAME con show --active 2>/dev/null | grep -v "Hotspot" | head -1)
                    if [ -n "$CLIENT_SSID" ]; then
                        echo -e "Connected to: $CLIENT_SSID"
                        IP=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "none")
                        echo -e "IP Address: $IP"
                    else
                        echo -e "Not connected"
                    fi
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
