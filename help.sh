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
PURPLE='\033[0;35m'
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
    echo -e "  ${YELLOW}apon${NC}                 - Turn on AP mode"
    echo -e "  ${YELLOW}apoff${NC}                - Turn off AP mode (back to client mode)"
    echo ""
fi

# Wi-Fi Manager commands
if [ -f "$SCRIPT_DIR/wifi_manager/wifi_manager.sh" ]; then
    echo -e "${GREEN}📡 WI-FI MANAGER COMMANDS:${NC}"
    echo -e "  ${YELLOW}wifiman${NC}              - Open interactive Wi-Fi Manager menu"
    echo -e "  ${YELLOW}wifi on${NC}              - Switch to Client mode (connect to Wi-Fi)"
    echo -e "  ${YELLOW}wifi off${NC}             - Turn Wi-Fi OFF completely"
    echo -e "  ${YELLOW}wifi ap${NC}              - Switch to AP mode (create hotspot)"
    echo -e "  ${YELLOW}wifi status${NC}          - Show current mode and connection"
    echo -e "  ${YELLOW}wifi scan${NC}            - Scan for available networks (client mode only)"
    echo -e "  ${YELLOW}wifi connect${NC}         - Connect to a Wi-Fi network (client mode only)"
    echo ""
fi

# System commands
echo -e "${GREEN}🖥️  SYSTEM COMMANDS:${NC}"
echo -e "  ${YELLOW}help${NC}                   - Show this help menu"
echo -e "  ${YELLOW}quickref${NC}               - Show quick reference card"
echo -e "  ${YELLOW}status${NC}                 - Show system status (IP, hostname, temp, storage)"
echo -e "  ${YELLOW}welcome${NC}                - Display welcome message"
echo -e "  ${YELLOW}version${NC}                - Show current version and commit"
echo -e "  ${YELLOW}update${NC}                 - Check for updates and update scripts"
echo -e "  ${YELLOW}changename${NC}             - Change Raspberry Pi hostname"
echo -e "  ${YELLOW}changeip${NC}               - Change Access Point IP address"
echo -e "  ${YELLOW}uninstall${NC}              - Completely remove whatinthePI tools"
echo -e "  ${YELLOW}reboot${NC}                 - Reboot the Raspberry Pi"
echo -e "  ${YELLOW}shutdown${NC}               - Shutdown the Raspberry Pi"
echo -e "  ${YELLOW}hostname${NC}               - Show current hostname"
echo -e "  ${YELLOW}myip${NC}                   - Show IP address"
echo ""

# Network commands
echo -e "${GREEN}🌐 NETWORK COMMANDS:${NC}"
echo -e "  ${YELLOW}ping google${NC}            - Test internet connection"
echo -e "  ${YELLOW}netstat${NC}                - Show network connections"
echo -e "  ${YELLOW}ifconfig${NC}               - Show network interfaces"
echo -e "  ${YELLOW}iwconfig${NC}               - Show wireless network configuration"
echo ""

# Info commands
echo -e "${GREEN}ℹ️  INFORMATION COMMANDS:${NC}"
echo -e "  ${YELLOW}date${NC}                   - Show current date and time"
echo -e "  ${YELLOW}cal${NC}                    - Show calendar"
echo -e "  ${YELLOW}df -h${NC}                  - Show disk space usage"
echo -e "  ${YELLOW}free -h${NC}                - Show memory usage"
echo -e "  ${YELLOW}top${NC}                    - Show running processes (press q to exit)"
echo -e "  ${YELLOW}htop${NC}                   - Better process viewer (install with: sudo apt install htop)"
echo ""

# Help for help
echo -e "${CYAN}💡 TIPS:${NC}"
echo -e "  • Add '${YELLOW}sudo${NC}' before commands if you get permission errors"
echo -e "  • Most commands work from anywhere in the system"
echo -e "  • Use '${YELLOW}Tab${NC}' key for auto-completion"
echo -e "  • Check logs at: ${YELLOW}/boot/setup_log.txt${NC}"
echo -e "  • Run '${YELLOW}update${NC}' regularly to get latest features"
echo ""

# Quick reference
echo -e "${BLUE}📖 QUICK REFERENCE:${NC}"
echo -e "  SSH into Pi:    ${GREEN}ssh $USER@$(hostname).local${NC}"
echo -e "  Current IP:     ${GREEN}$(hostname -I | awk '{print $1}')${NC}"
echo -e "  Current Wi-Fi:  ${GREEN}$(iwgetid -r 2>/dev/null || echo 'Not connected')${NC}"
echo ""

# Version info
if [ -d "$SCRIPT_DIR/.git" ]; then
    echo -e "${PURPLE}📦 INSTALLED VERSION:${NC}"
    echo -e "  Commit: ${YELLOW}$(cd $SCRIPT_DIR && git rev-parse --short HEAD 2>/dev/null || echo 'unknown')${NC}"
    echo -e "  Date:   ${YELLOW}$(cd $SCRIPT_DIR && git log -1 --format=%cd --date=short 2>/dev/null || echo 'unknown')${NC}"
    echo ""
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}For more info, visit:${NC}"
echo -e "https://github.com/ceej1014/whatinthePI"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${CYAN}Type 'quickref' for a compact reference card${NC}"
