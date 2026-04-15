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

# Temperature
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
    # Check if AP mode is active
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
