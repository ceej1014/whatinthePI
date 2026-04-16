#!/bin/bash
# Raspberry Pi 4B - Working Access Point Setup
# Compatible with Raspberry Pi OS (Bullseye/Bookworm)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Raspberry Pi 4B Access Point Setup${NC}"
echo -e "${GREEN}========================================${NC}"

# Default values
DEFAULT_HOSTNAME="ceejay"
DEFAULT_IP="192.168.50.1"
DEFAULT_SSID="RPi_Network"
DEFAULT_PASSWORD="raspberry123"

# Get user input
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

# Validate password length
if [ ${#PASSWORD} -lt 8 ] && [ -n "$PASSWORD" ]; then
    echo -e "${RED}Password must be at least 8 characters!${NC}"
    exit 1
fi

# Confirm
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

# ============================================
# Step 1: Update system
# ============================================
echo -e "\n${GREEN}[1/8] Updating system...${NC}"
sudo apt update

# ============================================
# Step 2: Install required packages
# ============================================
echo -e "\n${GREEN}[2/8] Installing packages...${NC}"
sudo apt install -y hostapd dnsmasq iptables

# ============================================
# Step 3: Stop services for configuration
# ============================================
echo -e "\n${GREEN}[3/8] Stopping services...${NC}"
sudo systemctl stop hostapd 2>/dev/null || true
sudo systemctl stop dnsmasq 2>/dev/null || true
sudo systemctl stop wpa_supplicant 2>/dev/null || true

# ============================================
# Step 4: Configure static IP
# ============================================
echo -e "\n${GREEN}[4/8] Configuring static IP...${NC}"

# Backup dhcpcd.conf
sudo cp /etc/dhcpcd.conf /etc/dhcpcd.conf.bak 2>/dev/null || true

# Remove any existing wlan0 configuration
sudo sed -i '/^interface wlan0/,/^$/d' /etc/dhcpcd.conf

# Add new configuration
sudo cat >> /etc/dhcpcd.conf << EOF

# Access Point configuration
interface wlan0
    static ip_address=$STATIC_IP/24
    nohook wpa_supplicant
EOF

# ============================================
# Step 5: Configure dnsmasq (DHCP server)
# ============================================
echo -e "\n${GREEN}[5/8] Configuring DHCP server...${NC}"

# Backup and create new config
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.bak 2>/dev/null || true

NETWORK_PREFIX=$(echo $STATIC_IP | cut -d. -f1-3)

sudo cat > /etc/dnsmasq.conf << EOF
# DHCP server for access point
interface=wlan0
dhcp-range=${NETWORK_PREFIX}.50,${NETWORK_PREFIX}.150,255.255.255.0,24h
dhcp-option=3,$STATIC_IP
dhcp-option=6,$STATIC_IP
server=8.8.8.8
server=8.8.4.4
log-queries
log-dhcp
EOF

# ============================================
# Step 6: Configure hostapd (Access Point)
# ============================================
echo -e "\n${GREEN}[6/8] Configuring access point...${NC}"

# Backup and create new config
sudo mv /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.bak 2>/dev/null || true

sudo cat > /etc/hostapd/hostapd.conf << EOF
# Access Point configuration
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

# Tell hostapd where config is
sudo sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

# ============================================
# Step 7: Enable IP forwarding and NAT
# ============================================
echo -e "\n${GREEN}[7/8] Setting up IP forwarding...${NC}"

# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

# Set up NAT (internet sharing)
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true
sudo iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE 2>/dev/null || true

# Save iptables rules
sudo mkdir -p /etc/iptables
sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null

# Create restore script
sudo cat > /etc/network/if-pre-up.d/iptables << 'EOF'
#!/bin/sh
/sbin/iptables-restore < /etc/iptables/rules.v4
EOF
sudo chmod +x /etc/network/if-pre-up.d/iptables

# ============================================
# Step 8: Set hostname and enable services
# ============================================
echo -e "\n${GREEN}[8/8] Finalizing setup...${NC}"

# Set hostname
echo "$HOSTNAME" | sudo tee /etc/hostname > /dev/null

# Update hosts file
if grep -q "127.0.1.1" /etc/hosts; then
    sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME/" /etc/hosts
else
    echo "127.0.1.1	$HOSTNAME" | sudo tee -a /etc/hosts
fi

# Disable wpa_supplicant (conflicts with hostapd)
sudo systemctl disable wpa_supplicant 2>/dev/null || true
sudo systemctl mask wpa_supplicant 2>/dev/null || true

# Enable and start services
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq

# Restart networking
sudo systemctl restart dhcpcd

# ============================================
# Done!
# ============================================
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Hostname:  ${GREEN}$HOSTNAME${NC}"
echo -e "AP IP:     ${GREEN}$STATIC_IP${NC}"
echo -e "SSID:      ${GREEN}$SSID${NC}"
echo -e "Password:  ${GREEN}$PASSWORD${NC}"
echo ""
echo -e "${YELLOW}After reboot, you'll see a new Wi-Fi network:${NC}"
echo -e "  ${GREEN}$SSID${NC}"
echo ""
echo -e "SSH access after reboot:"
echo -e "  ${GREEN}ssh $HOSTNAME@$HOSTNAME.local${NC}"
echo -e "  ${GREEN}ssh $HOSTNAME@$STATIC_IP${NC}"
echo ""
echo -e "${YELLOW}Rebooting in 10 seconds...${NC}"

for i in {10..1}; do
    echo -ne "\rRebooting in $i seconds... "
    sleep 1
done

sudo reboot
