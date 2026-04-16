#!/bin/bash
# One-line installer for Raspberry Pi
# Usage: curl -sSL https://raw.githubusercontent.com/ceej1014/whatinthePI/main/auto_setup.sh | bash

# Make itself executable if it's not already
if [[ ! -x "$0" ]] && [[ -f "$0" ]]; then
    chmod +x "$0" 2>/dev/null || true
fi

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Detect if running interactively
if [ -t 0 ] && [ -t 1 ]; then
    INTERACTIVE=true
else
    INTERACTIVE=false
fi

clear
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Raspberry Pi Tools Installer${NC}"
echo -e "${GREEN}========================================${NC}"

# Clone the repository if not already present
if [ ! -d "whatinthePI" ]; then
    echo -e "${YELLOW}Cloning repository...${NC}"
    git clone https://github.com/ceej1014/whatinthePI.git
    cd whatinthePI
else
    cd whatinthePI
    echo -e "${YELLOW}Repository already exists, updating...${NC}"
    git pull
fi

# Make all scripts executable
for script in *.sh; do
    if [ -f "$script" ]; then
        chmod +x "$script" 2>/dev/null || true
    fi
done
chmod +x raspi-ap-setup/*.sh 2>/dev/null || true
chmod +x wifi_manager/*.sh 2>/dev/null || true

echo -e "${GREEN}✓ All scripts are executable${NC}"
sleep 1

# Function to create aliases
create_aliases() {
    echo -e "${YELLOW}Creating aliases...${NC}"
    
    sed -i '/# Raspberry Pi Tools Aliases/,/# END Raspberry Pi Tools Aliases/d' ~/.bash_aliases 2>/dev/null || true
    
    cat >> ~/.bash_aliases << 'EOF'

# Raspberry Pi Tools Aliases
alias help='~/whatinthePI/help.sh'
alias quickref='~/whatinthePI/quickref.sh'
alias status='~/whatinthePI/status.sh'
alias welcome='~/whatinthePI/welcome.sh'
alias version='~/whatinthePI/version.sh'
alias update='~/whatinthePI/update.sh'
alias changename='~/whatinthePI/changename.sh'
alias changeip='~/whatinthePI/changeip.sh'
alias uninstall='~/whatinthePI/uninstall.sh'
alias wifiman='sudo ~/whatinthePI/wifi_manager/wifi_manager.sh'
alias apsetup='sudo ~/whatinthePI/raspi-ap-setup/setup_ap.sh'
alias wifi='~/whatinthePI/wifi_helper.sh'
alias myip='hostname -I | awk "{print \$1}"'
alias netstat='sudo netstat -tulpn'
alias reboot='sudo reboot'
alias shutdown='sudo shutdown now'

# Mode switching aliases
alias client='sudo systemctl stop hostapd dnsmasq 2>/dev/null; sudo systemctl disable hostapd dnsmasq 2>/dev/null; sudo systemctl unmask wpa_supplicant; sudo systemctl enable wpa_supplicant; sudo systemctl restart wpa_supplicant; echo "✓ Client mode enabled"'
alias ap='sudo systemctl stop wpa_supplicant; sudo systemctl mask wpa_supplicant; sudo systemctl unmask hostapd; sudo systemctl enable hostapd; sudo systemctl start hostapd; sudo systemctl start dnsmasq; echo "✓ AP mode enabled"'
alias apon='ap'
alias apoff='client'

# Wi-Fi quick commands
wifion() { 
    if systemctl is-active --quiet hostapd; then
        echo "AP mode active. Switching to client mode..."
        client
    fi
    sudo rfkill unblock wifi
    sudo ip link set wlan0 up
    sudo systemctl restart wpa_supplicant
    echo "Wi-Fi ON"
}
wifioff() { sudo rfkill block wifi; echo "Wi-Fi OFF"; }
wifiscan() { 
    if systemctl is-active --quiet hostapd; then
        echo "Cannot scan in AP mode. Run 'apoff' first."
    else
        sudo iwlist wlan0 scan | grep -E "ESSID|Quality"
    fi
}
wifistatus() { 
    if systemctl is-active --quiet hostapd; then
        echo "Mode: ACCESS POINT"
        echo "AP IP: $(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)"
    elif iwgetid -r > /dev/null 2>&1; then
        echo "Connected to: $(iwgetid -r)"
        echo "IP: $(hostname -I | awk '{print $1}')"
    else
        echo "Not connected to any network"
    fi
}
# END Raspberry Pi Tools Aliases
EOF

    source ~/.bash_aliases 2>/dev/null || true
    echo -e "${GREEN}✓ Aliases created successfully!${NC}"
}

# Function to create helper scripts
create_helper_scripts() {
    if [ ! -f ~/whatinthePI/status.sh ]; then
        cat > ~/whatinthePI/status.sh << 'EOF'
#!/bin/bash
# System Status - Shows Ethernet, Wi-Fi, and AP mode correctly

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

is_ap_mode() { 
    systemctl is-active --quiet hostapd 2>/dev/null && [ -f /etc/hostapd/hostapd.conf ]
}

clear
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                 SYSTEM STATUS - RASPBERRY PI               ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# System Information
echo -e "${GREEN}📊 SYSTEM INFORMATION${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
echo -e "  Hostname:        ${YELLOW}$(hostname)${NC}"
echo -e "  Kernel:          $(uname -r)"
echo -e "  Uptime:          $(uptime -p | sed 's/up //')"
echo -e "  Load Average:    $(uptime | awk -F'load average:' '{print $2}')"
echo -e "  Users Online:    $(who | wc -l)"
echo ""

# Hardware Information
if command -v vcgencmd &> /dev/null; then
    echo -e "${GREEN}🖥️  HARDWARE INFORMATION${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
    echo -e "  Temperature:     ${YELLOW}$(vcgencmd measure_temp | cut -d= -f2)${NC}"
    echo -e "  Clock Speed:     $(vcgencmd measure_clock arm | cut -d= -f2 | awk '{printf "%.2f MHz\n", $1/1000000}')"
    echo -e "  Voltage:         $(vcgencmd measure_volts core | cut -d= -f2)"
    echo ""
fi

# Network Information
echo -e "${GREEN}🌐 NETWORK INFORMATION${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"

# Wi-Fi / AP Mode
if is_ap_mode; then
    echo -e "  Mode:            ${YELLOW}ACCESS POINT${NC}"
    AP_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    SSID=$(sudo grep "^ssid" /etc/hostapd/hostapd.conf 2>/dev/null | cut -d= -f2)
    echo -e "  AP SSID:         ${GREEN}$SSID${NC}"
    echo -e "  AP IP:           ${GREEN}$AP_IP${NC}"
elif iwgetid -r > /dev/null 2>&1; then
    echo -e "  Mode:            ${GREEN}CLIENT (connected)${NC}"
    echo -e "  Wi-Fi SSID:      ${GREEN}$(iwgetid -r)${NC}"
    echo -e "  Wi-Fi IP:        ${GREEN}$(hostname -I | awk '{print $1}')${NC}"
    echo -e "  Signal:          $(iwconfig wlan0 2>/dev/null | grep -i quality | awk '{print $2}' | cut -d= -f2)"
elif systemctl is-active --quiet wpa_supplicant; then
    echo -e "  Mode:            ${YELLOW}CLIENT (not connected)${NC}"
else
    echo -e "  Mode:            ${RED}Wi-Fi DISABLED${NC}"
fi

# Ethernet Status
if ip link show eth0 | grep -q "state UP"; then
    ETH_IP=$(ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    echo -e "  Ethernet:        ${GREEN}Connected${NC} - $ETH_IP"
else
    echo -e "  Ethernet:        ${RED}Disconnected${NC}"
fi
echo ""

# Storage Information
echo -e "${GREEN}💾 STORAGE INFORMATION${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
df -h / | awk 'NR==2 {printf "  Used: %s / %s (%s)\n", $3, $2, $5}'
echo ""

# Memory Information
echo -e "${GREEN}🧠 MEMORY INFORMATION${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
free -h | awk 'NR==2 {printf "  Used: %s / %s (%.0f%%)\n", $3, $2, ($3/$2)*100}'
echo ""

# Quick Tips
echo -e "${GREEN}💡 QUICK TIPS${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
echo -e "  • Type ${YELLOW}wifi status${NC} to check connection"
echo -e "  • Type ${YELLOW}wifi ap${NC} to turn on hotspot"
echo -e "  • Type ${YELLOW}wifi on${NC} to connect to Wi-Fi"
echo -e "  • Type ${YELLOW}help${NC} for all commands"
echo ""

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    STATUS CHECK COMPLETE                   ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
EOF
        chmod +x ~/whatinthePI/status.sh
    fi
    
    if [ ! -f ~/whatinthePI/wifi_helper.sh ]; then
        cat > ~/whatinthePI/wifi_helper.sh << 'EOF'
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
        read -s -p "Enter password (press Enter for open network): " pass
        echo ""
        # Delete any existing connection profile for this SSID to avoid conflicts
        sudo nmcli connection delete "$ssid" 2>/dev/null
        if [ -z "$pass" ]; then
            sudo nmcli connection add type wifi con-name "$ssid" ifname wlan0 ssid "$ssid"
            sudo nmcli connection up "$ssid"
        else
            sudo nmcli connection add type wifi con-name "$ssid" ifname wlan0 ssid "$ssid" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$pass"
            sudo nmcli connection up "$ssid"
        fi
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
EOF
        chmod +x ~/whatinthePI/wifi_helper.sh
    fi
}

# Function to setup welcome message
setup_welcome() {
    echo -e "${YELLOW}Setting up welcome message...${NC}"
    
    if [ ! -f ~/whatinthePI/welcome.sh ]; then
        cat > ~/whatinthePI/welcome.sh << 'EOF'
#!/bin/bash
# Welcome message with Ethernet and AP detection

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
RED='\033[0;31m'
NC='\033[0m'

is_ap_mode() { 
    systemctl is-active --quiet hostapd 2>/dev/null && [ -f /etc/hostapd/hostapd.conf ]
}

clear
echo -e "${RED}"
echo '   ██████╗  █████╗ ███████╗██████╗ ██╗'
echo '   ██╔══██╗██╔══██╗██╔════╝██╔══██╗██║'
echo '   ██████╔╝███████║███████╗██████╔╝██║'
echo '   ██╔══██╗██╔══██║╚════██║██╔═══╝ ██║'
echo '   ██║  ██║██║  ██║███████║██║     ██║'
echo '   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝'
echo -e "${NC}"
echo -e "${WHITE}   Raspberry Pi - Welcome ${USER}!${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# System info
echo -e "${GREEN}📊 System Information:${NC}"
echo -e "  Hostname:    ${YELLOW}$(hostname)${NC}"
echo -e "  Uptime:      ${YELLOW}$(uptime -p | sed 's/up //')${NC}"
echo -e "  Kernel:      ${YELLOW}$(uname -r)${NC}"
echo ""

# Temperature
if command -v vcgencmd &> /dev/null; then
    TEMP=$(vcgencmd measure_temp | cut -d= -f2)
    echo -e "${GREEN}🌡️  Temperature:${NC} ${YELLOW}$TEMP${NC}"
    echo ""
fi

# Network info
echo -e "${GREEN}🌐 Network Information:${NC}"
if is_ap_mode; then
    AP_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    SSID=$(sudo grep "^ssid" /etc/hostapd/hostapd.conf 2>/dev/null | cut -d= -f2)
    echo -e "  Mode:        ${YELLOW}ACCESS POINT${NC}"
    echo -e "  SSID:        ${GREEN}$SSID${NC}"
    echo -e "  AP IP:       ${GREEN}$AP_IP${NC}"
elif iwgetid -r > /dev/null 2>&1; then
    echo -e "  Mode:        ${GREEN}CLIENT${NC}"
    echo -e "  Wi-Fi SSID:  ${GREEN}$(iwgetid -r)${NC}"
    echo -e "  IP Address:  ${GREEN}$(hostname -I | awk '{print $1}')${NC}"
else
    echo -e "  Wi-Fi:       ${YELLOW}Not connected${NC}"
fi

# Ethernet
if ip link show eth0 | grep -q "state UP"; then
    ETH_IP=$(ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    echo -e "  Ethernet IP: ${GREEN}$ETH_IP${NC}"
else
    echo -e "  Ethernet:    ${RED}Not connected${NC}"
fi
echo ""

# Storage
echo -e "${GREEN}💾 Storage:${NC}"
df -h / | awk 'NR==2 {printf "  Used: %s / %s (%s)\n", $3, $2, $5}'
echo ""

# Memory
echo -e "${GREEN}🧠 Memory:${NC}"
free -h | awk 'NR==2 {printf "  Used: %s / %s (%.0f%%)\n", $3, $2, ($3/$2)*100}'
echo ""

# Available commands
echo -e "${GREEN}💡 Available Commands:${NC}"
echo -e "  ${YELLOW}help${NC}        - Show all commands"
echo -e "  ${YELLOW}status${NC}      - System status"
echo -e "  ${YELLOW}welcome${NC}     - Show this message"
echo -e "  ${YELLOW}wifi ap${NC}     - Turn on hotspot (AP mode)"
echo -e "  ${YELLOW}wifi on${NC}     - Connect to Wi-Fi (client mode)"
echo -e "  ${YELLOW}wifi status${NC} - Check connection"
echo ""

echo -e "${CYAN}========================================${NC}"
echo -e "${YELLOW}SSH: ssh ${USER}@$(hostname).local${NC}"
echo -e "${CYAN}========================================${NC}"
EOF
        chmod +x ~/whatinthePI/welcome.sh
    fi
    
    sudo cp ~/whatinthePI/welcome.sh /etc/profile.d/welcome.sh
    sudo chmod +x /etc/profile.d/welcome.sh
    echo -e "${GREEN}✓ Welcome message installed!${NC}"
}

# Main menu
if [ "$INTERACTIVE" = true ]; then
    echo ""
    echo -e "${BLUE}What would you like to do?${NC}"
    echo "1) Setup Access Point (AP Mode) - Create your own Wi-Fi network"
    echo "2) Install Wi-Fi Manager only - Manage existing Wi-Fi connections"
    echo "3) Install all tools + create aliases (no AP setup)"
    echo -e "4) Full setup - Install everything + run AP setup ${GREEN}(RECOMMENDED)${NC}"
    echo "5) Check for updates"
    echo "6) Change hostname"
    echo "7) Change AP IP address"
    echo "8) Uninstall whatinthePI"
    echo "9) Exit"
    echo ""
    read -p "Choose [1-9] (press Enter for option 4): " choice
    
    if [ -z "$choice" ]; then
        choice=4
        echo -e "${YELLOW}Using default: Option 4 (Full setup)${NC}"
        sleep 2
    fi
else
    echo -e "${YELLOW}Non-interactive mode. Running Full Setup...${NC}"
    choice=4
fi

if [[ ! "$choice" =~ ^[1-9]$ ]]; then
    echo -e "${RED}Invalid option. Exiting.${NC}"
    exit 1
fi

case $choice in
    1)
        echo -e "${YELLOW}Setting up Access Point...${NC}"
        create_aliases
        create_helper_scripts
        setup_welcome
        cd raspi-ap-setup
        sudo ./setup_ap.sh
        ;;
    2)
        echo -e "${YELLOW}Installing Wi-Fi Manager only...${NC}"
        create_aliases
        create_helper_scripts
        setup_welcome
        echo -e "${GREEN}✓ Wi-Fi Manager installed!${NC}"
        ;;
    3)
        echo -e "${YELLOW}Installing all tools...${NC}"
        create_aliases
        create_helper_scripts
        setup_welcome
        echo -e "${GREEN}✓ All tools installed!${NC}"
        echo -e "${YELLOW}Run 'apsetup' later to configure AP${NC}"
        ;;
    4)
        echo -e "${YELLOW}Full setup: Installing tools and running AP setup...${NC}"
        create_aliases
        create_helper_scripts
        setup_welcome
        echo -e "${GREEN}✓ Tools installed! Now running AP setup...${NC}"
        sleep 2
        cd raspi-ap-setup
        sudo ./setup_ap.sh
        ;;
    5)
        echo -e "${YELLOW}Checking for updates...${NC}"
        if [ -f ~/whatinthePI/update.sh ]; then
            ~/whatinthePI/update.sh
        else
            curl -sSL https://raw.githubusercontent.com/ceej1014/whatinthePI/main/update.sh | bash
        fi
        ;;
    6)
        echo -e "${YELLOW}Changing hostname...${NC}"
        if [ -f ~/whatinthePI/changename.sh ]; then
            ~/whatinthePI/changename.sh
        else
            echo -e "${RED}Run option 3 or 4 first.${NC}"
        fi
        ;;
    7)
        echo -e "${YELLOW}Changing AP IP address...${NC}"
        if [ -f ~/whatinthePI/changeip.sh ]; then
            ~/whatinthePI/changeip.sh
        else
            echo -e "${RED}Run option 3 or 4 first.${NC}"
        fi
        ;;
    8)
        echo -e "${YELLOW}Running uninstaller...${NC}"
        if [ -f ~/whatinthePI/uninstall.sh ]; then
            ~/whatinthePI/uninstall.sh
        else
            curl -sSL https://raw.githubusercontent.com/ceej1014/whatinthePI/main/uninstall.sh | bash
        fi
        ;;
    9)
        echo -e "${GREEN}Exiting...${NC}"
        exit 0
        ;;
esac

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}Type 'help' to see all commands${NC}"
echo -e "${YELLOW}Type 'wifi ap' to turn on AP mode${NC}"
echo -e "${YELLOW}Type 'wifi on' to turn on client mode${NC}"
