#!/bin/bash
# One-line installer for Raspberry Pi
# Usage: curl -sSL https://raw.githubusercontent.com/ceej1014/whatinthePI/main/auto_setup.sh | bash

set -e

echo "========================================="
echo "Raspberry Pi Auto Setup"
echo "========================================="

# Clone the repository if not already present
if [ ! -d "whatinthePI" ]; then
    echo "Cloning repository..."
    git clone https://github.com/ceej1014/whatinthePI.git
    cd whatinthePI
else
    cd whatinthePI
    echo "Repository already exists, updating..."
    git pull
fi

# Make all scripts executable
chmod +x raspi-ap-setup/setup_ap.sh
chmod +x wifi_manager/wifi_manager.sh
chmod +x auto-setup/*.sh 2>/dev/null || true

# Ask what to install
echo ""
echo "What would you like to do?"
echo "1) Setup Access Point (AP Mode)"
echo "2) Install Wi-Fi Manager only"
echo "3) Run complete auto-setup with defaults"
echo "4) Exit"
read -p "Choose [1-4]: " choice

case $choice in
    1)
        cd raspi-ap-setup
        sudo ./setup_ap.sh
        ;;
    2)
        echo "Wi-Fi Manager installed at: $(pwd)/wifi_manager/wifi_manager.sh"
        echo "Run with: sudo ./wifi_manager/wifi_manager.sh"
        ;;
    3)
        cd auto-setup
        sudo ./first_boot_setup.sh
        ;;
    4)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac
