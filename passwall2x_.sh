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

# Create critical directories first
mkdir -p /var/lock
mkdir -p /tmp/opkg-lists
touch /var/lock/opkg.lock

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

# Install ABSOLUTE essentials with error handling
install_essentials() {
    echo -e "${YELLOW}Installing essential tools...${NC}"
    opkg update || echo -e "${YELLOW}opkg update failed, continuing...${NC}"
    
    # Install each package individually with error handling
    for pkg in wget unzip ca-bundle; do
        if opkg list-installed | grep -q "^$pkg "; then
            echo -e "${GREEN}$pkg is already installed${NC}"
        else
            echo -e "${YELLOW}Installing $pkg...${NC}"
            opkg install $pkg || echo -e "${RED}Failed to install $pkg${NC}"
        fi
    done
}
install_essentials

# Architecture detection
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) BIN_ARCH="amd64" ;;
    aarch64) BIN_ARCH="arm64" ;;
    armv7l) BIN_ARCH="armv7" ;;
    *) BIN_ARCH="amd64" ;;
esac
echo -e "${CYAN}Detected architecture: $BIN_ARCH${NC}"

# Xray-core installation
install_xray() {
    echo -e "${YELLOW}Installing Xray-core...${NC}"
    if which xray >/dev/null; then
        echo -e "${GREEN}Xray is already installed${NC}"
        return
    fi
    
    echo -e "${BLUE}Downloading Xray...${NC}"
    XRAY_URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-${BIN_ARCH}.zip"
    if ! wget -O /tmp/xray.zip "$XRAY_URL"; then
        echo -e "${RED}Failed to download Xray! Trying alternative URL...${NC}"
        XRAY_URL="https://github.com/XTLS/Xray-core/releases/download/v1.8.11/Xray-linux-${BIN_ARCH}.zip"
        wget -O /tmp/xray.zip "$XRAY_URL"
    fi
    
    echo -e "${BLUE}Installing Xray...${NC}"
    unzip -j -o /tmp/xray.zip xray -d /usr/bin/
    chmod +x /usr/bin/xray
    
    # Create service
    cat > /etc/init.d/xray <<'EOF'
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1
start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/xray run -config /etc/xray/config.json
    procd_set_param respawn
    procd_close_instance
}
EOF
    chmod +x /etc/init.d/xray
    /etc/init.d/xray enable
    
    echo -e "${GREEN}Xray installed successfully!${NC}"
    rm -f /tmp/xray.zip
}

# Sing-box installation
install_singbox() {
    echo -e "${YELLOW}Installing sing-box...${NC}"
    if which sing-box >/dev/null; then
        echo -e "${GREEN}sing-box is already installed${NC}"
        return
    fi
    
    echo -e "${BLUE}Downloading sing-box...${NC}"
    SINGBOX_URL="https://github.com/SagerNet/sing-box/releases/download/v1.8.7/sing-box-linux-${BIN_ARCH}.tar.gz"
    wget -O /tmp/singbox.tar.gz "$SINGBOX_URL"
    
    echo -e "${BLUE}Installing sing-box...${NC}"
    tar -xzf /tmp/singbox.tar.gz -C /tmp
    find /tmp -name sing-box -type f -exec cp {} /usr/bin/ \;
    chmod +x /usr/bin/sing-box
    
    # Create service
    cat > /etc/init.d/sing-box <<'EOF'
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1
start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/sing-box run -c /etc/sing-box/config.json
    procd_set_param respawn
    procd_close_instance
}
EOF
    chmod +x /etc/init.d/sing-box
    /etc/init.d/sing-box enable
    
    echo -e "${GREEN}sing-box installed successfully!${NC}"
    rm -f /tmp/singbox.tar.gz
}

# Hysteria installation
install_hysteria() {
    echo -e "${YELLOW}Installing hysteria...${NC}"
    if which hysteria >/dev/null; then
        echo -e "${GREEN}hysteria is already installed${NC}"
        return
    fi
    
    echo -e "${BLUE}Downloading hysteria...${NC}"
    HYSTERIA_URL="https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-${BIN_ARCH}"
    wget -O /usr/bin/hysteria "$HYSTERIA_URL"
    chmod +x /usr/bin/hysteria
    
    # Create service
    cat > /etc/init.d/hysteria <<'EOF'
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1
start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/hysteria server --config /etc/hysteria/config.json
    procd_set_param respawn
    procd_close_instance
}
EOF
    chmod +x /etc/init.d/hysteria
    /etc/init.d/hysteria enable
    
    echo -e "${GREEN}hysteria installed successfully!${NC}"
}

# Passwall2 installation
install_passwall() {
    echo -e "${YELLOW}Installing Passwall2...${NC}"
    if [ -f "/usr/lib/lua/luci/controller/passwall2.lua" ]; then
        echo -e "${GREEN}Passwall2 is already installed${NC}"
        return
    fi
    
    # Get OpenWrt version
    . /etc/os-release
    VERSION_ID=${VERSION_ID%.*}
    
    # Download Passwall2
    PASSWALL_URL="https://github.com/xiaorouji/openwrt-passwall/releases/download/25.7.15-1/luci-app-passwall2_${VERSION_ID}_all.ipk"
    wget -O /tmp/passwall2.ipk "$PASSWALL_URL"
    
    # Install
    opkg install /tmp/passwall2.ipk
    
    # Cleanup
    rm -f /tmp/passwall2.ipk
    echo -e "${GREEN}Passwall2 installed successfully!${NC}"
}

# Install cores
install_xray
install_singbox
install_hysteria
install_passwall

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
for pkg in dnsmasq-full kmod-nft-socket kmod-nft-tproxy kmod-inet-diag kmod-netlink-diag kmod-tun ipset; do
    if opkg list-installed | grep -q "^$pkg "; then
        echo -e "${GREEN}$pkg is already installed${NC}"
    else
        echo -e "${YELLOW}Installing $pkg...${NC}"
        opkg install $pkg || echo -e "${RED}Failed to install $pkg${NC}"
    fi
done

# Verify installations
echo -e "\n${CYAN}Verification:${NC}"

check_core() {
    local core_name=$1
    local binary_path=$2
    
    if [ -f "$binary_path" ]; then
        echo -e "${GREEN}✓ $core_name installed${NC}"
        return 0
    else
        echo -e "${RED}✗ $core_name installation failed${NC}"
        return 1
    fi
}

check_core "Xray-core" "/usr/bin/xray"
check_core "sing-box" "/usr/bin/sing-box"
check_core "hysteria" "/usr/bin/hysteria"

# Passwall2 configuration
echo -e "\n${YELLOW}Configuring Passwall2...${NC}"
if uci get passwall2.@global[0] >/dev/null 2>&1; then
    uci set passwall2.@global_forwarding[0].tcp_no_redir_ports='disable'
    uci set passwall2.@global_forwarding[0].udp_no_redir_ports='disable'
    uci set passwall2.@global_forwarding[0].tcp_redir_ports='1:65535'
    uci set passwall2.@global_forwarding[0].udp_redir_ports='1:65535'
    uci set passwall2.@global[0].remote_dns='8.8.4.4'
    
    # Shunt rules
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

# Final DNS
if uci get dhcp.@dnsmasq[0] >/dev/null 2>&1; then
    uci set dhcp.@dnsmasq[0].rebind_domain='www.ebanksepah.ir my.irancell.ir'
    uci commit dhcp
    echo -e "${GREEN}DNS configuration updated${NC}"
fi

echo -e "\n${GREEN}** Installation Complete **${NC}"
/sbin/reload_config

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
            echo -e "\n${YELLOW}Exiting. You may need to reboot later.${NC}"
            echo -e "Start services:"
            [ -f "/etc/init.d/xray" ] && echo "  /etc/init.d/xray start"
            [ -f "/etc/init.d/sing-box" ] && echo "  /etc/init.d/sing-box start"
            [ -f "/etc/init.d/hysteria" ] && echo "  /etc/init.d/hysteria start"
            exit 0
            ;;
        *)
            echo -e "\n${RED}Invalid choice! Press R or E: ${NC}"
            ;;
    esac
done
