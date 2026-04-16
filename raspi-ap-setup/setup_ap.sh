#!/bin/bash

# Raspberry Pi 4B - Dynamic Access Point Setup
# Specifically for Raspberry Pi OS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Detect if running interactively
if [ -t 0 ] && [ -t 1 ]; then
    INTERACTIVE=true
else
    INTERACTIVE=false
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Raspberry Pi 4B Dynamic Access Point Setup${NC}"
echo -e "${GREEN}========================================${NC}"

# Set default values
DEFAULT_HOSTNAME="ceejay"
DEFAULT_IP="1.2.1.1"
DEFAULT_SSID="raspi_cj"
DEFAULT_PASSWORD="gwaposicj245"

if [ "$INTERACTIVE" = true ]; then
    echo -e "${YELLOW}Press Enter to use default values in brackets${NC}\n"

    read -p "Enter hostname [$DEFAULT_HOSTNAME]: " HOSTNAME
    HOSTNAME=${HOSTNAME:-$DEFAULT_HOSTNAME}

    read -p "Enter static IP address for the Pi [$DEFAULT_IP]: " STATIC_IP
    STATIC_IP=${STATIC_IP:-$DEFAULT_IP}

    if ! [[ $STATIC_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}Invalid IP address format! Using default: $DEFAULT_IP${NC}"
        STATIC_IP=$DEFAULT_IP
    fi

    read -p "Enter Wi-Fi network name (SSID) [$DEFAULT_SSID]: " SSID
    SSID=${SSID:-$DEFAULT_SSID}

    read -p "Enter Wi-Fi password (leave blank for open network): " PASSWORD

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
else
    echo -e "${YELLOW}Non-interactive mode detected. Using default values:${NC}"
    HOSTNAME="$DEFAULT_HOSTNAME"
    STATIC_IP="$DEFAULT_IP"
    SSID="$DEFAULT_SSID"
    PASSWORD="$DEFAULT_PASSWORD"
    echo -e "  Hostname: ${GREEN}$HOSTNAME${NC}"
    echo -e "  IP Address: ${GREEN}$STATIC_IP${NC}"
    echo -e "  SSID: ${GREEN}$SSID${NC}"
    echo -e "  Password: ${GREEN}$PASSWORD${NC}"
    echo ""
    sleep 3
fi

echo -e "\n${GREEN}Setting up Raspberry Pi as access point...${NC}"

# Update system
sudo apt update || true

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

# Backup original configs
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.bak 2>/dev/null || true
sudo mv /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.bak 2>/dev/null || true

# Calculate network address
NETWORK_ADDR=$(echo $STATIC_IP | cut -d. -f1-3)
DHCP_START="${NETWORK_ADDR}.50"
DHCP_END="${NETWORK_ADDR}.150"

# Configure dnsmasq
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

# Configure hostapd
if [ -z "$PASSWORD" ]; then
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

# Enable IP forwarding - Raspberry Pi OS specific
# On Raspberry Pi OS, sysctl settings go in /etc/sysctl.d/ instead
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-ipforward.conf

# Set up NAT
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true

# Save iptables rules (Raspberry Pi OS method)
sudo mkdir -p /etc/iptables
sudo iptables-save | sudo tee /etc/iptables/iptables-rules > /dev/null

# Create script to restore rules on boot
sudo cat > /etc/network/if-pre-up.d/iptables << 'EOF'
#!/bin/sh
/sbin/iptables-restore < /etc/iptables/iptables-rules
EOF
sudo chmod +x /etc/network/if-pre-up.d/iptables

# Set hostname
echo "$HOSTNAME" | sudo tee /etc/hostname > /dev/null
if grep -q "127.0.1.1" /etc/hosts; then
    sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME/" /etc/hosts
else
    echo "127.0.1.1	$HOSTNAME" | sudo tee -a /etc/hosts
fi

# Enable and start services
sudo systemctl unmask hostapd 2>/dev/null || true
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq

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

for i in {10..1}; do
    echo -ne "\rRebooting in $i seconds... "
    sleep 1
done
echo -e "\n${GREEN}Rebooting now...${NC}"
sudo reboot
