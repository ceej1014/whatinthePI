#!/bin/bash
# Raspberry Pi 4B - Guaranteed Working Access Point Setup
# Uses 192.168.50.1 as default IP (DO NOT use 1.1.1.1 or other public IPs)

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

# Default values - USE PRIVATE IP RANGES ONLY!
DEFAULT_HOSTNAME="ceejay"
DEFAULT_USERNAME="ceej"
DEFAULT_IP="192.168.50.1"  # DO NOT CHANGE TO 1.1.1.1
DEFAULT_SSID="RPi_Network"
DEFAULT_PASSWORD="raspberry123"

echo -e "${YELLOW}IMPORTANT: Use a private IP range like 192.168.x.x or 10.x.x.x${NC}"
echo -e "${YELLOW}DO NOT use public IPs like 1.1.1.1 (that's Cloudflare DNS)${NC}"
echo ""

# Get user input
read -p "Enter hostname [$DEFAULT_HOSTNAME]: " HOSTNAME
HOSTNAME=${HOSTNAME:-$DEFAULT_HOSTNAME}

read -p "Enter username for SSH login [$DEFAULT_USERNAME]: " USERNAME
USERNAME=${USERNAME:-$DEFAULT_USERNAME}

read -p "Enter AP IP address [$DEFAULT_IP]: " STATIC_IP
STATIC_IP=${STATIC_IP:-$DEFAULT_IP}

# Validate IP is not a public DNS
if [[ "$STATIC_IP" == "1.1.1.1" ]] || [[ "$STATIC_IP" == "8.8.8.8" ]] || [[ "$STATIC_IP" == "8.8.4.4" ]]; then
    echo -e "${RED}ERROR: $STATIC_IP is a public DNS server!${NC}"
    echo -e "${RED}Please use a private IP like 192.168.50.1 or 10.0.0.1${NC}"
    exit 1
fi

read -p "Enter Wi-Fi SSID (network name) [$DEFAULT_SSID]: " SSID
SSID=${SSID:-$DEFAULT_SSID}

echo -e "${YELLOW}Enter Wi-Fi password (leave blank for OPEN network)${NC}"
read -s -p "Password: " PASSWORD
echo ""

if [ -z "$PASSWORD" ]; then
    echo -e "${YELLOW}Open network selected (no password)${NC}"
fi

# Confirm
echo -e "\n${YELLOW}Confirm settings:${NC}"
echo -e "  Hostname:  ${GREEN}$HOSTNAME${NC}"
echo -e "  Username:  ${GREEN}$USERNAME${NC}"
echo -e "  AP IP:     ${GREEN}$STATIC_IP${NC}"
echo -e "  SSID:      ${GREEN}$SSID${NC}"
if [ -z "$PASSWORD" ]; then
    echo -e "  Password:  ${RED}OPEN NETWORK${NC}"
else
    echo -e "  Password:  ${GREEN}${PASSWORD:0:4}***${NC}"
fi
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
echo -e "\n${GREEN}[1/6] Installing packages...${NC}"
sudo apt update
sudo apt install -y hostapd dnsmasq

echo -e "\n${GREEN}[2/6] Stopping services...${NC}"
sudo systemctl stop hostapd
sudo systemctl stop dnsmasq
sudo systemctl stop wpa_supplicant
sudo pkill hostapd 2>/dev/null || true

echo -e "\n${GREEN}[3/6] Configuring static IP...${NC}"

# Configure dhcpcd
sudo tee -a /etc/dhcpcd.conf << EOF

# AP Setup
interface wlan0
    static ip_address=$STATIC_IP/24
    nohook wpa_supplicant
EOF

# Restart dhcpcd
sudo systemctl restart dhcpcd
sleep 3

echo -e "\n${GREEN}[4/6] Configuring hostapd...${NC}"

# Create hostapd config
if [ -z "$PASSWORD" ]; then
    # Open network
    sudo tee /etc/hostapd/hostapd.conf > /dev/null << EOF
interface=wlan0
driver=nl80211
ssid=$SSID
hw_mode=g
channel=6
wmm_enabled=1
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
EOF
else
    # Secure network
    sudo tee /etc/hostapd/hostapd.conf > /dev/null << EOF
interface=wlan0
driver=nl80211
ssid=$SSID
hw_mode=g
channel=6
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
fi

# Configure hostapd defaults
sudo sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

echo -e "\n${GREEN}[5/6] Configuring dnsmasq...${NC}"

# Calculate network prefix
NETWORK_PREFIX=$(echo $STATIC_IP | cut -d. -f1-3)

sudo tee /etc/dnsmasq.conf > /dev/null << EOF
interface=wlan0
dhcp-range=${NETWORK_PREFIX}.10,${NETWORK_PREFIX}.100,255.255.255.0,24h
dhcp-option=3,$STATIC_IP
dhcp-option=6,$STATIC_IP
server=8.8.8.8
EOF

echo -e "\n${GREEN}[6/6] Starting services...${NC}"

# Set IP on wlan0
sudo ip link set wlan0 down
sudo ip addr flush dev wlan0
sudo ip addr add ${STATIC_IP}/24 dev wlan0
sudo ip link set wlan0 up

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
# Verify services are running
# ============================================
echo -e "\n${GREEN}Verifying services...${NC}"

if systemctl is-active --quiet hostapd; then
    echo -e "${GREEN}✓ hostapd is running${NC}"
else
    echo -e "${RED}✗ hostapd failed to start${NC}"
    echo "Check logs: sudo journalctl -u hostapd"
fi

if systemctl is-active --quiet dnsmasq; then
    echo -e "${GREEN}✓ dnsmasq is running${NC}"
else
    echo -e "${RED}✗ dnsmasq failed to start${NC}"
fi

# Show wlan0 IP
echo -e "\n${GREEN}wlan0 IP address:${NC}"
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
if [ -z "$PASSWORD" ]; then
    echo -e "  Password:  ${RED}OPEN NETWORK - No password required${NC}"
else
    echo -e "  Password:  ${GREEN}$PASSWORD${NC}"
fi
echo -e "  IP Range:  ${GREEN}${NETWORK_PREFIX}.10 - ${NETWORK_PREFIX}.100${NC}"
echo ""
echo -e "${BLUE}SSH Access:${NC}"
echo -e "  ${GREEN}ssh $USERNAME@$HOSTNAME.local${NC}"
echo -e "  ${GREEN}ssh $USERNAME@$STATIC_IP${NC}"
echo ""
echo -e "${YELLOW}Rebooting in 10 seconds...${NC}"
echo -e "${YELLOW}After reboot, look for Wi-Fi: $SSID${NC}"

for i in {10..1}; do
    echo -ne "\rRebooting in $i seconds... "
    sleep 1
done

sudo reboot
