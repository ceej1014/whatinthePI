#!/bin/bash
# One-line installer for Raspberry Pi
# Usage: curl -sSL https://raw.githubusercontent.com/ceej1014/whatinthePI/main/auto_setup.sh | bash

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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
chmod +x raspi-ap-setup/setup_ap.sh 2>/dev/null || true
chmod +x wifi_manager/wifi_manager.sh 2>/dev/null || true
chmod +x help.sh 2>/dev/null || true
chmod +x quickref.sh 2>/dev/null || true
chmod +x status.sh 2>/dev/null || true
chmod +x wifi_helper.sh 2>/dev/null || true
chmod +x welcome.sh 2>/dev/null || true
chmod +x version.sh 2>/dev/null || true
chmod +x update.sh 2>/dev/null || true
chmod +x changename.sh 2>/dev/null || true
chmod +x changeip.sh 2>/dev/null || true

# Function to create aliases
create_aliases() {
    echo -e "${YELLOW}Creating aliases...${NC}"
    
    # Add to .bash_aliases for current user
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
alias wifiman='sudo ~/whatinthePI/wifi_manager/wifi_manager.sh'
alias apsetup='sudo ~/whatinthePI/raspi-ap-setup/setup_ap.sh'
alias apon='sudo ~/whatinthePI/raspi-ap-setup/setup_ap.sh'
alias apoff='sudo systemctl stop hostapd dnsmasq 2>/dev/null; sudo systemctl restart wpa_supplicant'
alias wifi='~/whatinthePI/wifi_helper.sh'
alias myip='hostname -I | awk "{print \$1}"'
alias netstat='sudo netstat -tulpn'
alias reboot='sudo reboot'
alias shutdown='sudo shutdown now'

# Wi-Fi quick commands
wifion() { sudo rfkill unblock wifi && sudo ip link set wlan0 up; echo "Wi-Fi ON"; }
wifioff() { sudo rfkill block wifi; echo "Wi-Fi OFF"; }
wifiscan() { sudo iwlist wlan0 scan | grep -E "ESSID|Quality"; }
wificonnect() { 
    read -p "Enter SSID: " ssid
    read -s -p "Enter password: " pass
    echo
    echo "Connecting to $ssid..."
    wpa_passphrase "$ssid" "$pass" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
    sudo systemctl restart wpa_supplicant
    sleep 3
    wifistatus
}
wifistatus() { 
    if iwgetid -r > /dev/null 2>&1; then
        echo "Connected to: $(iwgetid -r)"
        echo "IP: $(hostname -I | awk '{print $1}')"
    else
        echo "Not connected to any network"
    fi
}
wifidisconnect() { sudo dhclient -r wlan0; echo "Disconnected"; }
wififorget() { 
    echo "Opening wpa_supplicant.conf - delete the network entry"
    sudo nano /etc/wpa_supplicant/wpa_supplicant.conf
    sudo systemctl restart wpa_supplicant
}
wifilist() { sudo grep -E "^[[:space:]]*ssid=" /etc/wpa_supplicant/wpa_supplicant.conf | sed 's/.*ssid="\(.*\)"/\1/'; }
EOF

    # Source the aliases
    source ~/.bash_aliases 2>/dev/null || true
    
    echo -e "${GREEN}Aliases created successfully!${NC}"
}

# Function to create helper scripts
create_helper_scripts() {
    # Create status.sh if it doesn't exist
    if [ ! -f ~/whatinthePI/status.sh ]; then
        cat > ~/whatinthePI/status.sh << 'EOF'
#!/bin/bash
echo "========================================="
echo "System Status"
echo "========================================="
echo "Hostname: $(hostname)"
echo "IP Address: $(hostname -I | awk '{print $1}')"
echo "Wi-Fi: $(iwgetid -r 2>/dev/null || echo 'Not connected/AP Mode')"
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
    
    # Create wifi_helper.sh if it doesn't exist
    if [ ! -f ~/whatinthePI/wifi_helper.sh ]; then
        cat > ~/whatinthePI/wifi_helper.sh << 'EOF'
#!/bin/bash
case "$1" in
    on)
        sudo rfkill unblock wifi
        sudo ip link set wlan0 up
        echo "Wi-Fi turned ON"
        ;;
    off)
        sudo rfkill block wifi
        echo "Wi-Fi turned OFF"
        ;;
    scan)
        sudo iwlist wlan0 scan | grep -E "ESSID|Quality"
        ;;
    status)
        if iwgetid -r > /dev/null 2>&1; then
            echo "Connected to: $(iwgetid -r)"
            echo "IP: $(hostname -I | awk '{print $1}')"
        else
            echo "Not connected to any network"
        fi
        ;;
    disconnect)
        sudo dhclient -r wlan0
        echo "Disconnected"
        ;;
    list)
        sudo grep -E "^[[:space:]]*ssid=" /etc/wpa_supplicant/wpa_supplicant.conf | sed 's/.*ssid="\(.*\)"/\1/'
        ;;
    connect)
        read -p "Enter SSID: " ssid
        read -s -p "Enter password: " pass
        echo
        echo "Connecting to $ssid..."
        wpa_passphrase "$ssid" "$pass" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
        sudo systemctl restart wpa_supplicant
        sleep 3
        wifistatus
        ;;
    *)
        echo "Wi-Fi Helper Commands:"
        echo "  wifi on        - Turn Wi-Fi ON"
        echo "  wifi off       - Turn Wi-Fi OFF"
        echo "  wifi scan      - Scan for networks"
        echo "  wifi status    - Show connection status"
        echo "  wifi disconnect- Disconnect from network"
        echo "  wifi connect   - Connect to a network"
        echo "  wifi list      - List saved networks"
        ;;
esac
EOF
        chmod +x ~/whatinthePI/wifi_helper.sh
    fi
}

# Function to setup welcome message with clear RASPI banner
setup_welcome() {
    echo -e "${YELLOW}Setting up welcome message...${NC}"
    
    # Create welcome.sh if it doesn't exist
    if [ ! -f ~/whatinthePI/welcome.sh ]; then
        cat > ~/whatinthePI/welcome.sh << 'EOF'
#!/bin/bash
# Custom welcome message for Raspberry Pi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
RED='\033[0;31m'
NC='\033[0m'

clear

# Clear RASPI ASCII Art Banner
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

# Temperature (only on Pi)
if command -v vcgencmd &> /dev/null; then
    TEMP=$(vcgencmd measure_temp | cut -d= -f2)
    echo -e "${GREEN}🌡️  Temperature:${NC} ${YELLOW}$TEMP${NC}"
fi
echo ""

# Network info
echo -e "${GREEN}🌐 Network Information:${NC}"
if iwgetid -r > /dev/null 2>&1; then
    echo -e "  Wi-Fi SSID:  ${YELLOW}$(iwgetid -r)${NC}"
    echo -e "  IP Address:  ${YELLOW}$(hostname -I | awk '{print $1}')${NC}"
else
    echo -e "  Wi-Fi:       ${YELLOW}Not connected / AP Mode${NC}"
    if systemctl is-active --quiet hostapd; then
        AP_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
        echo -e "  AP IP:       ${YELLOW}${AP_IP:-1.2.1.1}${NC}"
    else
        echo -e "  AP IP:       ${YELLOW}1.2.1.1 (default)${NC}"
    fi
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

# Last login
echo -e "${GREEN}🔐 Last Login:${NC}"
last -1 -n 1 | head -1 | sed 's/^/  /' 2>/dev/null || echo "  First login"
echo ""

# Available commands
echo -e "${GREEN}💡 Available Commands:${NC}"
echo -e "  ${YELLOW}help${NC}        - Show all commands"
echo -e "  ${YELLOW}status${NC}      - System status"
echo -e "  ${YELLOW}welcome${NC}     - Show this welcome message"
echo -e "  ${YELLOW}changename${NC}  - Change hostname"
echo -e "  ${YELLOW}changeip${NC}    - Change AP IP address"
echo -e "  ${YELLOW}wifiman${NC}     - Wi-Fi manager"
echo -e "  ${YELLOW}apsetup${NC}     - Setup access point"
echo ""

echo -e "${CYAN}========================================${NC}"
EOF
        chmod +x ~/whatinthePI/welcome.sh
    fi
    
    # Install to /etc/profile.d so it shows on SSH login
    sudo cp ~/whatinthePI/welcome.sh /etc/profile.d/welcome.sh
    sudo chmod +x /etc/profile.d/welcome.sh
    
    echo -e "${GREEN}Welcome message installed! It will show every time you SSH in.${NC}"
}

# Ask what to install
echo ""
echo -e "${BLUE}What would you like to do?${NC}"
echo "1) Setup Access Point (AP Mode) - Create your own Wi-Fi network"
echo "2) Install Wi-Fi Manager only - Manage existing Wi-Fi connections"
echo "3) Install all tools + create aliases (no AP setup)"
echo "4) Full setup - Install everything + run AP setup"
echo "5) Check for updates"
echo "6) Change hostname"
echo "7) Change AP IP address"
echo "8) Exit"
echo ""
read -p "Choose [1-8]: " choice

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
        echo -e "${GREEN}Wi-Fi Manager installed!${NC}"
        echo -e "Run it with: ${YELLOW}wifiman${NC} or ${YELLOW}sudo wifi_manager/wifi_manager.sh${NC}"
        echo ""
        echo "Quick Wi-Fi commands now available:"
        echo "  wifi on      - Turn Wi-Fi on"
        echo "  wifi off     - Turn Wi-Fi off"
        echo "  wifi scan    - Scan for networks"
        echo "  wifi status  - Check connection"
        echo "  wifi connect - Connect to network"
        ;;
    3)
        echo -e "${YELLOW}Installing all tools...${NC}"
        create_aliases
        create_helper_scripts
        setup_welcome
        echo -e "${GREEN}All tools installed!${NC}"
        echo ""
        echo -e "${BLUE}Available commands:${NC}"
        echo "  help      - Show full help menu"
        echo "  quickref  - Quick reference card"
        echo "  status    - Check system status"
        echo "  welcome   - Show welcome message"
        echo "  version   - Show version info"
        echo "  update    - Check for updates"
        echo "  changename- Change hostname"
        echo "  changeip  - Change AP IP address"
        echo "  wifiman   - Open Wi-Fi Manager"
        echo "  apsetup   - Run AP setup (when ready)"
        echo "  wifi      - Quick Wi-Fi commands"
        echo ""
        echo "Type 'help' to see all available commands"
        ;;
    4)
        echo -e "${YELLOW}Full setup: Installing tools and running AP setup...${NC}"
        create_aliases
        create_helper_scripts
        setup_welcome
        echo -e "${GREEN}Tools installed! Now running AP setup...${NC}"
        sleep 2
        cd raspi-ap-setup
        sudo ./setup_ap.sh
        ;;
    5)
        echo -e "${YELLOW}Checking for updates...${NC}"
        if [ -f ~/whatinthePI/update.sh ]; then
            ~/whatinthePI/update.sh
        else
            echo -e "${YELLOW}Downloading update script...${NC}"
            curl -sSL https://raw.githubusercontent.com/ceej1014/whatinthePI/main/update.sh | bash
        fi
        ;;
    6)
        echo -e "${YELLOW}Changing hostname...${NC}"
        if [ -f ~/whatinthePI/changename.sh ]; then
            ~/whatinthePI/changename.sh
        else
            echo -e "${RED}changename.sh not found. Run full setup first.${NC}"
        fi
        ;;
    7)
        echo -e "${YELLOW}Changing AP IP address...${NC}"
        if [ -f ~/whatinthePI/changeip.sh ]; then
            ~/whatinthePI/changeip.sh
        else
            echo -e "${RED}changeip.sh not found. Run full setup first.${NC}"
        fi
        ;;
    8)
        echo -e "${GREEN}Exiting...${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option. Exiting.${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}To see all available commands, type:${NC} ${GREEN}help${NC}"
echo -e "${YELLOW}For quick reference, type:${NC} ${GREEN}quickref${NC}"
echo -e "${YELLOW}To check system status, type:${NC} ${GREEN}status${NC}"
echo -e "${YELLOW}To check for updates, type:${NC} ${GREEN}update${NC}"
echo -e "${YELLOW}To change hostname, type:${NC} ${GREEN}changename${NC}"
echo -e "${YELLOW}To change AP IP, type:${NC} ${GREEN}changeip${NC}"
echo -e "${YELLOW}The welcome message will appear every time you SSH in!${NC}"
echo ""
echo -e "${BLUE}Tip: Run 'source ~/.bashrc' to ensure all aliases work${NC}"
