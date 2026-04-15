#!/bin/bash
# System Status Script for Raspberry Pi
# Shows comprehensive system information

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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
echo -e "  OS Version:      $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
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
    echo -e "  Throttled:       $(vcgencmd get_throttled | cut -d= -f2)"
    echo ""
fi

# Network Information
echo -e "${GREEN}🌐 NETWORK INFORMATION${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"

# Wi-Fi Status
if iwgetid -r > /dev/null 2>&1; then
    echo -e "  Wi-Fi Status:    ${GREEN}Connected${NC}"
    echo -e "  SSID:            $(iwgetid -r)"
    echo -e "  Signal:          $(iwconfig wlan0 2>/dev/null | grep -i quality | awk '{print $2}' | cut -d= -f2)"
    echo -e "  IP Address:      $(hostname -I | awk '{print $1}')"
else
    echo -e "  Wi-Fi Status:    ${RED}Disconnected / AP Mode${NC}"
    if systemctl is-active --quiet hostapd; then
        echo -e "  Mode:            ${YELLOW}Access Point (AP Mode)${NC}"
        echo -e "  AP IP:           1.2.1.1 (default)"
    fi
fi

# Ethernet Status
if ip link show eth0 | grep -q "state UP"; then
    ETH_IP=$(ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    echo -e "  Ethernet:        ${GREEN}Connected${NC} - $ETH_IP"
else
    echo -e "  Ethernet:        ${RED}Disconnected${NC}"
fi

# Interface details
echo -e "  MAC Address:     $(cat /sys/class/net/wlan0/address 2>/dev/null || echo 'N/A')"
echo ""

# Storage Information
echo -e "${GREEN}💾 STORAGE INFORMATION${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
df -h / /boot | awk 'NR==1 {printf "  %-10s %-8s %-8s %-8s %-5s\n", "Device", "Size", "Used", "Avail", "Use%"} NR>1 {printf "  %-10s %-8s %-8s %-8s %-5s\n", $1, $2, $3, $4, $5}'

# SD Card info
if command -v mmc &> /dev/null; then
    echo ""
    echo -e "  SD Card Info:"
    echo -e "    $(cat /sys/block/mmcblk0/device/cid 2>/dev/null | cut -c1-20 || echo 'N/A')"
fi
echo ""

# Memory Information
echo -e "${GREEN}🧠 MEMORY INFORMATION${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
free -h | awk 'NR==1 {printf "  %-12s %-10s %-10s %-10s\n", "Type", "Total", "Used", "Available"} NR==2 {printf "  %-12s %-10s %-10s %-10s\n", "Memory:", $2, $3, $7} NR==3 {printf "  %-12s %-10s %-10s\n", "Swap:", $2, $3}'
echo ""

# Running Services
echo -e "${GREEN}⚙️  IMPORTANT SERVICES${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
services=("hostapd" "dnsmasq" "wpa_supplicant" "ssh" "dhcpcd")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        echo -e "  $service:        ${GREEN}● Active${NC}"
    else
        echo -e "  $service:        ${RED}○ Inactive${NC}"
    fi
done
echo ""

# Recent Log Messages
echo -e "${GREEN}📝 RECENT SYSTEM LOGS (last 5 errors)${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
sudo journalctl -p 3 -n 5 --no-pager | sed 's/^/  /' || echo "  No recent errors"
echo ""

# Quick Tips
echo -e "${GREEN}💡 QUICK TIPS${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
echo -e "  • Type ${YELLOW}help${NC} to see all available commands"
echo -e "  • Type ${YELLOW}wifiman${NC} to open Wi-Fi Manager"
echo -e "  • Type ${YELLOW}apsetup${NC} to configure Access Point"
echo -e "  • Type ${YELLOW}sudo reboot${NC} to restart your Pi"
echo ""

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    STATUS CHECK COMPLETE                   ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
