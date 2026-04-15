#!/bin/bash
# Interactive installer for Raspberry Pi

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Raspberry Pi Tools Installer${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (sudo ./install.sh)${NC}"
    exit 1
fi

# Create installation directory
INSTALL_DIR="/opt/whatinthePI"
mkdir -p $INSTALL_DIR

# Copy scripts
echo "Copying scripts to $INSTALL_DIR..."
cp -r ../raspi-ap-setup $INSTALL_DIR/
cp -r ../wifi_manager $INSTALL_DIR/

# Make executables
chmod +x $INSTALL_DIR/raspi-ap-setup/setup_ap.sh
chmod +x $INSTALL_DIR/wifi_manager/wifi_manager.sh

# Create symlinks
ln -sf $INSTALL_DIR/wifi_manager/wifi_manager.sh /usr/local/bin/wifiman
ln -sf $INSTALL_DIR/raspi-ap-setup/setup_ap.sh /usr/local/bin/apsetup

echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo "You can now run:"
echo "  sudo wifiman  - Wi-Fi Manager"
echo "  sudo apsetup  - AP Setup"
echo ""
echo "Or run AP setup now? (y/n)"
read -r run_ap
if [[ $run_ap == "y" ]]; then
    apsetup
fi
