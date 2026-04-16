#!/bin/bash
# Custom welcome message for Raspberry Pi

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
RED='\033[0;31m'
NC='\033[0m'

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

# Temperature (only on Pi)
if command -v vcgencmd &> /dev/null; then
    TEMP=$(vcgencmd measure_temp | cut -d= -f2)
    echo -e "${GREEN}🌡️  Temperature:${NC} ${YELLOW}$TEMP${NC}"
    echo ""
fi

# Network info
echo -e "${GREEN}🌐 Network Information:${NC}"
if iwgetid -r > /dev/null 2>&1; then
    echo -e "  Wi-Fi SSID:  ${YELLOW}$(iwgetid -r)${NC}"
    echo -e "  IP Address:  ${YELLOW}$(hostname -I | awk '{print $1}')${NC}"
else
    echo -e "  Wi-Fi:       ${YELLOW}Not connected / AP Mode${NC}"
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

# Last login (fix for systems without 'last' command)
echo -e "${GREEN}🔐 Last Login:${NC}"
if command -v last &> /dev/null; then
    LAST_LOGIN=$(last -1 -n 1 2>/dev/null | head -1)
    if [ -n "$LAST_LOGIN" ]; then
        echo -e "  ${YELLOW}$LAST_LOGIN${NC}"
    else
        echo -e "  ${YELLOW}First login or no login history${NC}"
    fi
else
    # Alternative: show last login from log file
    if [ -f /var/log/auth.log ]; then
        LAST_SSH=$(grep "Accepted password" /var/log/auth.log 2>/dev/null | tail -1 | awk '{print $1, $2, $3, $11}')
        if [ -n "$LAST_SSH" ]; then
            echo -e "  ${YELLOW}Last SSH: $LAST_SSH${NC}"
        else
            echo -e "  ${YELLOW}No login history found${NC}"
        fi
    else
        echo -e "  ${YELLOW}Login history not available${NC}"
    fi
fi
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
echo -e "${YELLOW}SSH: ssh ${USER}@$(hostname).local${NC}"
echo -e "${CYAN}========================================${NC}"
