#!/bin/bash
# Quick reference card – compact version

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
echo -e "  ${YELLOW}changeip${NC}   - Change AP IP"
echo -e "  ${YELLOW}uninstall${NC}  - Uninstall all"
echo -e "  ${YELLOW}myip${NC}       - Show IP"
echo -e "  ${YELLOW}reboot${NC}     - Reboot Pi"
echo -e "  ${YELLOW}shutdown${NC}   - Shutdown Pi"
echo ""

echo -e "${BLUE}📡 WI-FI & AP COMMANDS:${NC}"
echo -e "  ${YELLOW}wifi${NC}        - Unified manager (menu)"
echo -e "  ${YELLOW}wifi on${NC}     - Client mode"
echo -e "  ${YELLOW}wifi off${NC}    - Wi-Fi OFF"
echo -e "  ${YELLOW}wifi ap${NC}     - Turn on hotspot"
echo -e "  ${YELLOW}wifi ap-off${NC} - Turn off hotspot"
echo -e "  ${YELLOW}wifi ap-setup${NC} - Configure hotspot"
echo -e "  ${YELLOW}wifi status${NC} - Show mode & IPs"
echo -e "  ${YELLOW}wifi scan${NC}   - Scan networks"
echo -e "  ${YELLOW}wifi connect${NC} - Connect to Wi-Fi"
echo ""

echo -e "${BLUE}🔵 AP MODE ALIASES:${NC}"
echo -e "  ${YELLOW}apsetup${NC}    - Same as 'wifi ap-setup'"
echo -e "  ${YELLOW}apon${NC}       - Same as 'wifi ap'"
echo -e "  ${YELLOW}apoff${NC}      - Same as 'wifi ap-off'"
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
