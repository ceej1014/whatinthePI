#!/bin/bash
# Help script for Raspberry Pi tools
# Displays all available commands and their usage

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
echo -e "${GREEN}   Raspberry Pi Tools Help Menu${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if scripts exist
SCRIPT_DIR="/home/pi/whatinthePI"
if [ ! -d "$SCRIPT_DIR" ]; then
    SCRIPT_DIR="$(pwd)"
fi

echo -e "${CYAN}📋 AVAILABLE COMMANDS:${NC}"
echo ""

# AP Setup commands
if [ -f "$SCRIPT_DIR/raspi-ap-setup/setup_ap.sh" ]; then
    echo -e "${GREEN}🔵 AP SETUP COMMANDS:${NC}"
    echo -e "  ${YELLOW}apsetup${NC}              - Run interactive AP setup"
    echo -e "  ${YELLOW}sudo apsetup${NC}         - Run AP setup (if alias not working)"
    echo -e "  ${YELLOW}apoff${NC}                - Turn off AP mode (back to client mode)"
    echo -e "  ${YELLOW}apon${NC}                 - Turn on AP mode (run setup)"
    echo ""
fi

# Wi-Fi Manager commands
if [ -f "$SCRIPT_DIR/wifi_manager/wifi_manager.sh" ]; then
    echo -e "${GREEN}📡 WI-FI MANAGER COMMANDS:${NC}"
    echo -e "  ${YELLOW}wifiman${NC}              - Open Wi-Fi Manager menu"
    echo -e "  ${YELLOW}wifi on${NC}              - Turn Wi-Fi ON"
    echo -e "  ${YELLOW}wifi off${NC}             - Turn Wi-Fi OFF"
    echo -e "  ${YELLOW}wifi scan${NC}            - Scan for available networks"
    echo -e "  ${YELLOW}wifi connect${NC}         - Connect to a network"
    echo -e "  ${YELLOW}wifi status${NC}          - Show current connection status"
    echo -e "  ${YELLOW}wifi disconnect${NC}      - Disconnect from current network"
    echo -e "  ${YELLOW}wifi forget${NC}          - Forget a saved network"
    echo -e "  ${YELLOW}wifi list${NC}            - List saved networks"
    echo ""
fi

# System commands
echo -e "${GREEN}🖥️  SYSTEM COMMANDS:${NC}"
echo -e "  ${YELLOW}help${NC}                   - Show this help menu"
echo -e "  ${YELLOW}status${NC}                 - Show system status (IP, hostname, Wi-Fi)"
echo -e "  ${YELLOW}reboot${NC}                 - Reboot the Pi"
echo -e "  ${YELLOW}shutdown${NC}               - Shutdown the Pi"
echo -e "  ${YELLOW}hostname${NC}               - Show current hostname"
echo -e "  ${YELLOW}myip${NC}                   - Show IP address"
echo ""

# Network commands
echo -e "${GREEN}🌐 NETWORK COMMANDS:${NC}"
echo -e "  ${YELLOW}ping google${NC}            - Test internet connection"
echo -e "  ${YELLOW}netstat${NC}                - Show network connections"
echo -e "  ${YELLOW}ifconfig${NC}               - Show network interfaces"
echo ""

# Help for help
echo -e "${CYAN}💡 TIPS:${NC}"
echo -e "  • Add 'sudo' before commands if you get permission errors"
echo -e "  • Most commands work from anywhere in the system"
echo -e "  • Use 'Tab' key for auto-completion"
echo -e "  • Check logs at: /boot/setup_log.txt"
echo ""

# Quick reference
echo -e "${BLUE}📖 QUICK REFERENCE:${NC}"
echo -e "  SSH into Pi:    ${GREEN}ssh ceej@$(hostname).local${NC}"
echo -e "  Current IP:     ${GREEN}$(hostname -I | awk '{print $1}')${NC}"
echo -e "  Current Wi-Fi:  ${GREEN}$(iwgetid -r 2>/dev/null || echo 'Not connected')${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}For more info, visit:${NC}"
echo -e "https://github.com/ceej1014/whatinthePI"
echo -e "${GREEN}========================================${NC}"
