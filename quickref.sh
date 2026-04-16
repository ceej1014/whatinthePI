#!/bin/bash
# Quick reference card - Simple compact version

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}              RASPBERRY PI TOOLS - QUICK REFERENCE${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BLUE}📡 CURRENT STATUS:${NC}"
echo -e "  IP: ${GREEN}$(hostname -I | awk '{print $1}')${NC}"
echo -e "  Wi-Fi: ${GREEN}$(iwgetid -r 2>/dev/null || echo 'Not connected')${NC}"
echo ""

echo -e "${BLUE}🖥️  SYSTEM COMMANDS:${NC}"
echo -e "  ${YELLOW}help${NC}       - Full help menu"
echo -e "  ${YELLOW}quickref${NC}   - This quick reference"
echo -e "  ${YELLOW}status${NC}     - System status"
echo -e "  ${YELLOW}welcome${NC}    - Welcome message"
echo -e "  ${YELLOW}version${NC}    - Show version"
echo -e "  ${YELLOW}update${NC}     - Check for updates"
echo -e "  ${YELLOW}changename${NC} - Change hostname"
echo -e "  ${YELLOW}changeip${NC}   - Change AP IP address"
echo -e "  ${YELLOW}uninstall${NC}  - Uninstall all tools"
echo -e "  ${YELLOW}myip${NC}       - Show IP address"
echo -e "  ${YELLOW}reboot${NC}     - Reboot Pi"
echo -e "  ${YELLOW}shutdown${NC}   - Shutdown Pi"
echo ""

echo -e "${BLUE}📡 WI-FI COMMANDS:${NC}"
echo -e "  ${YELLOW}wifiman${NC}    - Interactive Wi-Fi manager"
echo -e "  ${YELLOW}wifi on${NC}    - Switch to Client mode"
echo -e "  ${YELLOW}wifi off${NC}   - Turn Wi-Fi OFF"
echo -e "  ${YELLOW}wifi ap${NC}    - Switch to AP mode (hotspot)"
echo -e "  ${YELLOW}wifi status${NC} - Show current mode"
echo -e "  ${YELLOW}wifi scan${NC}  - Scan for networks"
echo -e "  ${YELLOW}wifi connect${NC} - Connect to network"
echo ""

echo -e "${BLUE}🔵 AP MODE COMMANDS:${NC}"
echo -e "  ${YELLOW}apsetup${NC}    - Setup Access Point"
echo -e "  ${YELLOW}apon${NC}       - Turn on AP mode"
echo -e "  ${YELLOW}apoff${NC}      - Turn off AP mode"
echo ""

echo -e "${BLUE}🌐 NETWORK COMMANDS:${NC}"
echo -e "  ${YELLOW}ping google${NC} - Test internet"
echo -e "  ${YELLOW}netstat${NC}    - Show connections"
echo ""

echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}SSH: ssh $USER@$(hostname).local${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Type 'help' for detailed descriptions${NC}"
