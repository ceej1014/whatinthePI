#!/bin/bash
# Help script for Raspberry Pi tools – updated for unified wifi manager

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

clear
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Raspberry Pi Tools Help Menu${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

SCRIPT_DIR="/home/pi/whatinthePI"
[ -d "$SCRIPT_DIR" ] || SCRIPT_DIR="$(pwd)"

echo -e "${CYAN}📋 AVAILABLE COMMANDS:${NC}"
echo ""

# AP setup commands (aliases to wifi subcommands)
echo -e "${GREEN}🔵 AP SETUP COMMANDS:${NC}"
echo -e "  ${YELLOW}apsetup${NC}              - Configure Access Point (SSID, password)"
echo -e "  ${YELLOW}apon${NC}                 - Turn on AP mode (hotspot)"
echo -e "  ${YELLOW}apoff${NC}                - Turn off AP mode (back to client)"
echo ""

# Unified Wi-Fi manager commands
echo -e "${GREEN}📡 UNIFIED WI-FI MANAGER:${NC}"
echo -e "  ${YELLOW}wifi${NC}                 - Open interactive menu"
echo -e "  ${YELLOW}wifiman${NC}              - Same as 'wifi'"
echo -e "  ${YELLOW}wifi on${NC}              - Switch to Client mode"
echo -e "  ${YELLOW}wifi off${NC}             - Turn Wi-Fi OFF completely"
echo -e "  ${YELLOW}wifi ap${NC}              - Switch to AP mode (hotspot)"
echo -e "  ${YELLOW}wifi ap-setup${NC}        - Configure hotspot profile"
echo -e "  ${YELLOW}wifi ap-off${NC}          - Turn off AP mode"
echo -e "  ${YELLOW}wifi status${NC}          - Show current mode and IPs"
echo -e "  ${YELLOW}wifi scan${NC}            - Scan for networks (client mode)"
echo -e "  ${YELLOW}wifi connect${NC}         - Connect to a network (client mode)"
echo -e "  ${YELLOW}wifi ap-list${NC}         - List saved hotspot profiles"
echo -e "  ${YELLOW}wifi ap-use${NC}          - Select a profile to use"
echo -e "  ${YELLOW}wifi ap-delete${NC}       - Delete a profile"
echo ""

# System commands
echo -e "${GREEN}🖥️  SYSTEM COMMANDS:${NC}"
echo -e "  ${YELLOW}help${NC}                 - Show this help menu"
echo -e "  ${YELLOW}quickref${NC}             - Show quick reference card"
echo -e "  ${YELLOW}status${NC}               - System status (IP, temp, storage)"
echo -e "  ${YELLOW}welcome${NC}              - Display welcome message"
echo -e "  ${YELLOW}version${NC}              - Show current version and commit"
echo -e "  ${YELLOW}update${NC}               - Check for updates"
echo -e "  ${YELLOW}changename${NC}           - Change hostname"
echo -e "  ${YELLOW}changeip${NC}             - Change AP IP address"
echo -e "  ${YELLOW}uninstall${NC}            - Remove whatinthePI"
echo -e "  ${YELLOW}reboot${NC}               - Reboot Pi"
echo -e "  ${YELLOW}shutdown${NC}             - Shutdown Pi"
echo -e "  ${YELLOW}myip${NC}                 - Show IP address"
echo ""

# Network commands
echo -e "${GREEN}🌐 NETWORK COMMANDS:${NC}"
echo -e "  ${YELLOW}ping google${NC}          - Test internet"
echo -e "  ${YELLOW}netstat${NC}              - Show connections"
echo -e "  ${YELLOW}ifconfig${NC}             - Show interfaces"
echo ""

# Tips
echo -e "${CYAN}💡 TIPS:${NC}"
echo -e "  • Add 'sudo' if you get permission errors"
echo -e "  • Run '${YELLOW}update${NC}' regularly"
echo ""

# Quick reference
echo -e "${BLUE}📖 QUICK REFERENCE:${NC}"
echo -e "  SSH into Pi:    ${GREEN}ssh $USER@$(hostname).local${NC}"
echo -e "  Current IP:     ${GREEN}$(hostname -I | awk '{print $1}')${NC}"
echo ""

# Version info
if [ -d "$SCRIPT_DIR/.git" ]; then
    echo -e "${PURPLE}📦 INSTALLED VERSION:${NC}"
    echo -e "  Commit: ${YELLOW}$(cd $SCRIPT_DIR && git rev-parse --short HEAD 2>/dev/null || echo 'unknown')${NC}"
    echo -e "  Date:   ${YELLOW}$(cd $SCRIPT_DIR && git log -1 --format=%cd --date=short 2>/dev/null || echo 'unknown')${NC}"
    echo ""
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}For more info: https://github.com/ceej1014/whatinthePI${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${CYAN}Type 'quickref' for a compact reference card${NC}"
