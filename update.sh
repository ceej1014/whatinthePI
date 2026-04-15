#!/bin/bash
# Update whatinthePI scripts

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   whatinthePI - Update Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Find the installation directory
if [ -d "$HOME/whatinthePI" ]; then
    INSTALL_DIR="$HOME/whatinthePI"
elif [ -d "/home/pi/whatinthePI" ]; then
    INSTALL_DIR="/home/pi/whatinthePI"
else
    echo -e "${RED}Error: whatinthePI not found!${NC}"
    echo "Please install first: curl -sSL https://raw.githubusercontent.com/ceej1014/whatinthePI/main/auto_setup.sh | bash"
    exit 1
fi

cd "$INSTALL_DIR"

# Check if it's a git repository
if [ -d ".git" ]; then
    echo -e "${YELLOW}Checking for updates...${NC}"
    echo ""
    
    # Get current version
    CURRENT_COMMIT=$(git rev-parse --short HEAD)
    echo -e "Current commit: ${BLUE}$CURRENT_COMMIT${NC}"
    
    # Fetch latest
    git fetch origin
    
    # Check if behind
    BEHIND=$(git rev-list HEAD..origin/main --count 2>/dev/null)
    
    if [ "$BEHIND" -gt 0 ]; then
        echo -e "${YELLOW}Updates available! ($BEHIND commit(s) behind)${NC}"
        echo ""
        echo "Files that will be updated:"
        git diff --name-only origin/main
        
        echo ""
        read -p "Update now? (y/n): " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Updating...${NC}"
            git pull
            
            # Make scripts executable again
            chmod +x *.sh 2>/dev/null
            chmod +x raspi-ap-setup/*.sh 2>/dev/null
            chmod +x wifi_manager/*.sh 2>/dev/null
            
            echo -e "${GREEN}✅ Update complete!${NC}"
            echo ""
            echo -e "${YELLOW}Recent changes:${NC}"
            git log -3 --oneline
            echo ""
            echo -e "${BLUE}Please run: source ~/.bashrc${NC}"
        else
            echo -e "${RED}Update cancelled${NC}"
        fi
    else
        echo -e "${GREEN}✅ Already up to date!${NC}"
    fi
else
    echo -e "${RED}Not a git repository. Cannot auto-update.${NC}"
    echo ""
    echo "Please reinstall with:"
    echo "  cd ~"
    echo "  rm -rf whatinthePI"
    echo "  curl -sSL https://raw.githubusercontent.com/ceej1014/whatinthePI/main/auto_setup.sh | bash"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
