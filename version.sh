#!/bin/bash
# Version information for whatinthePI

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   whatinthePI - Version Information${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

cd ~/whatinthePI 2>/dev/null || cd /home/pi/whatinthePI 2>/dev/null

if [ -d ".git" ]; then
    echo -e "${YELLOW}Repository Info:${NC}"
    echo -e "  Version:    $(git describe --tags 2>/dev/null || echo 'v1.0.0')"
    echo -e "  Commit:     $(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
    echo -e "  Date:       $(git log -1 --format=%cd --date=format:'%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'unknown')"
    echo -e "  Branch:     $(git branch --show-current 2>/dev/null || echo 'main')"
    echo ""
    echo -e "${YELLOW}Latest Changes:${NC}"
    git log -3 --oneline 2>/dev/null || echo "  No git history"
else
    echo -e "${RED}Not a git repository${NC}"
    echo -e "  Installed from: GitHub"
    echo -e "  To enable updates: git clone https://github.com/ceej1014/whatinthePI.git"
fi

echo ""
echo -e "${BLUE}Installed Tools:${NC}"
echo -e "  ✅ auto_setup.sh"
echo -e "  ✅ welcome.sh"
echo -e "  ✅ help.sh"
echo -e "  ✅ quickref.sh"
echo -e "  ✅ status.sh"
echo -e "  ✅ wifi_helper.sh"
echo -e "  ✅ raspi-ap-setup/setup_ap.sh"
echo -e "  ✅ wifi_manager/wifi_manager.sh"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "To update: ${YELLOW}curl -sSL https://raw.githubusercontent.com/ceej1014/whatinthePI/main/update.sh | bash${NC}"
echo -e "${GREEN}========================================${NC}"
