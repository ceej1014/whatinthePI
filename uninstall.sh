#!/bin/bash
# Uninstaller for whatinthePI - Raspberry Pi Tools
# Removes all scripts, aliases, configurations, and restores original settings

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${RED}========================================${NC}"
echo -e "${RED}   whatinthePI - Uninstaller${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo -e "${YELLOW}WARNING: This will remove all whatinthePI tools and configurations!${NC}"
echo ""
echo -e "This will remove:"
echo -e "  ${RED}•${NC} All whatinthePI scripts and files"
echo -e "  ${RED}•${NC} All aliases (help, status, wifiman, apsetup, etc.)"
echo -e "  ${RED}•${NC} Welcome message from SSH login"
echo -e "  ${RED}•${NC} AP Mode configuration (if enabled)"
echo -e "  ${RED}•${NC} The ~/whatinthePI directory"
echo ""
echo -e "${YELLOW}What will NOT be removed:${NC}"
echo -e "  ${GREEN}•${NC} Your saved Wi-Fi networks"
echo -e "  ${GREEN}•${NC} Your hostname (keeps current setting)"
echo -e "  ${GREEN}•${NC} Other system configurations"
echo ""
read -p "Are you sure you want to uninstall? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Uninstall cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Starting uninstallation...${NC}"
echo ""

# Function to remove aliases
remove_aliases() {
    echo -e "${BLUE}Removing aliases...${NC}"
    
    if [ -f ~/.bash_aliases ]; then
        cp ~/.bash_aliases ~/.bash_aliases.bak
        echo -e "  Backup saved to: ~/.bash_aliases.bak"
        sed -i '/# Raspberry Pi Tools Aliases/,/# END Raspberry Pi Tools Aliases/d' ~/.bash_aliases
        echo -e "  ${GREEN}✓${NC} Removed aliases from .bash_aliases"
    fi
    
    if [ -f ~/.bashrc ]; then
        sed -i '/source ~\/.bash_aliases/d' ~/.bashrc
    fi
    
    echo -e "  ${GREEN}✓${NC} Aliases removed"
}

# Function to remove welcome message
remove_welcome() {
    echo -e "${BLUE}Removing welcome message...${NC}"
    
    if [ -f /etc/profile.d/welcome.sh ]; then
        sudo rm -f /etc/profile.d/welcome.sh
        echo -e "  ${GREEN}✓${NC} Removed /etc/profile.d/welcome.sh"
    fi
    
    echo -e "  ${GREEN}✓${NC} Welcome message removed"
}

# Function to disable AP mode if active
disable_ap_mode() {
    echo -e "${BLUE}Checking for AP mode...${NC}"
    
    if systemctl is-active --quiet hostapd; then
        echo -e "  ${YELLOW}AP mode is currently active. Disabling...${NC}"
        sudo systemctl stop hostapd dnsmasq
        sudo systemctl disable hostapd dnsmasq
        echo -e "  ${GREEN}✓${NC} AP mode disabled"
    else
        echo -e "  ${GREEN}✓${NC} AP mode not active"
    fi
    
    if ! systemctl is-enabled --quiet wpa_supplicant 2>/dev/null; then
        sudo systemctl enable wpa_supplicant
        echo -e "  ${GREEN}✓${NC} Restored wpa_supplicant"
    fi
}

# Function to restore original network configs
restore_network_configs() {
    echo -e "${BLUE}Restoring network configurations...${NC}"
    
    if [ -f /etc/dhcpcd.conf.bak ]; then
        sudo cp /etc/dhcpcd.conf.bak /etc/dhcpcd.conf
        echo -e "  ${GREEN}✓${NC} Restored /etc/dhcpcd.conf from backup"
    fi
    
    if [ -f /etc/dnsmasq.conf.bak ]; then
        sudo cp /etc/dnsmasq.conf.bak /etc/dnsmasq.conf
        echo -e "  ${GREEN}✓${NC} Restored /etc/dnsmasq.conf from backup"
    fi
    
    if [ -f /etc/hostapd/hostapd.conf.bak ]; then
        sudo cp /etc/hostapd/hostapd.conf.bak /etc/hostapd/hostapd.conf
        echo -e "  ${GREEN}✓${NC} Restored /etc/hostapd/hostapd.conf from backup"
    fi
}

# Function to remove the whatinthePI directory
remove_directory() {
    echo -e "${BLUE}Removing whatinthePI directory...${NC}"
    
    if [ -d ~/whatinthePI ]; then
        echo ""
        read -p "Do you want to keep a backup of the scripts? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            BACKUP_DIR=~/whatinthePI_backup_$(date +%Y%m%d_%H%M%S)
            mv ~/whatinthePI "$BACKUP_DIR"
            echo -e "  ${GREEN}✓${NC} Backup saved to: $BACKUP_DIR"
        else
            rm -rf ~/whatinthePI
            echo -e "  ${GREEN}✓${NC} Removed ~/whatinthePI directory"
        fi
    else
        echo -e "  ${GREEN}✓${NC} whatinthePI directory not found"
    fi
}

# Function to remove backup files
remove_backups() {
    echo -e "${BLUE}Cleaning up backup files...${NC}"
    
    sudo rm -f /etc/dhcpcd.conf.bak 2>/dev/null
    sudo rm -f /etc/dnsmasq.conf.bak 2>/dev/null
    sudo rm -f /etc/hostapd/hostapd.conf.bak 2>/dev/null
    
    echo -e "  ${GREEN}✓${NC} Removed backup files"
}

# Function to show summary
show_summary() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   Uninstall Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}What was removed:${NC}"
    echo -e "  ${GREEN}✓${NC} All whatinthePI scripts and aliases"
    echo -e "  ${GREEN}✓${NC} Welcome message from SSH login"
    echo -e "  ${GREEN}✓${NC} AP mode configuration (if it was enabled)"
    echo -e "  ${GREEN}✓${NC} Network configuration backups"
    echo ""
    echo -e "${YELLOW}What remains unchanged:${NC}"
    echo -e "  ${GREEN}✓${NC} Your saved Wi-Fi networks"
    echo -e "  ${GREEN}✓${NC} Your hostname (currently: $(hostname))"
    echo -e "  ${GREEN}✓${NC} Other system settings"
    echo ""
    echo -e "${CYAN}To complete the uninstallation:${NC}"
    echo -e "  ${YELLOW}1.${NC} Run: ${GREEN}source ~/.bashrc${NC} (to remove aliases from current session)"
    echo -e "  ${YELLOW}2.${NC} Or simply: ${GREEN}exit${NC} and log back in"
    echo ""
    echo -e "${RED}Thank you for using whatinthePI!${NC}"
    echo -e "${CYAN}If you want to reinstall, run:${NC}"
    echo -e "  ${GREEN}curl -sSL https://raw.githubusercontent.com/ceej1014/whatinthePI/main/auto_setup.sh | bash${NC}"
    echo ""
}

# Main uninstallation flow
remove_aliases
remove_welcome
disable_ap_mode
restore_network_configs
remove_directory
remove_backups
show_summary

# Offer to reboot
echo ""
read -p "Reboot now to complete uninstallation? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Rebooting...${NC}"
    sudo reboot
else
    echo -e "${YELLOW}Remember to reboot later for all changes to take effect.${NC}"
fi
