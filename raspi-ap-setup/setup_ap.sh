#!/bin/bash

# Raspberry Pi 4B - Dynamic Access Point Setup
# Allows custom IP, Wi-Fi name, password, and hostname

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Raspberry Pi 4B Dynamic Access Point Setup${NC}"
echo -e "${GREEN}========================================${NC}"

# Get user input with defaults
echo -e "${YELLOW}Press Enter to use default values in brackets${NC}\n"

# Hostname input
read -p "Enter hostname [ceejay]: " HOSTNAME
HOSTNAME=${HOSTNAME:-ceejay}

# IP address input
read -p "Enter static IP address for the Pi [1.2.1.1]: " STATIC_IP
STATIC_IP=${STATIC_IP:-1.2.1.1}

# Validate IP format (basic check)
if ! [[ $STATIC_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}Invalid IP address format!${NC}"
    exit 1
fi

# Calculate network address (remove last octet)
NETWORK_ADDR=$(echo $STATIC_IP | cut -d. -f1-3)

# Wi-Fi SSID input
read -p "Enter Wi-Fi network name (SSID) [raspi_cj]: " SSID
SSID=${SSID:-raspi_cj}

# Password input (allow blank for open network)
read -p "Enter Wi-Fi password (leave blank for open network): " PASSWORD

# Confirm settings
echo -e "\n${YELLOW}Please confirm your settings:${NC}"
echo -e "Hostname: ${GREEN}$HOSTNAME${NC}"
echo -e "Pi IP Address: ${GREEN}$STATIC_IP${NC}"
echo -e "Wi-Fi SSID: ${GREEN}$SSID${NC}"
if [ -z "$PASSWORD" ]; then
    echo -e "Wi-Fi Password: ${RED}NO PASSWORD (Open Network)${NC}"
else
    echo -e "Wi-Fi Password: ${GREEN}$PASSWORD${NC}"
fi
echo ""

read -p "Continue with setup? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Setup cancelled.${NC}"
    exit 1
fi

echo -e "\n${GREEN}Setting up Raspberry Pi as access point...${NC}"

# Update system
sudo apt update
sudo apt upgrade -y

# Install required packages
sudo apt install -y hostapd dnsmasq iptables

# Stop services while configuring
sudo systemctl stop hostapd 2>/dev/null || true
sudo systemctl stop dnsmasq 2>/dev/null || true

# Configure static IP for wlan0
sudo cat > /etc/dhcpcd.conf << EOF
# Custom static IP for access point
interface wlan0
    static ip_address=$STATIC_IP/24
    nohook wpa_supplicant
EOF

# Backup original configs if they exist
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.bak 2>/dev/null || true
sudo mv /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.bak 2>/dev/null || true

# Calculate DHCP range (start and end)
DHCP_START="${NETWORK_ADDR}.50"
DHCP_END="${NETWORK_ADDR}.150"

# Configure dnsmasq (DHCP server)
sudo cat > /etc/dnsmasq.conf << EOF
interface=wlan0
dhcp-range=$DHCP_START,$DHCP_END,255.255.255.0,24h
dhcp-option=3,$STATIC_IP
dhcp-option=6,$STATIC_IP
server=8.8.8.8
log-queries
log-dhcp
listen-address=$STATIC_IP
EOF

# Configure hostapd (Access Point)
if [ -z "$PASSWORD" ]; then
    # Open network (no password)
    sudo cat > /etc/hostapd/hostapd.conf << EOF
interface=wlan0
driver=nl80211
ssid=$SSID
hw_mode=g
channel=7
wmm_enabled=1
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
EOF
else
    # Secure network (with password)
    sudo cat > /etc/hostapd/hostapd.conf << EOF
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
fi

# Point hostapd to config file
sudo sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

# Enable IP forwarding for internet sharing (optional)
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sysctl -p

# Set up NAT if eth0 is connected (optional internet sharing)
# Check if iptables is available, if not install it
if ! command -v iptables &> /dev/null; then
    sudo apt install -y iptables
fi

# Add iptables rule for NAT
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true

# Save iptables rules (different methods for different systems)
if command -v iptables-save &> /dev/null; then
    sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"
    
    # Add iptables restore to rc.local
    sudo sed -i '/^exit 0/d' /etc/rc.local 2>/dev/null || true
    sudo sed -i '/iptables-restore/d' /etc/rc.local 2>/dev/null || true
    if ! grep -q "iptables-restore" /etc/rc.local 2>/dev/null; then
        sudo sed -i '/^# Print the IP address/i iptables-restore < /etc/iptables.ipv4.nat\n' /etc/rc.local 2>/dev/null || true
    fi
    echo "exit 0" | sudo tee -a /etc/rc.local > /dev/null
else
    # Alternative method using netfilter-persistent
    sudo apt install -y iptables-persistent
    sudo netfilter-persistent save
fi

# Set hostname
echo "$HOSTNAME" | sudo tee /etc/hostname > /dev/null
sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME/" /etc/hosts

# Update /etc/hosts for the static IP
if ! grep -q "$STATIC_IP" /etc/hosts; then
    echo "$STATIC_IP    $HOSTNAME.local" | sudo tee -a /etc/hosts > /dev/null
fi

# Enable and start services
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq

# Display summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Hostname: ${GREEN}$HOSTNAME${NC}"
echo -e "Pi IP Address: ${GREEN}$STATIC_IP${NC}"
echo -e "Wi-Fi SSID: ${GREEN}$SSID${NC}"
if [ -z "$PASSWORD" ]; then
    echo -e "Wi-Fi Security: ${YELLOW}Open Network (No Password)${NC}"
else
    echo -e "Wi-Fi Password: ${GREEN}$PASSWORD${NC}"
fi
echo -e "\nSSH Access:"
echo -e "  ${GREEN}ssh $HOSTNAME@$HOSTNAME.local${NC}"
echo -e "  ${GREEN}ssh $HOSTNAME@$STATIC_IP${NC}"
echo -e "\n${YELLOW}Rebooting in 10 seconds...${NC}"
echo -e "${YELLOW}After reboot, connect to Wi-Fi: $SSID${NC}"

# Countdown
for i in {10..1}; do
    echo -ne "\rRebooting in $i seconds... "
    sleep 1
done
echo -e "\n${GREEN}Rebooting now...${NC}"
sudo reboot
