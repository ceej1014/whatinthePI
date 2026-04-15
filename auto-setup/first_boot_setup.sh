#!/bin/bash
# Runs automatically on first boot
# To enable: Add to /etc/rc.local or create systemd service

set -e

LOG_FILE="/boot/setup_log.txt"
exec > >(tee -a $LOG_FILE)
exec 2>&1

echo "========================================="
echo "First Boot Auto Setup - $(date)"
echo "========================================="

# Configuration (EDIT THESE VALUES)
DEFAULT_HOSTNAME="ceejay"
DEFAULT_IP="1.2.1.1"
DEFAULT_SSID="raspi_cj"
DEFAULT_PASSWORD="gwaposicj245"

# Check if already setup
if [ -f "/boot/.setup_complete" ]; then
    echo "Setup already completed. Exiting."
    exit 0
fi

# Update system
echo "Updating system..."
apt update
apt upgrade -y

# Install required packages
echo "Installing packages..."
apt install -y git hostapd dnsmasq

# Clone repository if not exists
if [ ! -d "/home/pi/whatinthePI" ]; then
    echo "Cloning repository..."
    cd /home/pi
    git clone https://github.com/ceej1014/whatinthePI.git
fi

# Make scripts executable
chmod +x /home/pi/whatinthePI/raspi-ap-setup/setup_ap.sh
chmod +x /home/pi/whatinthePI/wifi_manager/wifi_manager.sh

# Create aliases for easy access
cat > /home/pi/.bash_aliases << 'EOF'
alias wifiman='sudo /home/pi/whatinthePI/wifi_manager/wifi_manager.sh'
alias apsetup='sudo /home/pi/whatinthePI/raspi-ap-setup/setup_ap.sh'
alias apoff='sudo systemctl stop hostapd dnsmasq && sudo systemctl restart wpa_supplicant'
alias apon='cd /home/pi/whatinthePI/raspi-ap-setup && sudo ./setup_ap.sh'
EOF

chown pi:pi /home/pi/.bash_aliases
echo "source /home/pi/.bash_aliases" >> /home/pi/.bashrc

# Ask or use defaults
if [ -f "/boot/setup.conf" ]; then
    source /boot/setup.conf
else
    HOSTNAME=${DEFAULT_HOSTNAME}
    STATIC_IP=${DEFAULT_IP}
    SSID=${DEFAULT_SSID}
    PASSWORD=${DEFAULT_PASSWORD}
fi

# Run AP setup with defaults
echo "Running AP setup..."
cd /home/pi/whatinthePI/raspi-ap-setup
echo -e "$HOSTNAME\n$STATIC_IP\n$SSID\n$PASSWORD\ny\n" | sudo ./setup_ap.sh

# Mark setup as complete
touch /boot/.setup_complete

echo "Setup complete! Log saved to $LOG_FILE"
echo "Rebooting in 5 seconds..."
sleep 5
reboot
