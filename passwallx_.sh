#!/bin/bash

# ─── Color Codes ────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ─── Ensure Running As Root ─────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root${NC}"
  exit 1
fi

# ─── System Setup ───────────────────────────────────────────────────────
function set_timezone() {
  echo "Configuring timezone to Asia/Tehran..."
  uci set system.@system[0].zonename='Asia/Tehran'
  uci set system.@system[0].timezone='<+0330>-3:30'
  uci commit
  /sbin/reload_config
}

# ─── Display System Info ────────────────────────────────────────────────
function show_system_info() {
  . /etc/openwrt_release
  MODEL=$(cat /tmp/sysinfo/model)
  echo -e "${YELLOW}
 _____ _____ _____ _____ _ _ _ _____ __    __    
|  _  |  _  |   __|   __| | | |  _  |  |  |  |   
|   __|     |__   |__   | | | |     |  |__|  |__ 
|__|  |__|__|_____|_____|_____|__|__|_____|_____|${NC}"

  echo " - Model       : $MODEL"
  echo " - OS Version  : $DISTRIB_RELEASE"
  echo " - Architecture: $DISTRIB_ARCH"
  echo
}

# ─── Check Passwall Availability ────────────────────────────────────────
function check_existing_passwall() {
  if [ -f /etc/init.d/passwall ]; then
    echo -e "${YELLOW} > 4.${NC} ${GREEN} Update Passwall v1${NC}"
  fi

  if [ -f /etc/init.d/passwall2 ]; then
    echo -e "${YELLOW} > 5.${NC} ${GREEN} Update Passwall v2${NC}"
  fi
}

# ─── Install Functions ──────────────────────────────────────────────────
function download_and_run() {
  local url="$1"
  local file="$2"

  echo -e "${CYAN}Downloading ${file}...${NC}"
  rm -f "$file"
  if wget -q "$url" -O "$file"; then
    chmod 755 "$file"
    sh "$file"
  else
    echo -e "${RED}Failed to download ${file}${NC}"
    exit 1
  fi
}

function install_passwall1() {
  download_and_run "https://raw.githubusercontent.com/sadraimam/passwall/main/passwall.sh" "passwall.sh"
}

function install_passwall2() {
  download_and_run "https://raw.githubusercontent.com/sadraimam/passwall/main/passwall2x.sh" "passwall2x.sh"
}

function install_mahsa() {
  download_and_run "https://raw.githubusercontent.com/sadraimam/passwall/refs/heads/main/mahsa.sh" "mahsa.sh"
}

function update_passwall1() {
  echo "Updating Passwall v1..."
  opkg update && opkg install luci-app-passwall
}

function update_passwall2() {
  echo "Updating Passwall v2..."
  opkg update && opkg install luci-app-passwall2
}

function install_cf_scanner() {
  echo "Installing CloudFlare IP Scanner..."
  opkg update
  opkg install bash curl
  curl -ksSL https://gitlab.com/rwkgyg/cdnopw/raw/main/cdnopw.sh -o cdnopw.sh && bash cdnopw.sh
}

# ─── Menu ───────────────────────────────────────────────────────────────
function show_menu() {
  echo -e "${YELLOW} 1.${NC} ${CYAN}Install Passwall v1${NC}"
  echo -e "${YELLOW} 2.${NC} ${CYAN}Install Passwall v2 (≥256MB RAM)${NC}"
  echo -e "${YELLOW} 3.${NC} ${CYAN}Install Passwall v2 + Mahsa Core${NC}"
  echo -e "${YELLOW} 4.${NC} ${CYAN}Update Passwall v1${NC}"
  echo -e "${YELLOW} 5.${NC} ${CYAN}Update Passwall v2${NC}"
  echo -e "${YELLOW} 9.${NC} ${YELLOW}Install Cloudflare IP Scanner${NC}"
  echo -e "${YELLOW} 6.${NC} ${RED}Exit${NC}"
  echo
}

function handle_choice() {
  read -p " - Select an option: " choice
  echo
  case "$choice" in
    1) install_passwall1 ;;
    2) install_passwall2 ;;
    3) install_mahsa ;;
    4) update_passwall1 ;;
    5) update_passwall2 ;;
    9) install_cf_scanner ;;
    6) echo -e "${GREEN}Exiting...${NC}"; exit 0 ;;
    *) echo -e "${RED}Invalid option selected!${NC}"; exit 1 ;;
  esac
}

# ─── Main Execution ─────────────────────────────────────────────────────
clear
set_timezone
show_system_info
check_existing_passwall
show_menu
handle_choice
