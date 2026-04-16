#!/bin/bash
# Unified Wi-Fi Manager – Command-line + Interactive menu
# Fixed: no 'local' outside functions, includes 'ap-setup'

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

CONFIG_DIR="/etc/whatinthepi"
PROFILES_DIR="$CONFIG_DIR/profiles"
CURRENT_PROFILE_FILE="$CONFIG_DIR/current_profile"

sudo mkdir -p "$PROFILES_DIR"
sudo chmod 755 "$CONFIG_DIR" "$PROFILES_DIR"

# -------------------------------------------------------------------
# Profile management (functions – 'local' is allowed here)
# -------------------------------------------------------------------
get_current_profile() {
    if [ -f "$CURRENT_PROFILE_FILE" ]; then
        cat "$CURRENT_PROFILE_FILE"
    else
        echo ""
    fi
}

save_current_profile() {
    echo "$1" | sudo tee "$CURRENT_PROFILE_FILE" > /dev/null
}

list_profiles() {
    echo -e "${BLUE}Saved Hotspot Profiles:${NC}"
    if [ -d "$PROFILES_DIR" ] && [ "$(ls -A $PROFILES_DIR 2>/dev/null)" ]; then
        for profile in "$PROFILES_DIR"/*.conf; do
            if [ -f "$profile" ]; then
                name=$(basename "$profile" .conf)
                ssid=$(grep "^SSID=" "$profile" 2>/dev/null | cut -d= -f2)
                echo -e "  ${GREEN}$name${NC} - SSID: ${YELLOW}$ssid${NC}"
            fi
        done
    else
        echo -e "  ${YELLOW}No profiles saved yet${NC}"
    fi
}

save_profile() {
    local name="$1"
    local ssid="$2"
    local pass="$3"
    local date_str=$(date)
    sudo tee "$PROFILES_DIR/${name}.conf" > /dev/null << EOF
NAME=$name
SSID=$ssid
PASSWORD=$pass
CREATED=$date_str
EOF
}

load_profile() {
    local name="$1"
    local profile_file="$PROFILES_DIR/${name}.conf"
    
    if [ ! -f "$profile_file" ]; then
        echo -e "${RED}Profile '$name' not found!${NC}"
        return 1
    fi
    
    local ssid=$(grep "^SSID=" "$profile_file" | cut -d= -f2)
    local pass=$(grep "^PASSWORD=" "$profile_file" | cut -d= -f2)
    
    if [ -z "$ssid" ]; then
        echo -e "${RED}Invalid profile: missing SSID${NC}"
        return 1
    fi
    
    sudo nmcli connection delete "$name" 2>/dev/null
    sudo nmcli connection add type wifi ifname wlan0 con-name "$name" autoconnect yes ssid "$ssid" mode ap ipv4.method shared wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$pass"
    sudo nmcli connection modify "$name" connection.interface-name wlan0
    sudo nmcli connection modify "$name" 802-11-wireless.mode ap
    sudo nmcli connection modify "$name" connection.autoconnect-priority 100
    
    save_current_profile "$name"
    echo -e "${GREEN}✓ Loaded profile: $name (SSID: $ssid)${NC}"
    return 0
}

# -------------------------------------------------------------------
# State detection
# -------------------------------------------------------------------
is_ap_mode() {
    local cur=$(get_current_profile)
    [ -n "$cur" ] && nmcli -t -f NAME con show --active 2>/dev/null | grep -q "^$cur$"
}

is_client_connected() {
    iwgetid -r > /dev/null 2>&1
}

# -------------------------------------------------------------------
# Hardware/radio helpers
# -------------------------------------------------------------------
reset_wlan0() {
    echo -e "${YELLOW}Resetting wlan0 interface...${NC}"
    sudo ip link set wlan0 down
    sudo ip addr flush dev wlan0
    sudo rfkill unblock wifi
    sudo nmcli radio wifi on
    sleep 1
    sudo ip link set wlan0 up
    sleep 1
}

ensure_radio_on() {
    if ! nmcli radio wifi | grep -q "enabled"; then
        echo -e "${YELLOW}Wi‑Fi radio is off, turning it on...${NC}"
        sudo nmcli radio wifi on
        sleep 1
    fi
    if rfkill list | grep -q "Soft blocked: yes"; then
        echo -e "${YELLOW}RF‑kill detected, unblocking...${NC}"
        sudo rfkill unblock wifi
        sleep 1
    fi
}

# -------------------------------------------------------------------
# Mode switching
# -------------------------------------------------------------------
switch_to_client() {
    echo -e "${YELLOW}Switching to Client Mode...${NC}"
    local cur=$(get_current_profile)
    [ -n "$cur" ] && sudo nmcli connection down "$cur" 2>/dev/null
    reset_wlan0
    ensure_radio_on
    sudo systemctl unmask wpa_supplicant 2>/dev/null || true
    sudo systemctl enable wpa_supplicant
    sudo systemctl restart wpa_supplicant
    sudo nmcli device set wlan0 managed yes
    echo -e "${GREEN}✓ Client mode ready (radio ON)${NC}"
}

switch_to_ap() {
    local cur=$(get_current_profile)
    if [ -z "$cur" ]; then
        echo -e "${RED}No hotspot profile selected. Run 'wifi ap-setup' first.${NC}"
        return 1
    fi
    echo -e "${YELLOW}Switching to AP Mode...${NC}"
    sudo systemctl stop wpa_supplicant 2>/dev/null
    sudo pkill -f wpa_supplicant 2>/dev/null
    reset_wlan0
    ensure_radio_on
    load_profile "$cur"
    if sudo nmcli connection up "$cur" 2>/dev/null; then
        echo -e "${GREEN}✓ AP mode enabled with profile: $cur${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to start AP mode${NC}"
        return 1
    fi
}

# -------------------------------------------------------------------
# Status display
# -------------------------------------------------------------------
show_status() {
    if nmcli radio wifi | grep -q "enabled"; then
        echo -e "  Wi-Fi Radio: ${GREEN}ON${NC}"
    else
        echo -e "  Wi-Fi Radio: ${RED}OFF${NC}"
    fi

    if is_ap_mode; then
        echo -e "  AP Mode:     ${GREEN}ACTIVE${NC}"
        local cur=$(get_current_profile)
        if [ -n "$cur" ] && [ -f "$PROFILES_DIR/${cur}.conf" ]; then
            local ssid=$(grep "^SSID=" "$PROFILES_DIR/${cur}.conf" | cut -d= -f2)
            echo -e "  AP SSID:     ${GREEN}$ssid${NC}"
        fi
        local ap_ip=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
        echo -e "  AP IP:       ${GREEN}${ap_ip:-unknown}${NC}"
    elif is_client_connected; then
        echo -e "  AP Mode:     ${YELLOW}INACTIVE${NC}"
        echo -e "  Client Mode: ${GREEN}CONNECTED${NC}"
        echo -e "  Connected to: ${GREEN}$(iwgetid -r)${NC}"
        echo -e "  Wi-Fi IP:     ${GREEN}$(hostname -I | awk '{print $1}')${NC}"
    else
        echo -e "  AP Mode:     ${YELLOW}INACTIVE${NC}"
        echo -e "  Client Mode: ${YELLOW}NOT connected to any network${NC}"
    fi
    
    if ip link show eth0 | grep -q "state UP"; then
        local eth_ip=$(ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
        echo -e "  Ethernet IP:  ${GREEN}$eth_ip${NC}"
    else
        echo -e "  Ethernet:     ${RED}Not connected${NC}"
    fi
}

# -------------------------------------------------------------------
# Command-line actions (no 'local' here)
# -------------------------------------------------------------------
case "$1" in
    on)
        switch_to_client
        ;;
    off)
        echo -e "${YELLOW}Turning Wi-Fi OFF...${NC}"
        cur=$(get_current_profile)
        [ -n "$cur" ] && sudo nmcli connection down "$cur" 2>/dev/null
        sudo nmcli radio wifi off
        sudo ip link set wlan0 down
        echo -e "${GREEN}✓ Wi-Fi OFF${NC}"
        ;;
    ap)
        switch_to_ap
        ;;
    ap-setup)
        echo -e "${YELLOW}Hotspot Setup (one‑time configuration)${NC}"
        echo ""
        read -p "Enter profile name (no spaces, e.g., myhotspot): " prof_name
        if [ -z "$prof_name" ]; then
            echo -e "${RED}Profile name required${NC}"
            exit 1
        fi
        read -p "Enter Wi-Fi SSID (network name): " ssid
        if [ -z "$ssid" ]; then
            echo -e "${RED}SSID required${NC}"
            exit 1
        fi
        read -s -p "Enter password (min 8 chars, leave blank for open network): " pass
        echo ""
        if [ -n "$pass" ] && [ ${#pass} -lt 8 ]; then
            echo -e "${RED}Password must be at least 8 characters. Using default 'raspberry123'.${NC}"
            pass="raspberry123"
        fi
        save_profile "$prof_name" "$ssid" "$pass"
        save_current_profile "$prof_name"
        echo -e "${GREEN}✓ Hotspot profile '$prof_name' created and selected.${NC}"
        echo -e "${YELLOW}To start the hotspot now, run: wifi ap${NC}"
        ;;
    ap-create)
        echo -e "${YELLOW}Create new hotspot profile...${NC}"
        read -p "Enter profile name (no spaces): " prof_name
        [ -z "$prof_name" ] && { echo -e "${RED}Profile name required${NC}"; exit 1; }
        read -p "Enter SSID: " ssid
        [ -z "$ssid" ] && { echo -e "${RED}SSID required${NC}"; exit 1; }
        read -s -p "Enter password (min 8 chars): " pass
        echo ""
        if [ ${#pass} -lt 8 ]; then
            echo -e "${RED}Password must be at least 8 characters${NC}"
            exit 1
        fi
        save_profile "$prof_name" "$ssid" "$pass"
        echo -e "${GREEN}✓ Profile '$prof_name' created${NC}"
        ;;
    ap-list)
        list_profiles
        ;;
    ap-use)
        [ -z "$2" ] && { echo -e "${RED}Usage: wifi ap-use <profile_name>${NC}"; exit 1; }
        if [ ! -f "$PROFILES_DIR/${2}.conf" ]; then
            echo -e "${RED}Profile '$2' not found${NC}"
            exit 1
        fi
        save_current_profile "$2"
        echo -e "${GREEN}✓ Now using profile: $2${NC}"
        echo -e "${YELLOW}Run 'wifi ap' to start it${NC}"
        ;;
    ap-delete)
        [ -z "$2" ] && { echo -e "${RED}Usage: wifi ap-delete <profile_name>${NC}"; exit 1; }
        cur=$(get_current_profile)
        [ "$2" = "$cur" ] && save_current_profile ""
        sudo rm -f "$PROFILES_DIR/${2}.conf"
        sudo nmcli connection delete "$2" 2>/dev/null
        echo -e "${GREEN}✓ Profile '$2' deleted${NC}"
        ;;
    ap-current)
        cur=$(get_current_profile)
        if [ -n "$cur" ] && [ -f "$PROFILES_DIR/${cur}.conf" ]; then
            ssid=$(grep "^SSID=" "$PROFILES_DIR/${cur}.conf" | cut -d= -f2)
            echo -e "Current profile: ${GREEN}$cur${NC}"
            echo -e "  SSID: ${YELLOW}$ssid${NC}"
        else
            echo -e "${YELLOW}No profile selected${NC}"
        fi
        ;;
    ap-off)
        switch_to_client
        ;;
    status)
        show_status
        ;;
    scan)
        if is_ap_mode; then
            echo -e "${RED}Cannot scan in AP mode. Run 'wifi ap-off' first.${NC}"
            exit 1
        fi
        reset_wlan0
        ensure_radio_on
        echo -e "${YELLOW}Scanning for networks...${NC}"
        sudo iwlist wlan0 scan 2>/dev/null | grep -E "ESSID|Quality|Encryption" | sed 's/^[ \t]*//'
        ;;
    connect)
        if is_ap_mode; then
            echo -e "${RED}Cannot connect in AP mode. Run 'wifi ap-off' first.${NC}"
            exit 1
        fi
        reset_wlan0
        ensure_radio_on
        echo -e "${YELLOW}Available networks:${NC}"
        sudo iwlist wlan0 scan 2>/dev/null | grep "ESSID" | sort -u | sed 's/^[ \t]*ESSID://g' | tr -d '"'
        echo ""
        read -p "Enter SSID: " ssid
        [ -z "$ssid" ] && { echo -e "${RED}No SSID entered.${NC}"; exit 1; }
        sudo nmcli connection delete "$ssid" 2>/dev/null
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
        cat << EOF
${BLUE}Unified Wi-Fi Manager Commands:${NC}

${YELLOW}Client Mode:${NC}
  wifi on        - Switch to Client mode
  wifi off       - Turn Wi-Fi OFF completely
  wifi scan      - Scan for networks
  wifi connect   - Connect to a network

${YELLOW}AP Mode (Hotspot):${NC}
  wifi ap-setup  - One‑time configuration (SSID, password)
  wifi ap        - Start AP mode with current profile
  wifi ap-off    - Turn off AP mode (back to client)
  wifi ap-list   - List all saved profiles
  wifi ap-use    - Select a profile to use
  wifi ap-delete - Delete a profile
  wifi ap-current- Show current profile

${YELLOW}General:${NC}
  wifi status    - Show current status
  wifi help      - Show this help
EOF
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

# -------------------------------------------------------------------
# Interactive menu (no 'local' anywhere here)
# -------------------------------------------------------------------
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
        echo "2)  Switch to AP Mode (start hotspot)"
        echo "3)  Configure Hotspot (ap-setup)"
        echo "4)  List saved profiles"
        echo "5)  Select/Use a profile"
        echo "6)  Delete a profile"
        echo "7)  Show current profile"
        echo "8)  Turn OFF AP Mode (back to client)"
        echo "9)  Scan for networks"
        echo "10) Connect to a network"
        echo "11) Turn Wi-Fi OFF"
        echo "12) Show connection details"
        echo "13) Exit"
        echo -e "${GREEN}========================================${NC}"
        read -p "Enter your choice [1-13]: " choice

        case $choice in
            1) switch_to_client; read -p "Press Enter..." ;;
            2) switch_to_ap; read -p "Press Enter..." ;;
            3)
                echo -e "${YELLOW}Hotspot Setup...${NC}"
                read -p "Profile name (no spaces): " prof_name
                if [ -n "$prof_name" ]; then
                    read -p "SSID: " ssid
                    if [ -n "$ssid" ]; then
                        read -s -p "Password (min 8 chars, blank wont work): " pass
                        echo ""
                        if [ -z "$pass" ]; then
                            pass=""
                        elif [ ${#pass} -lt 8 ]; then
                            echo -e "${RED}Password too short, using default 'raspberry123'${NC}"
                            pass="raspberry123"
                        fi
                        save_profile "$prof_name" "$ssid" "$pass"
                        save_current_profile "$prof_name"
                        echo -e "${GREEN}✓ Profile '$prof_name' created and selected.${NC}"
                    else
                        echo -e "${RED}SSID required${NC}"
                    fi
                else
                    echo -e "${RED}Profile name required${NC}"
                fi
                read -p "Press Enter..."
                ;;
            4) list_profiles; read -p "Press Enter..." ;;
            5)
                list_profiles
                echo ""
                read -p "Enter profile name to use: " prof_name
                if [ -n "$prof_name" ] && [ -f "$PROFILES_DIR/${prof_name}.conf" ]; then
                    save_current_profile "$prof_name"
                    echo -e "${GREEN}✓ Now using profile: $prof_name${NC}"
                else
                    echo -e "${RED}Profile not found${NC}"
                fi
                read -p "Press Enter..."
                ;;
            6)
                list_profiles
                echo ""
                read -p "Enter profile name to delete: " prof_name
                if [ -n "$prof_name" ]; then
                    cur=$(get_current_profile)
                    [ "$prof_name" = "$cur" ] && save_current_profile ""
                    sudo rm -f "$PROFILES_DIR/${prof_name}.conf"
                    sudo nmcli connection delete "$prof_name" 2>/dev/null
                    echo -e "${GREEN}✓ Profile deleted${NC}"
                fi
                read -p "Press Enter..."
                ;;
            7)
                cur=$(get_current_profile)
                if [ -n "$cur" ] && [ -f "$PROFILES_DIR/${cur}.conf" ]; then
                    ssid=$(grep "^SSID=" "$PROFILES_DIR/${cur}.conf" | cut -d= -f2)
                    echo -e "Current profile: ${GREEN}$cur${NC}"
                    echo -e "  SSID: ${YELLOW}$ssid${NC}"
                else
                    echo -e "${YELLOW}No profile selected${NC}"
                fi
                read -p "Press Enter..."
                ;;
            8) switch_to_client; read -p "Press Enter..." ;;
            9)
                if is_ap_mode; then
                    echo -e "${RED}Cannot scan in AP mode${NC}"
                else
                    reset_wlan0
                    ensure_radio_on
                    echo -e "${YELLOW}Scanning...${NC}"
                    sudo iwlist wlan0 scan 2>/dev/null | grep -E "ESSID|Quality" | sed 's/^[ \t]*//'
                fi
                read -p "Press Enter..."
                ;;
            10)
                if is_ap_mode; then
                    echo -e "${RED}Cannot connect in AP mode${NC}"
                else
                    reset_wlan0
                    ensure_radio_on
                    echo -e "${YELLOW}Available networks:${NC}"
                    sudo iwlist wlan0 scan 2>/dev/null | grep "ESSID" | sort -u | sed 's/^[ \t]*ESSID://g' | tr -d '"'
                    echo ""
                    read -p "Enter SSID: " ssid
                    if [ -n "$ssid" ]; then
                        sudo nmcli connection delete "$ssid" 2>/dev/null
                        sudo nmcli --ask device wifi connect "$ssid"
                        sleep 2
                        if iwgetid -r | grep -q "$ssid"; then
                            echo -e "${GREEN}✓ Connected${NC}"
                        else
                            echo -e "${RED}✗ Failed${NC}"
                        fi
                    fi
                fi
                read -p "Press Enter..."
                ;;
            11)
                echo -e "${YELLOW}Turning Wi-Fi OFF...${NC}"
                cur=$(get_current_profile)
                [ -n "$cur" ] && sudo nmcli connection down "$cur" 2>/dev/null
                sudo nmcli radio wifi off
                sudo ip link set wlan0 down
                echo -e "${GREEN}✓ Wi-Fi OFF${NC}"
                read -p "Press Enter..."
                ;;
            12)
                if is_ap_mode; then
                    echo -e "Mode: ACCESS POINT"
                    cur=$(get_current_profile)
                    if [ -n "$cur" ] && [ -f "$PROFILES_DIR/${cur}.conf" ]; then
                        ssid=$(grep "^SSID=" "$PROFILES_DIR/${cur}.conf" | cut -d= -f2)
                        echo -e "  SSID: $ssid"
                    fi
                    echo -e "  IP: $(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)"
                elif is_client_connected; then
                    echo -e "Connected to: $(iwgetid -r)"
                    echo -e "IP Address: $(hostname -I | awk '{print $1}')"
                else
                    echo -e "Not connected"
                fi
                read -p "Press Enter..."
                ;;
            13)
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
    done
fi
