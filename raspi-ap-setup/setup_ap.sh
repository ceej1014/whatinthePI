#!/bin/bash
# Raspberry Pi 4B - Complete Access Point Setup
# Works with modern Raspberry Pi OS (NetworkManager)
# All-in-One setup with SSH, avahi, and AP configuration

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if running interactively
if [ -t 0 ] && [ -t 1 ] && [ -t 2 ]; then
    INTERACTIVE=true
else
    INTERACTIVE=false
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Raspberry Pi 4B - Complete AP Setup${NC}"
echo -e "${GREEN}========================================${NC}"

# Default values
DEFAULT_HOSTNAME="ceejay"
DEFAULT_IP="192.168.50.1"
DEFAULT_SSID="RPi_Network"
DEFAULT_PASSWORD="raspberry123"

# Get user input (only if interactive)
if [ "$INTERACTIVE" = true ]; then
    echo -e "${YELLOW}Press Enter to use default values${NC}\n"
    
    read -p "Enter hostname [$DEFAULT_HOSTNAME]: " HOSTNAME
    HOSTNAME=${HOSTNAME:-$DEFAULT_HOSTNAME}
    
    read -p "Enter AP IP address [$DEFAULT_IP]: " STATIC_IP
    STATIC_IP=${STATIC_IP:-$DEFAULT_IP}
    
    read -p "Enter Wi-Fi SSID [$DEFAULT_SSID]: " SSID
    SSID=${SSID:-$DEFAULT_SSID}
    
    read -s -p "Enter Wi-Fi password (min 8 chars) [$DEFAULT_PASSWORD]: " PASSWORD
    echo ""
    PASSWORD=${PASSWORD:-$DEFAULT_PASSWORD}
    
    echo -e "\n${YELLOW}Confirm settings:${NC}"
    echo -e "  Hostname: ${GREEN}$HOSTNAME${NC}"
    echo -e "  AP IP: ${GREEN}$STATIC_IP${NC}"
    echo -e "  SSID: ${GREEN}$SSID${NC}"
    echo -e "  Password: ${GREEN}${PASSWORD:0:4}***${NC}"
    echo ""
    
    read -p "Continue? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Cancelled${NC}"
        exit 1
    fi
else
    # Non-interactive mode - use defaults
    HOSTNAME="$DEFAULT_HOSTNAME"
    STATIC_IP="$DEFAULT_IP"
    SSID="$DEFAULT_SSID"
    PASSWORD="$DEFAULT_PASSWORD"
    
    echo -e "${YELLOW}Non-interactive mode. Using defaults:${NC}"
    echo -e "  Hostname: ${GREEN}$HOSTNAME${NC}"
    echo -e "  AP IP: ${GREEN}$STATIC_IP${NC}"
    echo -e "  SSID: ${GREEN}$SSID${NC}"
    echo ""
    sleep 2
fi

# ============================================
# Step 1: Update system
# ============================================
echo -e "\n${GREEN}[1/8] Updating system...${NC}"
sudo apt update -qq

# ============================================
# Step 2: Install required packages
# ============================================
echo -e "\n${GREEN}[2/8] Installing packages...${NC}"
sudo apt install -y hostapd dnsmasq avahi-daemon iptables

# ============================================
# Step 3: Enable SSH
# ============================================
echo -e "\n${GREEN}[3/8] Enabling SSH...${NC}"
sudo systemctl enable ssh
sudo systemctl start ssh

# ============================================
# Step 4: Set hostname
# ============================================
echo -e "\n${GREEN}[4/8] Setting hostname...${NC}"
echo "$HOSTNAME" | sudo tee /etc/hostname > /dev/null

# Update hosts file
if grep -q "127.0.1.1" /etc/hosts; then
    sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME/" /etc/hosts
else
    echo "127.0.1.1	$HOSTNAME" | sudo tee -a /etc/hosts
fi

# ============================================
# Step 5: Configure static IP
# ============================================
echo -e "\n${GREEN}[5/8] Configuring static IP...${NC}"

# Stop services first
sudo systemctl stop wpa_supplicant 2>/dev/null || true
sudo systemctl stop hostapd 2>/dev/null || true
sudo systemctl stop dnsmasq 2>/dev/null || true

# For NetworkManager (modern Raspberry Pi OS)
if command -v nmcli &> /dev/null; then
    # Remove existing connection if exists
    sudo nmcli connection delete AP-Hotspot 2>/dev/null || true
    
    # Create new hotspot connection
    sudo nmcli connection add type wifi ifname wlan0 con-name AP-Hotspot autoconnect no
    sudo nmcli connection modify AP-Hotspot 802-11-wireless.mode ap
    sudo nmcli connection modify AP-Hotspot 802-11-wireless.ssid "$SSID"
    sudo nmcli connection modify AP-Hotspot wifi-sec.key-mgmt wpa-psk
    sudo nmcli connection modify AP-Hotspot wifi-sec.psk "$PASSWORD"
    sudo nmcli connection modify AP-Hotspot ipv4.method manual
    sudo nmcli connection modify AP-Hotspot ipv4.addresses ${STATIC_IP}/24
    sudo nmcli connection modify AP-Hotspot ipv4.gateway $STATIC_IP
    sudo nmcli connection modify AP-Hotspot ipv4.dns "8.8.8.8"
    
    # Disable wpa_supplicant
    sudo systemctl disable wpa_supplicant 2>/dev/null || true
else
    # Fallback to dhcpcd (older Raspberry Pi OS)
    sudo sed -i '/^interface wlan0/,/^$/d' /etc/dhcpcd.conf
    sudo cat >> /etc/dhcpcd.conf << EOF

interface wlan0
    static ip_address=$STATIC_IP/24
    nohook wpa_supplicant
EOF
fi

# ============================================
# Step 6: Configure hostapd (fallback)
# ============================================
echo -e "\n${GREEN}[6/8] Configuring hostapd...${NC}"

sudo tee /etc/hostapd/hostapd.conf > /dev/null << EOF
interface=wlan0
driver=nl80211
ssid=$SSID
hw_mode=g
channel=7
wmm_enabled=1
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$PASSWORD
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

# Point hostapd to config file
sudo sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

# ============================================
# Step 7: Configure dnsmasq
# ============================================
echo -e "\n${GREEN}[7/8] Configuring dnsmasq...${NC}"

NETWORK_PREFIX=$(echo $STATIC_IP | cut -d. -f1-3)

sudo tee /etc/dnsmasq.conf > /dev/null << EOF
interface=wlan0
dhcp-range=${NETWORK_PREFIX}.10,${NETWORK_PREFIX}.100,255.255.255.0,24h
dhcp-option=3,$STATIC_IP
dhcp-option=6,$STATIC_IP
server=8.8.8.8
server=8.8.4.4
log-queries
log-dhcp
EOF

# ============================================
# Step 8: Enable and start services
# ============================================
echo -e "\n${GREEN}[8/8] Starting services...${NC}"

# Enable services
sudo systemctl unmask hostapd 2>/dev/null || true
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq
sudo systemctl enable avahi-daemon

# Start services
sudo systemctl restart hostapd
sudo systemctl restart dnsmasq
sudo systemctl restart avahi-daemon

# Set IP on wlan0 if not already set
sudo ip addr add ${STATIC_IP}/24 dev wlan0 2>/dev/null || true
sudo ip link set wlan0 up

# ============================================
# Done!
# ============================================
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo -e "  Hostname:  ${GREEN}$HOSTNAME${NC}"
echo -e "  AP IP:     ${GREEN}$STATIC_IP${NC}"
echo -e "  SSID:      ${GREEN}$SSID${NC}"
echo -e "  Password:  ${GREEN}$PASSWORD${NC}"
echo ""
echo -e "${BLUE}SSH Access after reboot:${NC}"
echo -e "  ${GREEN}ssh ceej@$HOSTNAME.local${NC}"
echo -e "  ${GREEN}ssh ceej@$STATIC_IP${NC}"
echo ""
echo -e "${YELLOW}After reboot, look for Wi-Fi network: ${GREEN}$SSID${NC}"
echo ""
echo -e "${YELLOW}Rebooting in 10 seconds...${NC}"

for i in {10..1}; do
    echo -ne "\rRebooting in $i seconds... "
    sleep 1
done

echo -e "\n${GREEN}Rebooting now...${NC}"
sudo reboot
