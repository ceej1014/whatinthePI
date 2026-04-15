# Raspberry Pi 4B Dynamic Access Point Setup

An interactive script that turns your Raspberry Pi 4B into a customizable Wi-Fi access point. Set your own IP address, Wi-Fi name, password (or open network), and hostname.

## Features

- **Dynamic Configuration** - Interactive prompts for all settings
- **Custom IP Address** - Choose any static IP for your Pi
- **Custom Wi-Fi Name** - Set any SSID you want
- **Flexible Security** - Password-protected or open network
- **Custom Hostname** - Change the Pi's hostname easily
- **DHCP Server** - Automatically assigns IPs to connected devices
- **Internet Sharing** - Optional NAT sharing via ethernet

## Quick Start

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
cd YOUR_REPO_NAME/raspi-ap-setup
chmod +x setup_ap.sh
sudo ./setup_ap.sh
