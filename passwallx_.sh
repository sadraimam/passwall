#!/bin/sh

# ─── Color Codes ────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ─── Ensure Running As Root ─────────────────────────────────────────────
if [ "$(id -u)" != "0" ]; then
  printf "%sPlease run as root%s\n" "$RED" "$NC"
  exit 1
fi

# ─── Timezone Setup ─────────────────────────────────────────────────────
set_timezone() {
  printf "Configuring timezone to Asia/Tehran...\n"
  uci set system.@system[0].zonename='Asia/Tehran'
  uci set system.@system[0].timezone='<+0330>-3:30'
  uci commit
  /sbin/reload_config
}

# ─── System Info ────────────────────────────────────────────────────────
show_system_info() {
  . /etc/openwrt_release
  MODEL=$(cat /tmp/sysinfo/model 2>/dev/null || echo "Unknown")
  printf "%s\n" "$YELLOW
 _____ _____ _____ _____ _ _ _ _____ __    __    
|  _  |  _  |   __|   __| | | |  _  |  |  |  |   
|   __|     |__   |__   | | | |     |  |__|  |__ 
|__|  |__|__|_____|_____|_____|__|__|_____|_____|
$NC"
  printf " - Model       : %s\n" "$MODEL"
  printf " - OS Version  : %s\n" "$DISTRIB_RELEASE"
  printf " - Architecture: %s\n\n" "$DISTRIB_ARCH"
}

# ─── Download + Run Helper ──────────────────────────────────────────────
download_and_run() {
  URL=$1
  FILE=$2
  printf "%sDownloading %s...%s\n" "$CYAN" "$FILE" "$NC"
  rm -f "$FILE"
  if wget -q "$URL" -O "$FILE"; then
    chmod 755 "$FILE"
    sh "$FILE"
  else
    printf "%sFailed to download %s%s\n" "$RED" "$FILE" "$NC"
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
  printf "Updating Passwall v1...\n"
  opkg update && opkg install luci-app-passwall
}

update_passwall2() {
  printf "Updating Passwall v2...\n"
  opkg update && opkg install luci-app-passwall2
}

install_cf_scanner() {
  printf "Installing CloudFlare IP Scanner...\n"
  opkg update
  opkg install bash curl
  curl -ksSL https://gitlab.com/rwkgyg/cdnopw/raw/main/cdnopw.sh -o cdnopw.sh && sh cdnopw.sh
}

# ─── Menu ───────────────────────────────────────────────────────────────
show_menu() {
  printf "%s1.%s %sInstall Passwall v1%s\n" "$YELLOW" "$NC" "$CYAN" "$NC"
  printf "%s2.%s %sInstall Passwall v2 - requires ≥256MB RAM%s\n" "$YELLOW" "$NC" "$CYAN" "$NC"
  printf "%s3.%s %sInstall Passwall v2 + Mahsa Core%s\n" "$YELLOW" "$NC" "$CYAN" "$NC"

  if [ -f /etc/init.d/passwall ]; then
    printf "%s4.%s %sUpdate Passwall v1%s\n" "$YELLOW" "$NC" "$CYAN" "$NC"
  fi

  if [ -f /etc/init.d/passwall2 ]; then
    printf "%s5.%s %sUpdate Passwall v2%s\n" "$YELLOW" "$NC" "$CYAN" "$NC"
  fi

  printf "%s9.%s %sInstall Cloudflare IP Scanner%s\n" "$YELLOW" "$NC" "$CYAN" "$NC"
  printf "%s6.%s %sExit%s\n\n" "$YELLOW" "$NC" "$RED" "$NC"
}

# ─── Handle Selection ───────────────────────────────────────────────────
handle_choice() {
  printf " - Select an option: "
  read choice

  case "$choice" in
    1) install_passwall1 ;;
    2) install_passwall2 ;;
    3) install_mahsa ;;
    4)
      if [ -f /etc/init.d/passwall ]; then
        update_passwall1
      else
        printf "%sPasswall v1 is not installed.%s\n" "$RED" "$NC"
      fi
      ;;
    5)
      if [ -f /etc/init.d/passwall2 ]; then
        update_passwall2
      else
        printf "%sPasswall v2 is not installed.%s\n" "$RED" "$NC"
      fi
      ;;
    9) install_cf_scanner ;;
    6)
      printf "%sExiting...%s\n" "$GREEN" "$NC"
      exit 0
      ;;
    *)
      printf "%sInvalid option selected!%s\n" "$RED" "$NC"
      exit 1
      ;;
  esac
}

# ─── Main ───────────────────────────────────────────────────────────────
clear
set_timezone
show_system_info
show_menu
handle_choice
