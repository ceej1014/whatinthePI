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
        echo "IP: $(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)"
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
echo "========================================="
echo "System Status"
echo "========================================="
echo "Hostname: $(hostname)"
echo "IP Address: $(hostname -I | awk '{print $1}')"
if systemctl is-active --quiet hostapd; then
    echo "Mode: ACCESS POINT (broadcasting Wi-Fi)"
else
    echo "Wi-Fi: $(iwgetid -r 2>/dev/null || echo 'Not connected')"
fi
echo "Uptime: $(uptime -p)"
if command -v vcgencmd &> /dev/null; then
    echo "Temperature: $(vcgencmd measure_temp | cut -d= -f2)"
fi
echo "Storage: $(df -h / | awk 'NR==2 {print $5 " used of " $2}')"
echo "Memory: $(free -h | awk 'NR==2 {print $3 " used of " $2}')"
echo "========================================="
EOF
        chmod +x ~/whatinthePI/status.sh
    fi
    
    if [ ! -f ~/whatinthePI/wifi_helper.sh ]; then
        cat > ~/whatinthePI/wifi_helper.sh << 'EOF'
#!/bin/bash
# Wi-Fi Helper - Works in both AP and Client modes

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

is_ap_mode() { systemctl is-active --quiet hostapd; }

case "$1" in
    on)
        if is_ap_mode; then
            echo "Switching from AP to Client mode..."
            sudo systemctl stop hostapd dnsmasq
            sudo systemctl disable hostapd dnsmasq
            sudo systemctl unmask wpa_supplicant
        fi
        sudo rfkill unblock wifi
        sudo ip link set wlan0 up
        sudo systemctl enable wpa_supplicant
        sudo systemctl restart wpa_supplicant
        echo "✓ Client mode enabled"
        ;;
    off)
        sudo rfkill block wifi
        echo "Wi-Fi OFF"
        ;;
    ap)
        sudo systemctl stop wpa_supplicant
        sudo systemctl mask wpa_supplicant
        sudo systemctl unmask hostapd
        sudo systemctl enable hostapd
        sudo systemctl start hostapd
        sudo systemctl start dnsmasq
        echo "✓ AP mode enabled"
        ;;
    status)
        if is_ap_mode; then
            echo "Mode: ACCESS POINT"
            ip addr show wlan0 | grep "inet "
        elif iwgetid -r > /dev/null 2>&1; then
            echo "Connected to: $(iwgetid -r)"
            echo "IP: $(hostname -I | awk '{print $1}')"
        else
            echo "Not connected"
        fi
        ;;
    scan)
        if is_ap_mode; then
            echo "Cannot scan in AP mode. Run 'wifi off' first."
        else
            sudo iwlist wlan0 scan | grep -E "ESSID|Quality"
        fi
        ;;
    connect)
        if is_ap_mode; then
            echo "Cannot connect in AP mode. Run 'wifi off' first."
        else
            read -p "SSID: " ssid
            read -s -p "Password: " pass
            echo
            sudo nmcli device wifi connect "$ssid" password "$pass"
        fi
        ;;
    *)
        echo "Usage: wifi [on|off|ap|status|scan|connect]"
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
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; RED='\033[0;31m'; NC='\033[0m'
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
echo -e "${GREEN}📊 System Information:${NC}"
echo -e "  Hostname:    ${YELLOW}$(hostname)${NC}"
echo -e "  Uptime:      ${YELLOW}$(uptime -p | sed 's/up //')${NC}"
echo -e "  Kernel:      ${YELLOW}$(uname -r)${NC}"
echo ""
if command -v vcgencmd &> /dev/null; then
    echo -e "${GREEN}🌡️  Temperature:${NC} ${YELLOW}$(vcgencmd measure_temp | cut -d= -f2)${NC}"
    echo ""
fi
echo -e "${GREEN}🌐 Network:${NC}"
if systemctl is-active --quiet hostapd; then
    echo -e "  Mode:        ${YELLOW}ACCESS POINT${NC}"
    echo -e "  IP:          ${YELLOW}$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)${NC}"
elif iwgetid -r > /dev/null 2>&1; then
    echo -e "  Wi-Fi SSID:  ${YELLOW}$(iwgetid -r)${NC}"
    echo -e "  IP Address:  ${YELLOW}$(hostname -I | awk '{print $1}')${NC}"
else
    echo -e "  Wi-Fi:       ${YELLOW}Not connected${NC}"
fi
echo ""
echo -e "${GREEN}💾 Storage:${NC}"
df -h / | awk 'NR==2 {printf "  Used: %s / %s (%s)\n", $3, $2, $5}'
echo ""
echo -e "${GREEN}🧠 Memory:${NC}"
free -h | awk 'NR==2 {printf "  Used: %s / %s (%.0f%%)\n", $3, $2, ($3/$2)*100}'
echo ""
echo -e "${GREEN}💡 Commands:${NC}"
echo -e "  ${YELLOW}help${NC}        - Show all commands"
echo -e "  ${YELLOW}status${NC}      - System status"
echo -e "  ${YELLOW}wifi ap${NC}     - Turn on AP mode"
echo -e "  ${YELLOW}wifi on${NC}     - Turn on client mode"
echo -e "  ${YELLOW}wifiman${NC}     - Wi-Fi manager"
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
