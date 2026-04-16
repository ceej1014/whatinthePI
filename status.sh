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
