#!/bin/sh

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
BLUE='\033[0;34m'
NC='\033[0m'

# Set timezone
uci set system.@system[0].zonename='Asia/Tehran'
uci set system.@system[0].timezone='<+0330>-3:30'
uci commit
/sbin/reload_config

cp passwallx.sh /sbin/passwall 2>/dev/null
clear

. /etc/openwrt_release
MODEL="$(cat /tmp/sysinfo/model)"
VERSION="$DISTRIB_RELEASE"
ARCH="$DISTRIB_ARCH"

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

echo -e "${YELLOW}1.${NC} ${CYAN}Install Passwall v1${NC}"
echo -e "${YELLOW}2.${NC} ${CYAN}Install Passwall v2 - requires ≥256MB RAM${NC}"
echo -e "${YELLOW}3.${NC} ${CYAN}Install Passwall v2 + Mahsa Core${NC}"
[ -f /etc/init.d/passwall ] && echo -e "${YELLOW}4.${NC} ${GREEN}Update Passwall v1${NC}"
[ -f /etc/init.d/passwall2 ] && echo -e "${YELLOW}5.${NC} ${GREEN}Update Passwall v2${NC}"
echo -e "${YELLOW}6.${NC} ${BLUE}Install Cloudflare IP Scanner${NC}"

# Show uninstall only if any version is installed
if [ -f /etc/init.d/passwall ] || [ -f /etc/init.d/passwall2 ]; then
    echo -e "${YELLOW}7.${NC} ${RED}Uninstall all Passwall versions${NC}"
fi

echo -e "${YELLOW}0.${NC} ${CYAN}Exit${NC}"
echo ""

# Prompt
printf " - Select an option: "
read choice

uninstall_passwall() {
    echo -e "${YELLOW}Uninstalling all Passwall components...${NC}"
    opkg remove luci-app-passwall luci-app-passwall2 xray-core sing-box hysteria \
        passwall xray-geoip xray-geosite singbox hysteria \
        --force-removal-of-dependent-packages 2>/dev/null
    /etc/init.d/passwall stop 2>/dev/null
    /etc/init.d/passwall2 stop 2>/dev/null
    rm -rf /etc/passwall /etc/passwall2 /etc/init.d/passwall /etc/init.d/passwall2
    echo -e "${GREEN}Uninstall complete.${NC}"
}

auto_uninstall_if_needed() {
    if [ -f /etc/init.d/passwall ] || [ -f /etc/init.d/passwall2 ]; then
        echo -e "${RED}Another version of Passwall is already installed.${NC}"
        echo -e "${YELLOW}Uninstalling before proceeding...${NC}"
        uninstall_passwall
    fi
}

case "$choice" in
    1)
        auto_uninstall_if_needed
        echo -e "${GREEN}Installing Passwall v1...${NC}"
        rm -f passwall.sh
        wget -q --show-progress https://raw.githubusercontent.com/sadraimam/passwall/main/passwall.sh
        chmod +x passwall.sh
        sh passwall.sh
        ;;
    2)
        auto_uninstall_if_needed
        echo -e "${GREEN}Installing Passwall v2...${NC}"
        rm -f passwall2x.sh
        wget -q --show-progress https://raw.githubusercontent.com/sadraimam/passwall/main/passwall2x.sh
        chmod +x passwall2x.sh
        sh passwall2x.sh
        ;;
    3)
        auto_uninstall_if_needed
        echo -e "${GREEN}Installing Passwall v2 + Mahsa Core...${NC}"
        rm -f mahsa.sh
        wget -q --show-progress https://raw.githubusercontent.com/sadraimam/passwall/main/mahsa.sh
        chmod +x mahsa.sh
        sh mahsa.sh
        ;;
    4)
        [ -f /etc/init.d/passwall ] && {
            echo -e "${GREEN}Updating Passwall v1...${NC}"
            opkg update
            opkg install luci-app-passwall
        } || echo -e "${RED}Passwall v1 not installed.${NC}"
        ;;
    5)
        [ -f /etc/init.d/passwall2 ] && {
            echo -e "${GREEN}Updating Passwall v2...${NC}"
            opkg update
            opkg install luci-app-passwall2
        } || echo -e "${RED}Passwall v2 not installed.${NC}"
        ;;
    6)
        echo -e "${GREEN}Installing Cloudflare IP Scanner...${NC}"
        opkg update
        opkg install bash curl
        curl -ksSL https://gitlab.com/rwkgyg/cdnopw/raw/main/cdnopw.sh -o cdnopw.sh
        sh cdnopw.sh
        ;;
    7)
        uninstall_passwall
        ;;
    0)
        echo -e "${GREEN}Goodbye.${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option.${NC}"
        ;;
esac
