#!/bin/bash
# Fully automatic AP setup - no prompts
# Edit the variables below before running

set -e

# ===== CONFIGURATION - EDIT THESE =====
HOSTNAME="ceejay"
STATIC_IP="1.2.1.1"
SSID="raspi_cj"
PASSWORD="gwaposicj245"
# ======================================

echo "Starting automatic AP setup..."

# Set hostname
echo "$HOSTNAME" > /etc/hostname
sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME/" /etc/hosts

# Configure static IP
cat > /etc/dhcpcd.conf << EOF
interface wlan0
    static ip_address=$STATIC_IP/24
    nohook wpa_supplicant
EOF

# Backup existing configs
mv /etc/dnsmasq.conf /etc/dnsmasq.conf.bak 2>/dev/null || true
mv /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.bak 2>/dev/null || true

# Configure dnsmasq
cat > /etc/dnsmasq.conf << EOF
interface=wlan0
dhcp-range=${STATIC_IP%.*}.50,${STATIC_IP%.*}.150,255.255.255.0,24h
dhcp-option=3,$STATIC_IP
dhcp-option=6,$STATIC_IP
server=8.8.8.8
log-queries
log-dhcp
listen-address=$STATIC_IP
EOF

# Configure hostapd
if [ -z "$PASSWORD" ]; then
    # Open network
    cat > /etc/hostapd/hostapd.conf << EOF
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
    # Secure network
    cat > /etc/hostapd/hostapd.conf << EOF
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

# Configure hostapd defaults
sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

# Enable IP forwarding
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

# Enable services
systemctl unmask hostapd
systemctl enable hostapd
systemctl enable dnsmasq

echo "AP Setup complete!"
echo "Hostname: $HOSTNAME"
echo "IP: $STATIC_IP"
echo "SSID: $SSID"
echo "Password: ${PASSWORD:-'No password (open network)'}"
echo ""
echo "Rebooting in 5 seconds..."
sleep 5
reboot
