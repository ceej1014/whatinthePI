#!/bin/bash

# ============================================
# setup_ap.sh - Create a Wi-Fi Access Point
# Uses nmcli (NetworkManager)
# Works on Raspberry Pi 4B and other Linux
# ============================================

# Default values (can be overridden by command line arguments)
DEFAULT_SSID="RPi_Hotspot"
DEFAULT_PASSWORD="raspberry"
INTERFACE="wlan0"

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_ok() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${YELLOW}→${NC} $1"; }

# Show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Setup a Wi-Fi Access Point on $INTERFACE"
    echo ""
    echo "Options:"
    echo "  -s, --ssid SSID        Set hotspot SSID (default: $DEFAULT_SSID)"
    echo "  -p, --password PASS    Set hotspot password (min 8 chars, default: $DEFAULT_PASSWORD)"
    echo "  -i, --interface IFACE  Wi-Fi interface (default: $INTERFACE)"
    echo "  -d, --delete           Delete the hotspot profile (turn off AP)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                 # Create hotspot with defaults"
    echo "  $0 -s MyNetwork -p mysecret123     # Custom SSID and password"
    echo "  $0 --delete                        # Remove hotspot"
}

# Function to delete hotspot profile
delete_hotspot() {
    print_info "Deleting hotspot profile..."
    if nmcli connection show | grep -q "Hotspot"; then
        sudo nmcli connection delete Hotspot
        print_ok "Hotspot profile removed"
    else
        print_info "No hotspot profile found"
    fi
    # Also disconnect any active hotspot connection
    sudo nmcli connection down Hotspot 2>/dev/null
    sudo nmcli device disconnect "$INTERFACE" 2>/dev/null
    print_ok "AP mode stopped"
}

# Function to create and start hotspot
create_hotspot() {
    local SSID="$1"
    local PASS="$2"
    
    print_info "Setting up Access Point on $INTERFACE with SSID: $SSID"
    
    # 1. Ensure Wi-Fi radio is on
    print_info "Turning Wi-Fi radio on..."
    nmcli radio wifi on
    
    # 2. Disconnect any current connection on the interface
    print_info "Cleaning up existing connections on $INTERFACE..."
    sudo nmcli device disconnect "$INTERFACE" 2>/dev/null
    sudo nmcli connection down "$INTERFACE" 2>/dev/null
    
    # 3. Remove any stale hotspot profile
    if nmcli connection show | grep -q "Hotspot"; then
        print_info "Removing old hotspot profile..."
        sudo nmcli connection delete Hotspot
    fi
    
    # 4. Create new hotspot profile
    print_info "Creating hotspot profile..."
    if ! sudo nmcli connection add type wifi ifname "$INTERFACE" \
        con-name Hotspot autoconnect no ssid "$SSID"; then
        print_error "Failed to add connection profile"
        return 1
    fi
    
    # 5. Configure AP mode settings
    print_info "Configuring AP settings..."
    sudo nmcli connection modify Hotspot 802-11-wireless.mode ap
    sudo nmcli connection modify Hotspot 802-11-wireless.band bg
    sudo nmcli connection modify Hotspot wifi-sec.key-mgmt wpa-psk
    sudo nmcli connection modify Hotspot wifi-sec.psk "$PASS"
    sudo nmcli connection modify Hotspot ipv4.method shared
    sudo nmcli connection modify Hotspot ipv4.addresses 192.168.4.1/24
    
    # 6. Bring up the hotspot
    print_info "Starting hotspot..."
    if sudo nmcli connection up Hotspot; then
        print_ok "AP Mode is ACTIVE"
        echo ""
        echo "========================================="
        echo "  Hotspot Details:"
        echo "  SSID      : $SSID"
        echo "  Password  : $PASS"
        echo "  Interface : $INTERFACE"
        echo "  IP Address: 192.168.4.1"
        echo "========================================="
        echo ""
        print_info "Other devices can now connect to this hotspot"
        return 0
    else
        print_error "Failed to start AP mode"
        print_error "Check that $INTERFACE is available and not blocked"
        return 1
    fi
}

# Parse command line arguments
SSID="$DEFAULT_SSID"
PASSWORD="$DEFAULT_PASSWORD"
DELETE_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--ssid)
            SSID="$2"
            shift 2
            ;;
        -p|--password)
            PASSWORD="$2"
            shift 2
            ;;
        -i|--interface)
            INTERFACE="$2"
            shift 2
            ;;
        -d|--delete)
            DELETE_MODE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate password length (if not in delete mode)
if [ "$DELETE_MODE" = false ]; then
    if [ ${#PASSWORD} -lt 8 ] && [ ${#PASSWORD} -gt 0 ]; then
        print_error "Password must be at least 8 characters long"
        exit 1
    fi
    # If password is empty? Default is set, but user could set empty. We'll allow empty? No, WPA needs a password.
    if [ -z "$PASSWORD" ]; then
        print_error "Password cannot be empty for WPA2 security"
        exit 1
    fi
fi

# Check if nmcli is available
if ! command -v nmcli &> /dev/null; then
    print_error "nmcli not found. Please install NetworkManager: sudo apt install network-manager"
    exit 1
fi

# Check if interface exists
if ! ip link show "$INTERFACE" &> /dev/null; then
    print_error "Network interface $INTERFACE does not exist"
    exit 1
fi

# Main action
if [ "$DELETE_MODE" = true ]; then
    delete_hotspot
else
    create_hotspot "$SSID" "$PASSWORD"
fi

exit 0
