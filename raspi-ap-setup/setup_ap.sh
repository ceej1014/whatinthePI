#!/bin/bash
# Raspberry Pi 4B - Access Point Setup (NetworkManager compatible)
# This version works on modern Raspberry Pi OS

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Raspberry Pi 4B - Access Point Setup${NC}"
echo -e "${GREEN}========================================${NC}"

# Default values
DEFAULT_HOSTNAME="ceejay"
DEFAULT_USERNAME="ceej"
DEFAULT_IP="192.168.50.1"
DEFAULT_SSID="RPi_Network"
DEFAULT_PASSWORD="raspberry123"

echo -e "${YELLOW}Using IP: $DEFAULT_IP${NC}"
echo ""

# Get user input
read -p "Enter hostname [$DEFAULT_HOSTNAME]: " HOSTNAME
HOSTNAME=${HOSTNAME:-$DEFAULT_HOSTNAME}

read -p "Enter username for SSH login [$DEFAULT_USERNAME]: " USERNAME
USERNAME=${USERNAME:-$DEFAULT_USERNAME}

read -p "Enter AP IP address [$DEFAULT_IP]: " STATIC_IP
STATIC_IP=${STATIC_IP:-$DEFAULT_IP}

read -p "Enter Wi-Fi SSID (network name) [$DEFAULT_SSID]: " SSID
SSID=${SSID:-$DEFAULT_SSID}

read -s -p "Enter Wi-Fi password (min 8 chars) [$DEFAULT_PASSWORD]: " PASSWORD
echo ""
PASSWORD=${PASSWORD:-$DEFAULT_PASSWORD}

# Confirm
echo -e "\n${YELLOW}Confirm settings:${NC}"
echo -e "  Hostname:  ${GREEN}$HOSTNAME${NC}"
echo -e "  Username:  ${GREEN}$USERNAME${NC}"
echo -e "  AP IP:     ${GREEN}$STATIC_IP${NC}"
echo -e "  SSID:      ${GREEN}$SSID${NC}"
echo -e "  Password:  ${GREEN}${PASSWORD:0:4}***${NC}"
echo ""

read -p "Continue? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Cancelled${NC}"
    exit 1
fi

# Create user if needed
if ! id "$USERNAME" &>/dev/null; then
    echo -e "${YELLOW}Creating user $USERNAME...${NC}"
    sudo useradd -m -s /bin/bash "$USERNAME"
    echo -e "${YELLOW}Set password for $USERNAME:${NC}"
    sudo passwd "$USERNAME"
    sudo usermod -aG sudo "$USERNAME"
fi

# ============================================
# Configure AP
# ============================================
echo -e "\n${GREEN}[1/5] Installing packages...${NC}"
sudo apt update
sudo apt install -y hostapd dnsmasq

echo -e "\n${GREEN}[2/5] Stopping services...${NC}"
sudo systemctl stop hostapd 2>/dev/null || true
sudo systemctl stop dnsmasq 2>/dev/null || true
sudo systemctl stop wpa_supplicant 2>/dev/null || true
sudo pkill hostapd 2>/dev/null || true

echo -e "\n${GREEN}[3/5] Configuring network...${NC}"

# Disable NetworkManager for wlan0
sudo nmcli device set wlan0 managed no 2>/dev/null || true

# Set static IP
sudo ip link set wlan0 down
sudo ip addr flush dev wlan0
sudo ip addr add ${STATIC_IP}/24 dev wlan0
sudo ip link set wlan0 up

echo -e "\n${GREEN}[4/5] Configuring hostapd...${NC}"

# Create hostapd config
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

# Configure hostapd
sudo sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

# Create dnsmasq config
NETWORK_PREFIX=$(echo $STATIC_IP | cut -d. -f1-3)
sudo tee /etc/dnsmasq.conf > /dev/null << EOF
interface=wlan0
dhcp-range=${NETWORK_PREFIX}.10,${NETWORK_PREFIX}.100,255.255.255.0,24h
dhcp-option=3,$STATIC_IP
dhcp-option=6,$STATIC_IP
server=8.8.8.8
EOF

echo -e "\n${GREEN}[5/5] Starting services...${NC}"

# Start services
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl start hostapd

sudo systemctl enable dnsmasq
sudo systemctl start dnsmasq

# Enable SSH
sudo systemctl enable ssh
sudo systemctl start ssh

# Set hostname
echo "$HOSTNAME" | sudo tee /etc/hostname
sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME/" /etc/hosts

# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

# ============================================
# Verify
# ============================================
echo -e "\n${GREEN}Verifying...${NC}"
sleep 2

if systemctl is-active --quiet hostapd; then
    echo -e "${GREEN}✓ hostapd is running${NC}"
else
    echo -e "${RED}✗ hostapd failed to start${NC}"
    sudo journalctl -u hostapd --no-pager -n 10
fi

if systemctl is-active --quiet dnsmasq; then
    echo -e "${GREEN}✓ dnsmasq is running${NC}"
fi

echo -e "\n${GREEN}wlan0 IP:${NC}"
ip addr show wlan0 | grep "inet "

# ============================================
# Done
# ============================================
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Wi-Fi Network:${NC}"
echo -e "  SSID:      ${GREEN}$SSID${NC}"
echo -e "  Password:  ${GREEN}$PASSWORD${NC}"
echo -e "  IP:        ${GREEN}$STATIC_IP${NC}"
echo ""
echo -e "${BLUE}SSH Access:${NC}"
echo -e "  ${GREEN}ssh $USERNAME@$HOSTNAME.local${NC}"
echo -e "  ${GREEN}ssh $USERNAME@$STATIC_IP${NC}"
echo ""

read -p "Reboot now? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Rebooting...${NC}"
    sudo reboot
fi
