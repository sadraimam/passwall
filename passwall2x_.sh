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

### Install cores ###
install_core() {
    local core_name=$1
    local package_name=$2
    local binary_path=$3
    
    echo -e "${YELLOW}Installing ${core_name}...${NC}"
    opkg install "${package_name}" >/dev/null 2>&1
    sleep 2
    
    if [ -f "${binary_path}" ]; then
        echo -e "${GREEN}${core_name} installed via opkg!${NC}"
        return 0
    else
        echo -e "${YELLOW}Using direct installation method...${NC}"
        case $core_name in
            "Xray")
                # Xray installation method that works
                wget -O /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
                unzip -o /tmp/xray.zip xray -d /usr/bin/
                chmod +x /usr/bin/xray
                rm -f /tmp/xray.zip
                ;;
            "sing-box")
                # PROVEN WORKING METHOD - Direct binary download
                wget -O /usr/bin/sing-box https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-linux-amd64
                chmod +x /usr/bin/sing-box
                ;;
            "hysteria")
                # Working hysteria method
                wget -O /usr/bin/hysteria https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64
                chmod +x /usr/bin/hysteria
                ;;
        esac
        
        if [ -f "${binary_path}" ]; then
            echo -e "${GREEN}${core_name} installed successfully!${NC}"
            
            # Create service file if needed
            if [ ! -f "/etc/init.d/${core_name}" ]; then
                cat > "/etc/init.d/${core_name}" <<EOF
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command "${binary_path}"
    procd_set_param respawn
    procd_close_instance
}
EOF
                chmod +x "/etc/init.d/${core_name}"
                /etc/init.d/${core_name} enable
            fi
            return 0
        else
            echo -e "${RED}Failed to install ${core_name}!${NC}"
            return 1
        fi
    fi
}

# Install all cores
install_core "Xray" "xray-core" "/usr/bin/xray"
install_core "sing-box" "sing-box" "/usr/bin/sing-box"
install_core "hysteria" "hysteria" "/usr/bin/hysteria"

### Verify installations ###
echo -e "\n${CYAN}Verification:${NC}"
check_core() {
    local core_path=$1
    local core_name=$2
    
    if [ -f "$core_path" ]; then
        version=$($core_path version 2>/dev/null | head -n 1)
        if [ -n "$version" ]; then
            echo -e "${GREEN}✓ $core_name: $version${NC}"
        else
            echo -e "${GREEN}✓ $core_name installed (version unknown)${NC}"
        fi
    else
        echo -e "${RED}✗ $core_name NOT installed${NC}"
    fi
}

check_core "/usr/bin/xray" "Xray-core"
check_core "/usr/bin/sing-box" "sing-box"
check_core "/usr/bin/hysteria" "hysteria"

[ -f "/etc/init.d/passwall2" ] && echo -e "${GREEN}✓ Passwall2 installed${NC}" || echo -e "${RED}✗ Passwall2 missing${NC}"
[ -f "/usr/lib/opkg/info/dnsmasq-full.control" ] && echo -e "${GREEN}✓ dnsmasq-full installed${NC}" || echo -e "${RED}✗ dnsmasq-full missing${NC}"

### Additional configuration ###
echo -e "\n${YELLOW}Applying final configuration...${NC}"
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

# Final commit
uci set dhcp.@dnsmasq[0].rebind_domain='www.ebanksepah.ir 
my.irancell.ir'
uci commit

echo -e "\n${GREEN}** Installation Complete **${NC}"
rm -f passwall2x.sh passwallx.sh
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
