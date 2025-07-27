#!/bin/sh

# ─── Color Codes ────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ─── Ensure Running As Root ─────────────────────────────────────────────
[ "$(id -u)" -ne 0 ] && echo -e "${RED}Please run as root${NC}" && exit 1

# ─── Timezone Setup ─────────────────────────────────────────────────────
set_timezone() {
  echo "Configuring timezone to Asia/Tehran..."
  uci set system.@system[0].zonename='Asia/Tehran'
  uci set system.@system[0].timezone='<+0330>-3:30'
  uci commit
  /sbin/reload_config
}

# ─── System Info ────────────────────────────────────────────────────────
show_system_info() {
  . /etc/openwrt_release
  MODEL=$(cat /tmp/sysinfo/model)
  echo -e "${YELLOW}
 _____ _____ _____ _____ _ _ _ _____ __    __    
|  _  |  _  |   __|   __| | | |  _  |  |  |  |   
|   __|     |__   |__   | | | |     |  |__|  |__ 
|__|  |__|__|_____|_____|_____|__|__|_____|_____|
${NC}"
  echo " - Model       : $MODEL"
  echo " - OS Version  : $DISTRIB_RELEASE"
  echo " - Architecture: $DISTRIB_ARCH"
  echo
}

# ─── Actions ────────────────────────────────────────────────────────────
download_and_run() {
  URL="$1"
  FILE="$2"
  echo -e "${CYAN}Downloading ${FILE}...${NC}"
  rm -f "$FILE"
  if wget -q "$URL" -O "$FILE"; then
    chmod 755 "$FILE"
    sh "$FILE"
  else
    echo -e "${RED}Failed to download ${FILE}${NC}"
    exit 1
  fi
}

install_passwall1() {
  download_and_run "https://raw.githubusercontent.com/sadraimam/passwall/main/passwall.sh" "passwall.sh"
}

install_passwall2() {
  download_and_run "https://raw.githubusercontent.com/sadraimam/passwall/main/passwall2x.sh" "passwall2x.sh"
}

install_mahsa() {
  download_and_run "https://raw.githubusercontent.com/sadraimam/passwall/refs/heads/main/mahsa.sh" "mahsa.sh"
}

update_passwall1() {
  echo "Updating Passwall v1..."
  opkg update && opkg install luci-app-passwall
}

update_passwall2() {
  echo "Updating Passwall v2..."
  opkg update && opkg install luci-app-passwall2
}

install_cf_scanner() {
  echo "Installing CloudFlare IP Scanner..."
  opkg update
  opkg install bash curl
  curl -ksSL https://gitlab.com/rwkgyg/cdnopw/raw/main/cdnopw.sh -o cdnopw.sh && sh cdnopw.sh
}

# ─── Menu ───────────────────────────────────────────────────────────────
show_menu() {
  echo -e "${YELLOW} 1.${NC} ${CYAN}Install Passwall v1${NC}"
  echo -e "${YELLOW} 2.${NC} ${CYAN}Install Passwall v2 (≥256MB RAM)${NC}"
  echo -e "${YELLOW} 3.${NC} ${CYAN}Install Passwall v2 + Mahsa Core${NC}"

  [ -f /etc/init.d/passwall ] && echo -e "${YELLOW} 4.${NC} ${CYAN}Update Passwall v1${NC}"
  [ -f /etc/init.d/passwall2 ] && echo -e "${YELLOW} 5.${NC} ${CYAN}Update Passwall v2${NC}"

  echo -e "${YELLOW} 9.${NC} ${CYAN}Install Cloudflare IP Scanner${NC}"
  echo -e "${YELLOW} 6.${NC} ${RED}Exit${NC}"
  echo
}

# ─── Handle Selection ───────────────────────────────────────────────────
handle_choice() {
  echo -n " - Select an option: "
  read choice

  case "$choice" in
    1) install_passwall1 ;;
    2) install_passwall2 ;;
    3) install_mahsa ;;
    4) [ -f /etc/init.d/passwall ] && update_passwall1 || echo "${RED}Not installed.${NC}" ;;
    5) [ -f /etc/init.d/passwall2 ] && update_passwall2 || echo "${RED}Not installed.${NC}" ;;
    9) install_cf_scanner ;;
    6) echo -e "${GREEN}Exiting...${NC}"; exit 0 ;;
    *) echo -e "${RED}Invalid option selected!${NC}"; exit 1 ;;
  esac
}

# ─── Run ────────────────────────────────────────────────────────────────
clear
set_timezone
show_system_info
show_menu
handle_choice
