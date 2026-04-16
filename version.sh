#!/bin/bash
# Custom welcome message for Raspberry Pi - Fixed AP detection

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
RED='\033[0;31m'
NC='\033[0m'

# Fixed AP detection
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

# Network info - Fixed detection
echo -e "${GREEN}🌐 Network Information:${NC}"
if is_ap_mode; then
    AP_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    SSID=$(sudo grep "^ssid" /etc/hostapd/hostapd.conf 2>/dev/null | cut -d= -f2)
    echo -e "  Mode:        ${YELLOW}ACCESS POINT${NC}"
    echo -e "  SSID:        ${GREEN}$SSID${NC}"
    echo -e "  IP:          ${GREEN}$AP_IP${NC}"
elif iwgetid -r > /dev/null 2>&1; then
    echo -e "  Mode:        ${GREEN}CLIENT${NC}"
    echo -e "  Wi-Fi SSID:  ${GREEN}$(iwgetid -r)${NC}"
    echo -e "  IP Address:  ${GREEN}$(hostname -I | awk '{print $1}')${NC}"
else
    echo -e "  Wi-Fi:       ${YELLOW}Not connected${NC}"
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
