#!/bin/bash
# System Status - Fixed AP detection

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Fixed AP detection
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

if is_ap_mode; then
    echo -e "  Mode:            ${YELLOW}ACCESS POINT${NC}"
    AP_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    SSID=$(sudo grep "^ssid" /etc/hostapd/hostapd.conf 2>/dev/null | cut -d= -f2)
    echo -e "  AP IP:           ${GREEN}$AP_IP${NC}"
    echo -e "  SSID:            ${GREEN}$SSID${NC}"
elif iwgetid -r > /dev/null 2>&1; then
    echo -e "  Mode:            ${GREEN}CLIENT (connected)${NC}"
    echo -e "  Wi-Fi SSID:      ${GREEN}$(iwgetid -r)${NC}"
    echo -e "  IP Address:      ${GREEN}$(hostname -I | awk '{print $1}')${NC}"
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
