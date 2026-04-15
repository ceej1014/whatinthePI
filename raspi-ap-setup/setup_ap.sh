#!/bin/bash

# Raspberry Pi 4B - Create own network access point
# SSH will be available at ceejay.local or 1.2.1.1

set -e

echo "Setting up Raspberry Pi as standalone access point..."

# Update system
sudo apt update
sudo apt upgrade -y

# Install required packages
sudo apt install -y hostapd dnsmasq

# Stop services while configuring
sudo systemctl stop hostapd
sudo systemctl stop dnsmasq

# Configure static IP for wlan0
sudo cat > /etc/dhcpcd.conf << 'EOF'
# Custom static IP for access point
interface wlan0
    static ip_address=1.2.1.1/24
    nohook wpa_supplicant
EOF

# Backup original configs if they exist
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.bak 2>/dev/null || true
sudo mv /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.bak 2>/dev/null || true

# Configure dnsmasq (DHCP server)
sudo cat > /etc/dnsmasq.conf << 'EOF'
interface=wlan0
dhcp-range=1.2.1.50,1.2.1.150,255.255.255.0,24h
dhcp-option=3,1.2.1.1
dhcp-option=6,1.2.1.1
server=8.8.8.8
log-queries
log-dhcp
listen-address=1.2.1.1
EOF

# Configure hostapd (Access Point) with new SSID and password
sudo cat > /etc/hostapd/hostapd.conf << 'EOF'
interface=wlan0
driver=nl80211
ssid=raspi_cj
hw_mode=g
channel=7
wmm_enabled=1
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=gwaposicj245
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

# Point hostapd to config file
sudo sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

# Enable IP forwarding for internet sharing (optional)
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

# Set up NAT if eth0 is connected (optional internet sharing)
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"

# Add iptables restore to rc.local
sudo sed -i '/^exit 0/d' /etc/rc.local
sudo sed -i '/iptables-restore/d' /etc/rc.local
sudo sed -i '/^# Print the IP address/i iptables-restore < /etc/iptables.ipv4.nat\n' /etc/rc.local
echo "exit 0" | sudo tee -a /etc/rc.local

# Ensure hostname is set correctly
echo "ceejay" | sudo tee /etc/hostname
sudo sed -i 's/127.0.1.1.*/127.0.1.1\tceejay/' /etc/hosts

# Enable and start services
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq

# Reboot to apply changes
echo "Setup complete! Rebooting in 5 seconds..."
echo "After reboot, connect to Wi-Fi: raspi_cj"
echo "Password: gwaposicj245"
echo "Then SSH to: ssh ceej@ceejay.local or ssh ceej@1.2.1.1"
sleep 5
sudo reboot
