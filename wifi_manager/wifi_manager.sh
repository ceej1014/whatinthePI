#!/bin/bash
# Raspberry Pi Wi-Fi Manager - Full interactive menu

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_menu() {
    clear
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   Raspberry Pi Wi-Fi Manager${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "${BLUE}Current Status:${NC}"
    
    if systemctl is-active --quiet hostapd; then
        echo -e "${YELLOW}Mode: ACCESS POINT (broadcasting Wi-Fi)${NC}"
        AP_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
        echo -e "  AP IP: ${GREEN}$AP_IP${NC}"
    elif iwgetid -r > /dev/null 2>&1; then
        echo -e "${GREEN}Connected to: $(iwgetid -r)${NC}"
        echo -e "IP Address: $(hostname -I | awk '{print $1}')"
    else
        echo -e "${YELLOW}Not connected to any network${NC}"
    fi
    
    echo -e "\n${BLUE}Options:${NC}"
    echo "1) Switch to AP Mode (create Wi-Fi network)"
    echo "2) Switch to Client Mode (connect to Wi-Fi)"
    echo "3) Scan for networks"
    echo "4) Connect to a network"
    echo "5) Disconnect"
    echo "6) Show connection details"
    echo "7) List saved networks"
    echo "8) Forget a network"
    echo "9) Change hostname"
    echo "10) Change AP IP address"
    echo "11) Exit"
    echo -e "${GREEN}========================================${NC}"
    read -p "Enter your choice [1-11]: " choice
}

case "$1" in
    --help|-h)
        echo "Wi-Fi Manager - Interactive menu for Wi-Fi control"
        echo "Usage: wifiman"
        exit 0
        ;;
esac

while true; do
    show_menu
    case $choice in
        1)
            echo -e "${YELLOW}Switching to AP Mode...${NC}"
            sudo systemctl stop wpa_supplicant
            sudo systemctl mask wpa_supplicant
            sudo systemctl unmask hostapd
            sudo systemctl enable hostapd
            sudo systemctl start hostapd
            sudo systemctl start dnsmasq
            echo -e "${GREEN}✓ AP Mode enabled${NC}"
            read -p "Press Enter..."
            ;;
        2)
            echo -e "${YELLOW}Switching to Client Mode...${NC}"
            sudo systemctl stop hostapd dnsmasq
            sudo systemctl disable hostapd dnsmasq
            sudo systemctl unmask wpa_supplicant
            sudo systemctl enable wpa_supplicant
            sudo systemctl restart wpa_supplicant
            echo -e "${GREEN}✓ Client Mode enabled${NC}"
            read -p "Press Enter..."
            ;;
        3)
            echo -e "${YELLOW}Scanning...${NC}"
            sudo iwlist wlan0 scan | grep -E "ESSID|Quality"
            read -p "Press Enter..."
            ;;
        4)
            read -p "Enter SSID: " ssid
            read -s -p "Enter password: " pass
            echo
            sudo nmcli device wifi connect "$ssid" password "$pass"
            read -p "Press Enter..."
            ;;
        5)
            sudo dhclient -r wlan0 2>/dev/null
            sudo ip link set wlan0 down
            echo -e "${GREEN}Disconnected${NC}"
            read -p "Press Enter..."
            ;;
        6)
            if iwgetid -r > /dev/null 2>&1; then
                echo -e "SSID: ${GREEN}$(iwgetid -r)${NC}"
                echo -e "IP: ${GREEN}$(hostname -I | awk '{print $1}')${NC}"
                echo -e "MAC: ${GREEN}$(cat /sys/class/net/wlan0/address)${NC}"
            else
                echo -e "${RED}Not connected${NC}"
            fi
            read -p "Press Enter..."
            ;;
        7)
            echo -e "${GREEN}Saved networks:${NC}"
            nmcli connection show --active
            read -p "Press Enter..."
            ;;
        8)
            read -p "Enter SSID to forget: " ssid
            sudo nmcli connection delete "$ssid" 2>/dev/null
            echo -e "${GREEN}Forgotten${NC}"
            read -p "Press Enter..."
            ;;
        9)
            read -p "New hostname: " newname
            echo "$newname" | sudo tee /etc/hostname
            sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$newname/" /etc/hosts
            echo -e "${GREEN}Hostname changed. Reboot required.${NC}"
            read -p "Press Enter..."
            ;;
        10)
            read -p "New AP IP [192.168.50.1]: " newip
            newip=${newip:-192.168.50.1}
            sudo sed -i "s/static ip_address=.*/static ip_address=$newip\/24/" /etc/dhcpcd.conf 2>/dev/null
            echo -e "${GREEN}AP IP changed to $newip${NC}"
            read -p "Press Enter..."
            ;;
        11)
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            sleep 1
            ;;
    esac
done
