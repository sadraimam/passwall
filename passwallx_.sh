#!/bin/sh

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Set timezone
echo -e "${YELLOW}Configuring timezone to Asia/Tehran...${NC}"
uci set system.@system[0].zonename='Asia/Tehran'
uci set system.@system[0].timezone='<+0330>-3:30'
uci commit
/sbin/reload_config

# Optional alias
cp passwallx.sh /sbin/passwall 2>/dev/null

# Clear screen
clear

# Get system info
. /etc/openwrt_release
MODEL="$(cat /tmp/sysinfo/model)"
VERSION="$DISTRIB_RELEASE"
ARCH="$DISTRIB_ARCH"

# Display banner
echo -e "${YELLOW}
 _____ _____ _____ _____ _ _ _ _____ __    __
|  _  |  _  |   __|   __| | | |  _  |  |  |  |
|   __|     |__   |__   | | | |     |  |__|  |__
|__|  |__|__|_____|_____|_____|__|__|_____|_____|
${NC}"
echo -e "${GRAY} - Model       : ${NC}${MODEL}"
echo -e "${GRAY} - OS Version  : ${NC}${VERSION}"
echo -e "${GRAY} - Architecture: ${NC}${ARCH}"
echo ""

# Display menu
echo -e "${YELLOW}1.${NC} ${CYAN}Install Passwall v1${NC}"
echo -e "${YELLOW}2.${NC} ${CYAN}Install Passwall v2 - requires ≥256MB RAM${NC}"
echo -e "${YELLOW}3.${NC} ${CYAN}Install Passwall v2 + Mahsa Core${NC}"

if [ -f /etc/init.d/passwall ]; then
    echo -e "${YELLOW}4.${NC} ${CYAN}Update Passwall v1${NC}"
fi

if [ -f /etc/init.d/passwall2 ]; then
    echo -e "${YELLOW}5.${NC} ${CYAN}Update Passwall v2${NC}"
fi

echo -e "${YELLOW}9.${NC} ${CYAN}Install Cloudflare IP Scanner${NC}"
echo -e "${YELLOW}6.${NC} ${RED}Exit${NC}"
echo ""

# Prompt for input
printf " - Select an option: "
read choice

# Handle menu choice
case "$choice" in
    1)
        echo -e "${GREEN}Installing Passwall v1...${NC}"
        rm -f passwall.sh
        wget -q --show-progress https://raw.githubusercontent.com/sadraimam/passwall/main/passwall.sh
        chmod +x passwall.sh
        sh passwall.sh
        ;;
    2)
        echo -e "${GREEN}Installing Passwall v2...${NC}"
        rm -f passwall2x.sh
        wget -q --show-progress https://raw.githubusercontent.com/sadraimam/passwall/main/passwall2x.sh
        chmod +x passwall2x.sh
        sh passwall2x.sh
        ;;
    3)
        echo -e "${GREEN}Installing Passwall v2 + Mahsa Core...${NC}"
        rm -f mahsa.sh
        wget -q --show-progress https://raw.githubusercontent.com/sadraimam/passwall/main/mahsa.sh
        chmod +x mahsa.sh
        sh mahsa.sh
        ;;
    4)
        if [ -f /etc/init.d/passwall ]; then
            echo -e "${GREEN}Updating Passwall v1...${NC}"
            opkg update
            opkg install luci-app-passwall
        else
            echo -e "${RED}Passwall v1 not installed.${NC}"
        fi
        ;;
    5)
        if [ -f /etc/init.d/passwall2 ]; then
            echo -e "${GREEN}Updating Passwall v2...${NC}"
            opkg update
            opkg install luci-app-passwall2
        else
            echo -e "${RED}Passwall v2 not installed.${NC}"
        fi
        ;;
    9)
        echo -e "${GREEN}Installing Cloudflare IP Scanner...${NC}"
        opkg update
        opkg install bash curl
        curl -ksSL https://gitlab.com/rwkgyg/cdnopw/raw/main/cdnopw.sh -o cdnopw.sh
        sh cdnopw.sh
        ;;
    6)
        echo -e "${GREEN}Goodbye.${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option.${NC}"
        ;;
esac
