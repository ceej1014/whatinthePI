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

# Function to reboot with countdown
reboot_with_countdown() {
    echo ""
    echo -e "${YELLOW}System will reboot in 10 seconds to apply changes.${NC}"
    echo -e "${YELLOW}Press Ctrl+C to cancel reboot.${NC}"
    for i in {10..1}; do
        echo -ne "\rRebooting in $i seconds... "
        sleep 1
    done
    echo -e "\n${GREEN}Rebooting now...${NC}"
    sudo reboot
}

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

# Remove obsolete Wi-Fi helper/manager scripts (if any)
rm -f wifi_helper.sh wifi_manager.sh 2>/dev/null || true

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

# Unified Wi-Fi Manager (replaces both wifi_helper and wifiman)
alias wifi='~/whatinthePI/wifi.sh'
alias wifiman='~/whatinthePI/wifi.sh'   # same script, interactive by default

# Quick AP mode toggles (using the unified script)
alias apsetup='wifi ap-setup'
alias apon='wifi ap'
alias apoff='wifi ap-off'
alias client='wifi on'

# Legacy aliases for backward compatibility
alias ap='wifi ap'
alias ap-off='wifi ap-off'
alias client-mode='wifi on'

# Other aliases
alias myip='hostname -I | awk "{print \$1}"'
alias netstat='sudo netstat -tulpn'
alias reboot='sudo reboot'
alias shutdown='sudo shutdown now'

# END Raspberry Pi Tools Aliases
EOF

    source ~/.bash_aliases 2>/dev/null || true
    echo -e "${GREEN}✓ Aliases created successfully!${NC}"
}

# Function to create helper scripts (only status.sh now)
create_helper_scripts() {
    if [ ! -f ~/whatinthePI/status.sh ]; then
        cat > ~/whatinthePI/status.sh << 'EOF'
#!/bin/bash
# System Status - Fixed AP detection and memory calculation

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Function to detect AP mode (matches wifi.sh logic)
is_ap_mode() {
    local CONFIG_DIR="/etc/whatinthepi"
    local CURRENT_PROFILE_FILE="$CONFIG_DIR/current_profile"
    if [ -f "$CURRENT_PROFILE_FILE" ]; then
        local cur=$(cat "$CURRENT_PROFILE_FILE")
        [ -n "$cur" ] && nmcli -t -f NAME con show --active 2>/dev/null | grep -q "^$cur$"
    else
        false
    fi
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

if is_ap_mode; then
    echo -e "  Mode:            ${YELLOW}ACCESS POINT${NC}"
    # Get AP IP from the active hotspot connection (no 'local' here)
    cur=$(cat /etc/whatinthepi/current_profile 2>/dev/null)
    if [ -n "$cur" ]; then
        AP_IP=$(nmcli -t -f ipv4.addresses con show "$cur" 2>/dev/null | cut -d: -f2 | cut -d/ -f1)
        SSID=$(grep "^SSID=" "/etc/whatinthepi/profiles/${cur}.conf" 2>/dev/null | cut -d= -f2)
        echo -e "  AP SSID:         ${GREEN}$SSID${NC}"
    else
        AP_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    fi
    echo -e "  AP IP:           ${GREEN}${AP_IP:-unknown}${NC}"
elif iwgetid -r > /dev/null 2>&1; then
    echo -e "  Mode:            ${GREEN}CLIENT (connected)${NC}"
    echo -e "  Wi-Fi SSID:      ${GREEN}$(iwgetid -r)${NC}"
    echo -e "  Wi-Fi IP:        ${GREEN}$(hostname -I | awk '{print $1}')${NC}"
    echo -e "  Signal:          $(iwconfig wlan0 2>/dev/null | grep -i quality | awk '{print $2}' | cut -d= -f2)"
else
    echo -e "  Mode:            ${YELLOW}CLIENT (not connected)${NC}"
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
    
    # Ensure wifi.sh is present and executable
    if [ -f ~/whatinthePI/wifi.sh ]; then
        chmod +x ~/whatinthePI/wifi.sh
    else
        echo -e "${RED}Error: wifi.sh not found in repository!${NC}"
        exit 1
    fi

    # Create fallback hotspot profile (low priority) – only if it doesn't exist
    if ! nmcli con show fallback &>/dev/null; then
        echo -e "${YELLOW}Creating fallback hotspot profile...${NC}"
        sudo nmcli connection add type wifi ifname wlan0 con-name fallback autoconnect yes ssid "whatinthePI" mode ap ipv4.method shared wifi-sec.key-mgmt wpa-psk wifi-sec.psk "raspberry123"
        sudo nmcli connection modify fallback connection.interface-name wlan0
        sudo nmcli connection modify fallback 802-11-wireless.mode ap
        sudo nmcli connection modify fallback ipv4.addresses 192.168.50.1/24
        sudo nmcli connection modify fallback ipv4.gateway 192.168.50.1
        sudo nmcli connection modify fallback connection.autoconnect-priority 10
        echo -e "${GREEN}✓ Fallback hotspot 'whatinthePI' (password: raspberry123) created.${NC}"
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
echo -e "  ${YELLOW}wifi${NC}        - Unified Wi-Fi manager (menu or commands)"
echo -e "  ${YELLOW}wifiman${NC}     - Same as 'wifi' (interactive menu)"
echo -e "  ${YELLOW}apsetup${NC}     - Configure Access Point"
echo -e "  ${YELLOW}apon${NC}        - Turn on AP mode"
echo -e "  ${YELLOW}apoff${NC}       - Turn off AP mode"
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

# Main menu (options adjusted)
if [ "$INTERACTIVE" = true ]; then
    echo ""
    echo -e "${BLUE}What would you like to do?${NC}"
    echo "1) Setup Access Point (AP Mode) - Create your own Wi-Fi network"
    echo "2) Install all tools + create aliases (no AP setup)"
    echo -e "3) Full setup - Install everything + run AP setup ${GREEN}(RECOMMENDED)${NC}"
    echo "4) Check for updates"
    echo "5) Change hostname"
    echo "6) Change AP IP address"
    echo "7) Uninstall whatinthePI"
    echo "8) Exit"
    echo ""
    read -p "Choose [1-8] (press Enter for option 3): " choice
    
    if [ -z "$choice" ]; then
        choice=3
        echo -e "${YELLOW}Using default: Option 3 (Full setup)${NC}"
        sleep 2
    fi
else
    echo -e "${YELLOW}Non-interactive mode. Running Full Setup...${NC}"
    choice=3
fi

if [[ ! "$choice" =~ ^[1-8]$ ]]; then
    echo -e "${RED}Invalid option. Exiting.${NC}"
    exit 1
fi

case $choice in
    1)
        echo -e "${YELLOW}Setting up Access Point...${NC}"
        create_aliases
        create_helper_scripts
        setup_welcome
        # Use the new unified wifi command for AP setup
        ~/whatinthePI/wifi.sh ap-setup
        reboot_with_countdown
        ;;
    2)
        echo -e "${YELLOW}Installing all tools...${NC}"
        create_aliases
        create_helper_scripts
        setup_welcome
        echo -e "${GREEN}✓ All tools installed!${NC}"
        echo -e "${YELLOW}Run 'apsetup' later to configure AP${NC}"
        # No reboot needed
        ;;
    3)
        echo -e "${YELLOW}Full setup: Installing tools and running AP setup...${NC}"
        create_aliases
        create_helper_scripts
        setup_welcome
        echo -e "${GREEN}✓ Tools installed! Now running AP setup...${NC}"
        sleep 2
        ~/whatinthePI/wifi.sh ap-setup
        reboot_with_countdown
        ;;
    4)
        echo -e "${YELLOW}Checking for updates...${NC}"
        if [ -f ~/whatinthePI/update.sh ]; then
            ~/whatinthePI/update.sh
        else
            curl -sSL https://raw.githubusercontent.com/ceej1014/whatinthePI/main/update.sh | bash
        fi
        # No reboot needed
        ;;
    5)
        echo -e "${YELLOW}Changing hostname...${NC}"
        if [ -f ~/whatinthePI/changename.sh ]; then
            ~/whatinthePI/changename.sh
            reboot_with_countdown
        else
            echo -e "${RED}Run option 2 or 3 first.${NC}"
        fi
        ;;
    6)
        echo -e "${YELLOW}Changing AP IP address...${NC}"
        if [ -f ~/whatinthePI/changeip.sh ]; then
            ~/whatinthePI/changeip.sh
            echo -e "${YELLOW}AP IP changed. A reboot is recommended.${NC}"
            reboot_with_countdown
        else
            echo -e "${RED}Run option 2 or 3 first.${NC}"
        fi
        ;;
    7)
        echo -e "${YELLOW}Running uninstaller...${NC}"
        if [ -f ~/whatinthePI/uninstall.sh ]; then
            ~/whatinthePI/uninstall.sh
            echo -e "${YELLOW}Uninstall complete. You may want to reboot.${NC}"
            read -p "Reboot now? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo reboot
            fi
        else
            curl -sSL https://raw.githubusercontent.com/ceej1014/whatinthePI/main/uninstall.sh | bash
        fi
        ;;
    8)
        echo -e "${GREEN}Exiting...${NC}"
        exit 0
        ;;
esac

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}Type 'help' to see all commands${NC}"
echo -e "${YELLOW}Type 'wifi' to open the unified Wi-Fi manager${NC}"
