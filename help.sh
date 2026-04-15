#!/bin/bash
# Quick reference card for Raspberry Pi tools

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    QUICK REFERENCE CARD                          ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║ ${GREEN}COMMAND${NC}                    │ ${GREEN}DESCRIPTION${NC}                                      ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║ ${YELLOW}help${NC}                       │ Full help menu                                        ${CYAN}║${NC}"
echo -e "${CYAN}║ ${YELLOW}quickref${NC}                   │ This quick reference                                  ${CYAN}║${NC}"
echo -e "${CYAN}║ ${YELLOW}status${NC}                     │ System status (temp, IP, storage)                    ${CYAN}║${NC}"
echo -e "${CYAN}║ ${YELLOW}welcome${NC}                    │ Show welcome message                                  ${CYAN}║${NC}"
echo -e "${CYAN}║ ${YELLOW}version${NC}                    │ Show current version                                  ${CYAN}║${NC}"
echo -e "${CYAN}║ ${YELLOW}update${NC}                     │ Check for updates                                     ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║ ${YELLOW}wifiman${NC}                    │ Interactive Wi-Fi manager                            ${CYAN}║${NC}"
echo -e "${CYAN}║ ${YELLOW}wifi on${NC}                    │ Turn Wi-Fi ON                                         ${CYAN}║${NC}"
echo -e "${CYAN}║ ${YELLOW}wifi off${NC}                   │ Turn Wi-Fi OFF                                        ${CYAN}║${NC}"
echo -e "${CYAN}║ ${YELLOW}wifi scan${NC}                  │ Scan for networks                                     ${CYAN}║${NC}"
echo -e "${CYAN}║ ${YELLOW}wifi connect${NC}               │ Connect to a network                                  ${CYAN}║${NC}"
echo -e "${CYAN}║ ${YELLOW}wifi status${NC}                │ Show connection status                                ${CYAN}║${NC}"
echo -e "${CYAN}║ ${YELLOW}wifi disconnect${NC}            │ Disconnect from network                               ${CYAN}║${NC}"
echo -e "${CYAN}║ ${YELLOW}wifi list${NC}                  │ List saved networks                                   ${CYAN}║${NC}"
echo -e "${CYAN}║ ${YELLOW}wifi forget${NC}                │ Forget a saved network                                ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║ ${YELLOW}apsetup${NC}                    │ Setup Access Point mode                               ${CYAN}║${NC}"
echo -e "${CYAN}║ ${YELLOW}apon${NC}                       │ Turn on AP mode                                       ${CYAN}║${NC}"
echo -e "${CYAN}║ ${YELLOW}apoff${NC}                      │ Turn off AP mode                                      ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║ ${YELLOW}myip${NC}                       │ Show IP address                                       ${CYAN}║${NC}"
echo -e "${CYAN}║ ${YELLOW}reboot${NC}                     │ Reboot Raspberry Pi                                   ${CYAN}║${NC}"
echo -e "${CYAN}║ ${YELLOW}shutdown${NC}                   │ Shutdown Raspberry Pi                                 ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Tip: Use 'help' for detailed descriptions${NC}"
