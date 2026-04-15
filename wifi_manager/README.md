# Raspberry Pi Wi-Fi Manager

An interactive Bash script that gives you complete control over Wi-Fi on your Raspberry Pi. Scan, connect, disconnect, turn Wi-Fi on/off, manage saved networks, and switch between client and access point modes.

## Features

- **Scan Networks** - View all available Wi-Fi networks with signal strength
- **Connect to Networks** - Support for both open and password-protected networks
- **Disconnect** - Disconnect from current network
- **Power Control** - Turn Wi-Fi hardware ON or OFF
- **Connection Details** - View SSID, IP address, MAC, signal strength, and frequency
- **Network Management** - Forget saved networks or list all saved networks
- **Mode Switching** - Switch between client mode and access point (AP) mode
- **Auto-save** - Automatically saves networks for future connections

## Quick Start

```bash
git clone https://github.com/ceej1014/whatinthePI.git
cd whatinthePI
chmod +x wifi_manager.sh
sudo ./wifi_manager.sh
