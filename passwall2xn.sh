#!/bin/bash

# ====== Colors ======
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ====== System Settings ======
uci set system.@system[0].zonename='Asia/Tehran'
uci set system.@system[0].timezone='<+0330>-3:30'
uci set network.wan.peerdns="0"
uci set network.wan6.peerdns="0"
uci set network.wan.dns='1.1.1.1'
uci set network.wan6.dns='2001:4860:4860::8888'
uci commit system
uci commit network
/sbin/reload_config

# ====== Update Feeds ======
opkg update

wget -O passwall.pub https://master.dl.sourceforge.net/project/openwrt-passwall-build/passwall.pub
opkg-key add passwall.pub
>/etc/opkg/customfeeds.conf

read release arch << EOF
$(. /etc/openwrt_release ; echo ${DISTRIB_RELEASE%.*} $DISTRIB_ARCH)
EOF

for feed in passwall_luci passwall_packages passwall2; do
    echo "src/gz $feed https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-$release/$arch/$feed" >> /etc/opkg/customfeeds.conf
done

opkg update

# ====== Install Helper ======
install_if_missing() {
    pkg="$1"
    if ! opkg list-installed | grep -q "^$pkg "; then
        echo -e "${YELLOW}Installing $pkg...${NC}"
        opkg install "$pkg"
        sleep 1
        rm -rf /tmp/opkg-lists/*
        rm -rf /tmp/luci-uploads/*
        rm -rf /tmp/*.ipk
    else
        echo -e "${GREEN}$pkg already installed.${NC}"
    fi
}

# ====== Core Install ======
opkg remove dnsmasq
sleep 3

for pkg in dnsmasq-full wget-ssl unzip luci-app-passwall2 \
           kmod-nft-socket kmod-nft-tproxy ca-bundle \
           kmod-inet-diag kmod-netlink-diag kmod-tun ipset sing-box hysteria xray-core; do
    install_if_missing "$pkg"
done

# ====== Verify Critical Components ======
echo -e "${YELLOW}Verifying Installed Packages...${NC}"

check_installed() {
    pkg="$1"
    path="$2"
    if [ -e "$path" ]; then
        echo -e "${GREEN}$pkg installed successfully ✔${NC}"
    else
        echo -e "${RED}$pkg NOT installed ✘${NC}"
    fi
}

check_installed "dnsmasq-full" "/usr/lib/opkg/info/dnsmasq-full.control"
check_installed "luci-app-passwall2" "/etc/init.d/passwall2"
check_installed "sing-box" "/usr/bin/sing-box"
check_installed "hysteria" "/usr/bin/hysteria"
check_installed "xray-core" "/usr/bin/xray"

# ====== Patch Files ======
cd /tmp
wget -q https://raw.githubusercontent.com/sadraimam/passwall/refs/heads/main/iam.zip
unzip -o iam.zip -d /
cd

# ====== Passwall2 Configuration ======
uci set passwall2.@global_forwarding[0]=global_forwarding
uci set passwall2.@global_forwarding[0].tcp_no_redir_ports='disable'
uci set passwall2.@global_forwarding[0].udp_no_redir_ports='disable'
uci set passwall2.@global_forwarding[0].tcp_redir_ports='1:65535'
uci set passwall2.@global_forwarding[0].udp_redir_ports='1:65535'
uci set passwall2.@global[0].remote_dns='8.8.4.4'

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

uci set dhcp.@dnsmasq[0].rebind_domain='www.ebanksepah.ir my.irancell.ir'

uci commit system
uci commit network
uci commit passwall2
uci commit dhcp
/sbin/reload_config

# ====== Cleanup ======
rm -f passwall2x.sh passwallx.sh iam.zip passwall.pub

echo -e "${GREEN}** Passwall2 Installation Completed Successfully **${NC}"
