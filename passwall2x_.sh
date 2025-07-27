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

### Add Core Repositories with Public Keys ###
echo -e "${YELLOW}Adding package repositories with public keys...${NC}"

# Architecture detection
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) OWRT_ARCH="amd64" ;;
    aarch64) OWRT_ARCH="arm64" ;;
    armv7l) OWRT_ARCH="arm_cortex-a7" ;;
    *) OWRT_ARCH="$ARCH" ;;
esac

# Passwall repository
echo -e "${CYAN}Adding Passwall repository...${NC}"
wget -O passwall.pub https://master.dl.sourceforge.net/project/openwrt-passwall-build/passwall.pub
opkg-key add passwall.pub

cat > /etc/opkg/customfeeds.conf <<EOF
src/gz passwall_base https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-21.02/$OWRT_ARCH/passwall_packages
src/gz passwall_luci https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-21.02/$OWRT_ARCH/passwall_luci
EOF

# Sing-box repository
echo -e "${CYAN}Adding sing-box repository...${NC}"
wget -O sing-box.pub https://sing-box.vercel.app/openwrt.pub
opkg-key add sing-box.pub
echo "src/gz singbox https://sing-box.vercel.app/debian/pool/main/s/sing-box" >> /etc/opkg/customfeeds.conf

# Hysteria repository
echo -e "${CYAN}Adding hysteria repository...${NC}"
wget -O hysteria.pub https://op.supes.top/packages/public.key
opkg-key add hysteria.pub
echo "src/gz hysteria https://op.supes.top/packages/$OWRT_ARCH" >> /etc/opkg/customfeeds.conf

# Update package lists
echo -e "${YELLOW}Updating package lists...${NC}"
opkg update

### Install basic packages ###
echo -e "${YELLOW}Installing basic packages...${NC}"
opkg remove dnsmasq
opkg install dnsmasq-full
opkg install wget-ssl unzip luci-app-passwall2
opkg install kmod-nft-socket kmod-nft-tproxy ca-bundle kmod-inet-diag kernel kmod-netlink-diag kmod-tun ipset

### Install cores using official packages ###
install_core() {
    local core_name=$1
    local package_name=$2
    
    echo -e "${YELLOW}Installing $core_name...${NC}"
    opkg install "$package_name"
    
    # Verify installation
    if opkg list-installed | grep -q "$package_name"; then
        echo -e "${GREEN}$core_name installed via opkg!${NC}"
    else
        echo -e "${RED}Failed to install $core_name via opkg!${NC}"
        return 1
    fi
}

# Install all cores
install_core "Xray-core" "xray-core"
install_core "sing-box" "sing-box"
install_core "hysteria" "hysteria"

### Fallback for failed installations ###
install_fallback() {
    local core_name=$1
    local binary_name=$2
    local repo_url=$3
    local file_pattern=$4
    
    if ! command -v "$binary_name" &> /dev/null; then
        echo -e "${YELLOW}Installing $core_name manually...${NC}"
        
        # Get latest release
        latest_url=$(curl -s "$repo_url" | grep -oP 'https://github.com/[^/]+/[^/]+/releases/download/[^"]+' | head -1)
        download_url=""
        
        # Find matching file
        while read -r url; do
            if [[ $url == *"$file_pattern"* ]]; then
                download_url="$url"
                break
            fi
        done < <(curl -s "$latest_url" | grep -oP 'href="\K[^"]+' | sed 's/^/https:\/\/github.com/')
        
        if [ -z "$download_url" ]; then
            echo -e "${RED}Could not find $core_name download URL!${NC}"
            return 1
        fi
        
        # Download and install
        echo -e "${CYAN}Downloading $core_name from $download_url${NC}"
        wget -O /tmp/core_file "$download_url"
        
        # Extract if needed
        if [[ "$download_url" == *.tar.gz ]]; then
            tar -xzf /tmp/core_file -C /tmp
            find /tmp -name "$binary_name" -exec cp {} /usr/bin/ \;
        elif [[ "$download_url" == *.zip ]]; then
            unzip /tmp/core_file -d /tmp
            find /tmp -name "$binary_name" -exec cp {} /usr/bin/ \;
        else
            cp /tmp/core_file "/usr/bin/$binary_name"
        fi
        
        chmod +x "/usr/bin/$binary_name"
        rm -f /tmp/core_file
    fi
}

# Fallback installations
install_fallback "sing-box" "sing-box" \
    "https://api.github.com/repos/SagerNet/sing-box/releases/latest" \
    "linux-$OWRT_ARCH"

install_fallback "hysteria" "hysteria" \
    "https://api.github.com/repos/apernet/hysteria/releases/latest" \
    "linux-$OWRT_ARCH"

### Create service files ###
create_service() {
    local service_name=$1
    local binary_path=$2
    
    if [ ! -f "/etc/init.d/$service_name" ]; then
        echo -e "${YELLOW}Creating $service_name service...${NC}"
        cat > "/etc/init.d/$service_name" <<EOF
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
        chmod +x "/etc/init.d/$service_name"
        /etc/init.d/"$service_name" enable
    fi
}

create_service "xray" "/usr/bin/xray"
create_service "sing-box" "/usr/bin/sing-box"
create_service "hysteria" "/usr/bin/hysteria"

### Verify installations ###
echo -e "\n${CYAN}Verification:${NC}"

verify_core() {
    local core_name=$1
    local binary_path=$2
    
    if command -v "$binary_path" &> /dev/null; then
        version=$("$binary_path" version 2>/dev/null | head -n 1)
        echo -e "${GREEN}✓ $core_name installed: ${version}${NC}"
        
        # Check if LuCI can detect it
        if uci get passwall2.@global[0] &> /dev/null; then
            echo -e "${GREEN}  LuCI integration verified${NC}"
        else
            echo -e "${YELLOW}  LuCI integration might need manual configuration${NC}"
        fi
    else
        echo -e "${RED}✗ $core_name installation failed${NC}"
    fi
}

verify_core "Xray-core" "xray"
verify_core "sing-box" "sing-box"
verify_core "hysteria" "hysteria"

### Additional configuration ###
echo -e "\n${YELLOW}Applying Passwall2 configuration...${NC}"

# Ensure Passwall2 is properly configured
if [ -f "/etc/config/passwall2" ]; then
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
    echo -e "${GREEN}Passwall2 configuration updated${NC}"
else
    echo -e "${RED}Passwall2 configuration not found!${NC}"
fi

# Final DNS configuration
uci set dhcp.@dnsmasq[0].rebind_domain='www.ebanksepah.ir 
my.irancell.ir'
uci commit

echo -e "\n${GREEN}** Installation Complete **${NC}"

# Cleanup
rm -f passwall2x.sh passwallx.sh iam.zip
/sbin/reload_config

# LuCI detection test
echo -e "\n${YELLOW}LuCI Detection Test:${NC}"
if [ -f "/usr/lib/lua/luci/controller/passwall2.lua" ]; then
    echo -e "${GREEN}Passwall2 LuCI component is installed${NC}"
else
    echo -e "${RED}Passwall2 LuCI component missing!${NC}"
    echo -e "${YELLOW}Reinstalling luci-app-passwall2...${NC}"
    opkg install --force-reinstall luci-app-passwall2
fi

# Reboot prompt
echo -e "\n${YELLOW}Choose action:${NC}"
echo -e "${GREEN}[R]${NC}eboot now (recommended)"
echo -e "${BLUE}[E]${NC}xit without reboot"
echo -n -e "${YELLOW}Your choice [R/E]: ${NC}"

while true; do
    read -n1 choice
    case $choice in
        [Rr]) 
            echo -e "\n${GREEN}Rebooting system...${NC}"
            sleep 2
            reboot
            exit 0
            ;;
        [Ee])
            echo -e "\n${YELLOW}Exiting. You may need to reboot later for all changes to take effect.${NC}"
            echo -e "To start services manually:"
            [ -f "/etc/init.d/xray" ] && echo "  /etc/init.d/xray start"
            [ -f "/etc/init.d/sing-box" ] && echo "  /etc/init.d/sing-box start"
            [ -f "/etc/init.d/hysteria" ] && echo "  /etc/init.d/hysteria start"
            exit 0
            ;;
        *)
            echo -e "\n${RED}Invalid choice! Press R to reboot or E to exit: ${NC}"
            ;;
    esac
done
