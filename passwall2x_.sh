#!/bin/bash
# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run as root!${NC}" >&2
    exit 1
fi

echo -e "${GREEN}Running as root...${NC}"
sleep 2
clear

# Basic system configuration
echo -e "${YELLOW}Configuring system settings...${NC}"
uci set system.@system[0].zonename='Asia/Tehran'
uci set system.@system[0].timezone='<+0330>-3:30'
uci set network.wan.peerdns="0"
uci set network.wan6.peerdns="0"
uci set network.wan.dns='1.1.1.1'
uci set network.wan6.dns='2001:4860:4860::8888'
uci commit system
uci commit network
uci commit
/sbin/reload_config

# Check for SNAPSHOT version
SNNAP=$(grep -o SNAPSHOT /etc/openwrt_release | sed -n '1p')
if [ "$SNNAP" == "SNAPSHOT" ]; then
    echo -e "${YELLOW}SNAPSHOT Version Detected!${NC}"
    rm -f passwalls.sh && wget https://raw.githubusercontent.com/sadraimam/passwall/main/passwalls.sh && chmod 777 passwalls.sh && sh passwalls.sh
    exit 1
else
    echo -e "${GREEN}Updating Packages...${NC}"
fi

### Update Packages ###
opkg update

### Add Src ###
wget -O passwall.pub https://master.dl.sourceforge.net/project/openwrt-passwall-build/passwall.pub
opkg-key add passwall.pub

>/etc/opkg/customfeeds.conf
read release arch << EOF
$(. /etc/openwrt_release ; echo ${DISTRIB_RELEASE%.*} $DISTRIB_ARCH)
EOF
for feed in passwall_luci passwall_packages passwall2; do
    echo "src/gz $feed https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-$release/$arch/$feed" >> /etc/opkg/customfeeds.conf
done

### Install basic packages ###
echo -e "${YELLOW}Installing basic packages...${NC}"
opkg update
opkg remove dnsmasq
opkg install dnsmasq-full
opkg install wget-ssl unzip luci-app-passwall2
opkg install kmod-nft-socket kmod-nft-tproxy ca-bundle kmod-inet-diag kernel kmod-netlink-diag kmod-tun ipset

### Enhanced Core Installation ###
install_core() {
    local core_name=$1
    local package_name=$2
    local binary_path=$3
    local github_repo=$4
    
    echo -e "${YELLOW}Installing ${core_name}...${NC}"
    
    # Try opkg installation first
    if opkg install "${package_name}" 2>/dev/null; then
        sleep 2
        if [ -f "${binary_path}" ]; then
            echo -e "${GREEN}${core_name} installed via opkg!${NC}"
            return 0
        fi
    fi
    
    # GitHub fallback with architecture detection
    echo -e "${YELLOW}Trying GitHub release...${NC}"
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    case $(uname -m) in
        x86_64) arch="amd64";;
        aarch64) arch="arm64";;
        *) arch="$(uname -m)";;
    esac
    
    # Special handling for each core
    case $core_name in
        "sing-box")
            download_url=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | grep "browser_download_url.*linux-$arch" | grep -v 'android' | head -1 | cut -d '"' -f 4)
            ;;
        "hysteria")
            download_url=$(curl -s https://api.github.com/repos/apernet/hysteria/releases/latest | grep "browser_download_url.*linux-$arch" | head -1 | cut -d '"' -f 4)
            ;;
        "Xray")
            download_url="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-$arch.zip"
            ;;
    esac

    if wget -q --show-progress "$download_url"; then
        archive_file=$(basename "$download_url")
        
        # Extract based on file type
        if [[ $archive_file == *.tar.gz ]]; then
            tar -xzf "$archive_file"
        elif [[ $archive_file == *.zip ]]; then
            unzip -q "$archive_file"
        fi
        
        # Find binary (handle different extraction paths)
        binary=$(find . -type f -name "${core_name,,}*" -o -name "${core_name}*" | grep -v '\.sig$' | head -1)
        
        if [ -n "$binary" ] && [ -f "$binary" ]; then
            cp "$binary" "$binary_path"
            chmod +x "$binary_path"
            echo -e "${GREEN}${core_name} installed from GitHub!${NC}"
            
            # Create basic service file if needed
            if [ ! -f "/etc/init.d/${core_name}" ]; then
                echo -e "${YELLOW}Creating basic service file...${NC}"
                cat > "/etc/init.d/${core_name}" <<EOF
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command "$binary_path"
    procd_set_param respawn
    procd_close_instance
}
EOF
                chmod +x "/etc/init.d/${core_name}"
                /etc/init.d/${core_name} enable
            fi
            return 0
        fi
    fi
    
    echo -e "${RED}Failed to install ${core_name}!${NC}"
    echo -e "${YELLOW}Manual installation required for ${core_name}.${NC}"
    cd
    rm -rf "$temp_dir"
    return 1
}

# Install cores with proper fallback
install_core "Xray" "xray-core" "/usr/bin/xray" "XTLS/Xray-core"
install_core "sing-box" "sing-box" "/usr/bin/sing-box" "SagerNet/sing-box"
install_core "hysteria" "hysteria" "/usr/bin/hysteria" "apernet/hysteria"

### Verify installations ###
echo -e "${YELLOW}Verifying installations...${NC}"
[ -f "/etc/init.d/passwall2" ] && echo -e "${GREEN}Passwall.2 Installed Successfully!${NC}" || echo -e "${RED}Passwall.2 not installed!${NC}"
[ -f "/usr/lib/opkg/info/dnsmasq-full.control" ] && echo -e "${GREEN}dnsmasq-full Installed successfully!${NC}" || echo -e "${RED}dnsmasq-full not installed!${NC}"

### Additional configuration ###
echo -e "${YELLOW}Applying additional configuration...${NC}"
cd /tmp
wget -q https://raw.githubusercontent.com/sadraimam/passwall/refs/heads/main/iam.zip
unzip -o iam.zip -d /
cd

# Passwall2 configuration
uci set passwall2.@global_forwarding[0]=global_forwarding
uci set passwall2.@global_forwarding[0].tcp_no_redir_ports='disable'
uci set passwall2.@global_forwarding[0].udp_no_redir_ports='disable'
uci set passwall2.@global_forwarding[0].tcp_redir_ports='1:65535'
uci set passwall2.@global_forwarding[0].udp_redir_ports='1:65535'
uci set passwall2.@global[0].remote_dns='8.8.4.4'

# Shunt rules for Iran
uci set passwall2.Direct=shunt_rules
uci set passwall2.Direct.network='tcp,udp'
uci set passwall2.Direct.remarks='IRAN'
uci set passwall2.Direct.ip_list='0.0.0.0/8
10.0.0.0/8
100.64.0.0/10
127.0.0.0/8
169.254.0.0/16
172.16.0.0/12
192.0.0.0/24
192.0.2.0/24
192.88.99.0/24
192.168.0.0/16
198.19.0.0/16
198.51.100.0/24
203.0.113.0/24
224.0.0.0/4
240.0.0.0/4
255.255.255.255/32
::/128
::1/128
::ffff:0:0:0/96
64:ff9b::/96
100::/64
2001::/32
2001:20::/28
2001:db8::/32
2002::/16
fc00::/7
fe80::/10
ff00::/8
geoip:ir'
uci set passwall2.Direct.domain_list='regexp:^.+\.ir$
geosite:category-ir'

uci set passwall2.myshunt.Direct='_direct'
uci commit passwall2

# Final commit and cleanup
uci set dhcp.@dnsmasq[0].rebind_domain='www.ebanksepah.ir 
my.irancell.ir'
uci commit

echo -e "${GREEN}** Installation Completed **${NC}"
rm -f passwall2x_.sh passwallx.sh
/sbin/reload_config

# Final verification with service check
echo -e "\n${CYAN}Installation Verification:${NC}"
check_service() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓ $2 installed ($(basename $1) - v$($1 version 2>/dev/null | head -1))${NC}"
    else
        echo -e "${RED}✗ $2 not installed${NC}"
    fi
}

check_service "/usr/bin/xray" "Xray-core"
check_service "/usr/bin/sing-box" "sing-box"
check_service "/usr/bin/hysteria" "hysteria"

# Reboot/Exit option with service status
echo -e "\n${YELLOW}Core Services Status:${NC}"
[ -f "/etc/init.d/xray" ] && echo -e "Xray: $(/etc/init.d/xray enabled && echo -e "${GREEN}Enabled${NC}" || echo -e "${YELLOW}Disabled${NC}")"
[ -f "/etc/init.d/sing-box" ] && echo -e "sing-box: $(/etc/init.d/sing-box enabled && echo -e "${GREEN}Enabled${NC}" || echo -e "${YELLOW}Disabled${NC}")"
[ -f "/etc/init.d/hysteria" ] && echo -e "hysteria: $(/etc/init.d/hysteria enabled && echo -e "${GREEN}Enabled${NC}" || echo -e "${YELLOW}Disabled${NC}")"

echo -e "\n${YELLOW}Choose action:${NC}"
echo -e "${GREEN}[R]${NC}eboot now (recommended)"
echo -e "${BLUE}[E]${NC}xit without reboot"
echo -n -e "${YELLOW}Your choice [R/E]: ${NC}"

while true; do
    read -n1 choice
    case $choice in
        [Rr]) 
            echo -e "\n${GREEN}Rebooting system...${NC}"
            sleep 1
            reboot
            exit 0
            ;;
        [Ee])
            echo -e "\n${YELLOW}Remember to reboot later for changes to take effect.${NC}"
            echo -e "You can manually start services with:"
            [ -f "/etc/init.d/xray" ] && echo -e "  /etc/init.d/xray start"
            [ -f "/etc/init.d/sing-box" ] && echo -e "  /etc/init.d/sing-box start"
            [ -f "/etc/init.d/hysteria" ] && echo -e "  /etc/init.d/hysteria start"
            exit 0
            ;;
        *)
            echo -e "\n${RED}Invalid choice! Press R to reboot or E to exit: ${NC}"
            ;;
    esac
done
