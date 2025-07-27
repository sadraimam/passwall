#!/bin/bash

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Configuring timezone to Asia/Tehran...${NC}"
sleep 1

uci set system.@system[0].zonename='Asia/Tehran'
uci set system.@system[0].timezone='<+0330>-3:30'
uci commit
/sbin/reload_config

cp passwallx.sh /sbin/passwall 2>/dev/null

clear
. /etc/openwrt_release

# Banner
echo -e "${YELLOW}
 _____ _____ _____ _____ _ _ _ _____ __    __
|  _  |  _  |   __|   __| | | |  _  |  |  |  |
|   __|     |__   |__   | | | |     |  |__|  |__
|__|  |__|__|_____|_____|_____|__|__|_____|_____|
${NC}"

# System Info
EPOL=$(cat /tmp/sysinfo/model)
echo -e "${GRAY} - Model       : ${NC}$EPOL"
echo -e "${GRAY} - OS Version  : ${NC}$DISTRIB_RELEASE"
echo -e "${GRAY} - Architecture: ${NC}$DISTRIB_ARCH"
echo ""

# Check installed versions
has_passwall=false
has_passwall2=false

[ -f /etc/init.d/passwall ] && has_passwall=true
[ -f /etc/init.d/passwall2 ] && has_passwall2=true

# Menu options
echo -e "${YELLOW}1.${NC} ${CYAN}Install Passwall v1${NC}"
echo -e "${YELLOW}2.${NC} ${CYAN}Install Passwall v2 - requires ≥256MB RAM${NC}"
echo -e "${YELLOW}3.${NC} ${CYAN}Install Passwall v2 + Mahsa Core${NC}"
$has_passwall && echo -e "${YELLOW}4.${NC} ${CYAN}Update Passwall v1${NC}"
$has_passwall2 && echo -e "${YELLOW}5.${NC} ${CYAN}Update Passwall v2${NC}"
echo -e "${YELLOW}9.${NC} ${CYAN}Install Cloudflare IP Scanner${NC}"
echo -e "${YELLOW}6.${NC} ${RED}Exit${NC}"
echo ""

# User Input
read -p " - Select an option: " choice

case $choice in
1)
    echo -e "${GREEN}Installing Passwall v1...${NC}"
    sleep 1
    rm -f passwall.sh
    wget https://raw.githubusercontent.com/sadraimam/passwall/main/passwall.sh
    chmod +x passwall.sh
    sh passwall.sh
    ;;
2)
    echo -e "${GREEN}Installing Passwall v2...${NC}"
    sleep 1
    rm -f passwall2x.sh
    wget https://raw.githubusercontent.com/sadraimam/passwall/main/passwall2x.sh
    chmod +x passwall2x.sh
    sh passwall2x.sh
    ;;
3)
    echo -e "${GREEN}Installing Passwall v2 + Mahsa Core...${NC}"
    sleep 1
    rm -f mahsa.sh
    wget https://raw.githubusercontent.com/sadraimam/passwall/main/mahsa.sh
    chmod +x mahsa.sh
    sh mahsa.sh
    ;;
4)
    if $has_passwall; then
        echo -e "${GREEN}Updating Passwall v1...${NC}"
        opkg update
        opkg install luci-app-passwall
    else
        echo -e "${RED}Passwall v1 is not installed.${NC}"
    fi
    ;;
5)
    if $has_passwall2; then
        echo -e "${GREEN}Updating Passwall v2...${NC}"
        opkg update
        opkg install luci-app-passwall2
    else
        echo -e "${RED}Passwall v2 is not installed.${NC}"
    fi
    ;;
9)
    echo -e "${GREEN}Installing Cloudflare IP Scanner...${NC}"
    opkg update
    opkg install bash curl
    curl -ksSL https://gitlab.com/rwkgyg/cdnopw/raw/main/cdnopw.sh -o cdnopw.sh
    bash cdnopw.sh
    ;;
6)
    echo -e "${GREEN}Exiting...${NC}"
    exit 0
    ;;
*)
    echo -e "${RED}Invalid option selected!${NC}"
    ;;
esac
