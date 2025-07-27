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

### Cleanup before installation ###
echo -e "${YELLOW}Cleaning up space...${NC}"
opkg clean
rm -rf /tmp/opkg-lists/*
rm -f /tmp/*.ipk /tmp/*.zip /tmp/*.tar.gz

### Install essential tools ###
echo -e "${YELLOW}Installing essential tools...${NC}"
opkg install wget-ssl unzip
opkg install libustream-openssl ca-bundle

### Core Installation Functions ###
install_xray() {
    echo -e "${YELLOW}Installing Xray...${NC}"
    if opkg install xray-core; then
        echo -e "${GREEN}Xray installed via opkg!${NC}"
    else
        echo -e "${YELLOW}Using direct installation method...${NC}"
        wget -O /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-arm64-v8a.zip
        unzip -o /tmp/xray.zip xray -d /usr/bin/
        chmod +x /usr/bin/xray
        echo -e "${GREEN}Xray installed successfully!${NC}"
    fi
    
    # Cleanup
    rm -f /tmp/xray.zip
}

install_singbox() {
    echo -e "${YELLOW}Installing sing-box...${NC}"
    
    # Get architecture
    case $(uname -m) in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        *) ARCH="amd64" ;;
    esac
    
    # Direct download method
    echo -e "${YELLOW}Downloading sing-box binary...${NC}"
    wget -O /usr/bin/sing-box https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-linux-$ARCH
    
    if [ -f "/usr/bin/sing-box" ]; then
        chmod +x /usr/bin/sing-box
        echo -e "${GREEN}sing-box installed successfully!${NC}"
        
        # Create service file
        cat > "/etc/init.d/sing-box" <<EOF
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/sing-box
    procd_set_param respawn
    procd_close_instance
}
EOF
        chmod +x "/etc/init.d/sing-box"
        /etc/init.d/sing-box enable
        echo -e "${GREEN}Created sing-box service${NC}"
    else
        echo -e "${RED}Failed to install sing-box!${NC}"
    fi
}

install_hysteria() {
    echo -e "${YELLOW}Installing hysteria...${NC}"
    
    # Get architecture
    case $(uname -m) in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        *) ARCH="amd64" ;;
    esac
    
    # Direct download method
    echo -e "${YELLOW}Downloading hysteria binary...${NC}"
    wget -O /usr/bin/hysteria https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-$ARCH
    
    if [ -f "/usr/bin/hysteria" ]; then
        chmod +x /usr/bin/hysteria
        echo -e "${GREEN}hysteria installed successfully!${NC}"
        
        # Create service file
        cat > "/etc/init.d/hysteria" <<EOF
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/hysteria
    procd_set_param respawn
    procd_close_instance
}
EOF
        chmod +x "/etc/init.d/hysteria"
        /etc/init.d/hysteria enable
        echo -e "${GREEN}Created hysteria service${NC}"
    else
        echo -e "${RED}Failed to install hysteria!${NC}"
    fi
}

### Install basic packages ###
echo -e "${YELLOW}Installing basic packages...${NC}"
opkg install dnsmasq-full
opkg install luci-app-passwall2
opkg install kmod-nft-socket kmod-nft-tproxy kmod-inet-diag kmod-netlink-diag kmod-tun ipset

### Install all cores ###
install_xray
install_singbox
install_hysteria

### Verify installations ###
echo -e "\n${CYAN}Verification:${NC}"

check_core() {
    local core_path=$1
    local core_name=$2
    
    if [ -f "$core_path" ]; then
        echo -e "${GREEN}✓ $core_name installed${NC}"
        return 0
    else
        echo -e "${RED}✗ $core_name installation failed${NC}"
        return 1
    fi
}

check_core "/usr/bin/xray" "Xray-core"
check_core "/usr/bin/sing-box" "sing-box"
check_core "/usr/bin/hysteria" "hysteria"

### Additional configuration ###
echo -e "\n${YELLOW}Applying final configuration...${NC}"

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

# Final DNS configuration
uci set dhcp.@dnsmasq[0].rebind_domain='www.ebanksepah.ir 
my.irancell.ir'
uci commit

echo -e "\n${GREEN}** Installation Complete **${NC}"

# Cleanup
rm -f /tmp/*.zip /tmp/*.tar.gz
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
