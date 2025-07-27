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
|__|  |__|__|_____|_____|_____|__|__|_____|_____|
${NC}"

  echo " - Model       : $MODEL"
  echo " - OS Version  : $DISTRIB_RELEASE"
  echo " - Architecture: $DISTRIB_ARCH"
  echo
}

# ─── Download + Run Helper ──────────────────────────────────────────────
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

# ─── Installation / Update Functions ────────────────────────────────────
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

function exit_script() {
  echo -e "${GREEN}Exiting...${NC}"
  exit 0
}

# ─── Menu Builder ───────────────────────────────────────────────────────
MENU_OPTIONS=()
OPTION_MAP=()

function build_menu() {
  MENU_OPTIONS+=("1. Install Passwall v1")
  OPTION_MAP+=("install_passwall1")

  MENU_OPTIONS+=("2. Install Passwall v2 (≥256MB RAM)")
  OPTION_MAP+=("install_passwall2")

  MENU_OPTIONS+=("3. Install Passwall v2 + Mahsa Core")
  OPTION_MAP+=("install_mahsa")

  if [ -f /etc/init.d/passwall ]; then
    MENU_OPTIONS+=("4. Update Passwall v1")
    OPTION_MAP+=("update_passwall1")
  fi

  if [ -f /etc/init.d/passwall2 ]; then
    MENU_OPTIONS+=("5. Update Passwall v2")
    OPTION_MAP+=("update_passwall2")
  fi

  MENU_OPTIONS+=("9. Install Cloudflare IP Scanner")
  OPTION_MAP+=("install_cf_scanner")

  MENU_OPTIONS+=("6. Exit")
  OPTION_MAP+=("exit_script")
}

function show_menu() {
  for item in "${MENU_OPTIONS[@]}"; do
    echo -e "${YELLOW}${item%%.*}.${NC} ${CYAN}${item#*. }${NC}"
  done
  echo
}

function handle_choice() {
  read -p " - Select an option: " choice
  echo

  for i in "${!MENU_OPTIONS[@]}"; do
    index="${MENU_OPTIONS[$i]%%.*}"
    if [[ "$choice" == "$index" ]]; then
      ${OPTION_MAP[$i]}
      return
    fi
  done

  echo -e "${RED}Invalid option selected!${NC}"
  exit 1
}

# ─── Main Execution ─────────────────────────────────────────────────────
clear
set_timezone
show_system_info
build_menu
show_menu
handle_choice
