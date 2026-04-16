#!/bin/bash

# ========================================
# Unified Wi-Fi Manager for Raspberry Pi 4B
# FIXED: AP mode now uses wlan0 correctly
# ========================================

INTERFACE="wlan0"
HOTSPOT_SSID="RPi_Hotspot"
HOTSPOT_PASSWORD="raspberry"

show_status() {
    echo "Current Status:"
    if nmcli radio wifi | grep -q "enabled"; then
        echo "  Wi-Fi Radio: ON"
    else
        echo "  Wi-Fi Radio: OFF"
    fi
    
    CLIENT_CONN=$(nmcli -t -f NAME,DEVICE,STATE connection show --active 2>/dev/null | grep ":${INTERFACE}:")
    if [ -n "$CLIENT_CONN" ]; then
        CLIENT_NAME=$(echo "$CLIENT_CONN" | cut -d: -f1)
        echo "  Client Mode: Connected to '$CLIENT_NAME' on $INTERFACE"
        CLIENT_IP=$(ip -4 addr show "$INTERFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
        echo "  Wi-Fi IP: $CLIENT_IP"
    else
        echo "  Client Mode: NOT connected to any network"
    fi
    
    if nmcli connection show --active 2>/dev/null | grep -q "Hotspot"; then
        AP_IP=$(ip -4 addr show "$INTERFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "192.168.4.1")
        echo "  AP Mode: ACTIVE (Hotspot running, IP: $AP_IP)"
    else
        echo "  AP Mode: INACTIVE"
    fi
    
    ETH_IP=$(ip -4 addr show eth0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "none")
    echo "  Ethernet IP: $ETH_IP"
    echo ""
}

switch_to_client() {
    echo "Switching to Client Mode..."
    if nmcli connection show --active 2>/dev/null | grep -q "Hotspot"; then
        sudo nmcli connection down Hotspot 2>/dev/null
        echo "  Hotspot stopped."
    fi
    sudo nmcli device disconnect "$INTERFACE" 2>/dev/null
    nmcli radio wifi on
    echo "  Client mode ready. Use option 6 to connect to a network."
}

switch_to_ap() {
    echo "Switching to AP Mode..."
    nmcli radio wifi on
    sudo nmcli device disconnect "$INTERFACE" 2>/dev/null
    sudo nmcli connection down Hotspot 2>/dev/null
    if nmcli connection show | grep -q "Hotspot"; then
        sudo nmcli connection delete Hotspot 2>/dev/null
    fi
    
    sudo nmcli connection add type wifi ifname "$INTERFACE" con-name Hotspot autoconnect no ssid "$HOTSPOT_SSID"
    sudo nmcli connection modify Hotspot 802-11-wireless.mode ap
    sudo nmcli connection modify Hotspot 802-11-wireless.band bg
    sudo nmcli connection modify Hotspot wifi-sec.key-mgmt wpa-psk
    sudo nmcli connection modify Hotspot wifi-sec.psk "$HOTSPOT_PASSWORD"
    sudo nmcli connection modify Hotspot ipv4.method shared
    sudo nmcli connection modify Hotspot ipv4.addresses 192.168.4.1/24
    
    if sudo nmcli connection up Hotspot; then
        echo "✓ AP mode enabled. SSID: $HOTSPOT_SSID, Password: $HOTSPOT_PASSWORD"
    else
        echo "✗ Failed to start AP mode. Check that $INTERFACE is available."
    fi
}

configure_hotspot() {
    read -p "Enter new Hotspot SSID [current: $HOTSPOT_SSID]: " new_ssid
    read -p "Enter new Hotspot password (min 8 chars) [current: $HOTSPOT_PASSWORD]: " new_pass
    if [ -n "$new_ssid" ]; then
        HOTSPOT_SSID="$new_ssid"
        if nmcli connection show | grep -q "Hotspot"; then
            sudo nmcli connection modify Hotspot ssid "$HOTSPOT_SSID"
        fi
    fi
    if [ -n "$new_pass" ]; then
        HOTSPOT_PASSWORD="$new_pass"
        if nmcli connection show | grep -q "Hotspot"; then
            sudo nmcli connection modify Hotspot wifi-sec.psk "$HOTSPOT_PASSWORD"
        fi
    fi
    echo "Hotspot settings updated. Will take effect next time you start AP mode."
}

turn_off_ap() {
    if nmcli connection show --active 2>/dev/null | grep -q "Hotspot"; then
        sudo nmcli connection down Hotspot
        echo "AP Mode turned OFF."
    else
        echo "AP Mode was not active."
    fi
    nmcli radio wifi on
    echo "Now in client mode."
}

scan_networks() {
    echo "Scanning for Wi-Fi networks..."
    sudo nmcli device wifi rescan
    sleep 2
    nmcli -f SSID,SIGNAL,SECURITY device wifi list
}

connect_network() {
    read -p "Enter SSID: " SSID
    read -s -p "Enter Password (press Enter if open): " PASSWORD
    echo ""
    sudo nmcli connection delete "$SSID" 2>/dev/null
    if [ -z "$PASSWORD" ]; then
        sudo nmcli device wifi connect "$SSID"
    else
        sudo nmcli device wifi connect "$SSID" password "$PASSWORD"
    fi
    if [ $? -eq 0 ]; then
        echo "Successfully connected to $SSID"
    else
        echo "Connection failed."
    fi
}

wifi_off() {
    nmcli radio wifi off
    echo "Wi-Fi turned OFF."
}

show_details() {
    echo "=== Wi-Fi Radio ==="
    nmcli radio wifi
    echo "=== Active Connections ==="
    nmcli connection show --active
    echo "=== IP Addresses ==="
    ip -4 addr show
    echo "=== NetworkManager Status ==="
    nmcli general status
}

while true; do
    clear
    echo "========================================"
    echo "      Unified Wi-Fi Manager"
    echo "========================================"
    show_status
    echo "Options:"
    echo "1)  Switch to Client Mode (connect to Wi-Fi)"
    echo "2)  Switch to AP Mode (create hotspot)"
    echo "3)  Configure Hotspot (SSID, password)"
    echo "4)  Turn OFF AP Mode (back to client)"
    echo "5)  Scan for networks"
    echo "6)  Connect to a network"
    echo "7)  Turn Wi-Fi OFF"
    echo "8)  Show connection details"
    echo "9)  Exit"
    echo "========================================"
    read -p "Enter your choice [1-9]: " choice
    
    case $choice in
        1) switch_to_client ;;
        2) switch_to_ap ;;
        3) configure_hotspot ;;
        4) turn_off_ap ;;
        5) scan_networks ;;
        6) connect_network ;;
        7) wifi_off ;;
        8) show_details ;;
        9) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid choice."; sleep 2 ;;
    esac
    echo ""
    read -p "Press Enter to continue..."
done
