#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

clear

uci set system.@system[0].zonename='Asia/Tehran'
uci set system.@system[0].timezone='<+0330>-3:30'
uci set network.wan.peerdns="0"
uci set network.wan6.peerdns="0"
uci set network.wan.dns='1.1.1.1'
uci set network.wan6.dns='2001:4860:4860::8888'
uci commit system
uci commit network
/sbin/reload_config

opkg update

# Add Passwall Feeds
wget -O /tmp/passwall.pub https://master.dl.sourceforge.net/project/openwrt-passwall-build/passwall.pub
opkg-key add /tmp/passwall.pub
>/etc/opkg/customfeeds.conf

read release arch << EOF
$(. /etc/openwrt_release ; echo ${DISTRIB_RELEASE%.*} $DISTRIB_ARCH)
EOF

for feed in passwall_luci passwall_packages passwall2; do
  echo "src/gz $feed https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-$release/$arch/$feed" >> /etc/opkg/customfeeds.conf
done

opkg update

# Function to install from tmp
install_tmp() {
  pkg="$1"
  echo -e "${YELLOW}Installing $pkg ...${NC}"
  cd /tmp
  opkg download "$pkg" && opkg install $(ls -t ${pkg}_*.ipk | head -n1)
  sleep 2
  rm -f ${pkg}_*.ipk
}

# Main Install Sequence
opkg remove dnsmasq
install_tmp dnsmasq-full
install_tmp wget-ssl
install_tmp unzip
install_tmp luci-app-passwall2
install_tmp kmod-nft-socket
install_tmp kmod-nft-tproxy
install_tmp ca-bundle
install_tmp kmod-inet-diag
install_tmp kernel
install_tmp kmod-netlink-diag
install_tmp kmod-tun
install_tmp ipset
install_tmp sing-box
install_tmp hysteria
install_tmp xray-core

RESULT=`ls /usr/bin/passwall2`
if [ "$RESULT" == "/usr/bin/passwall2" ]; then
echo -e "${GREEN} Passwall2 : OK ! ${NC}"
 else
 echo -e "${YELLOW} Passwall2 : NOT INSTALLED X ${NC}"
fi

RESULT=`ls /usr/bin/xray`
if [ "$RESULT" == "/usr/bin/xray" ]; then
echo -e "${GREEN} XRAY : OK ! ${NC}"
 else
 echo -e "${YELLOW} XRAY : NOT INSTALLED X ${NC}"
fi

RESULT=`ls /usr/bin/sing-box`
if [ "$RESULT" == "/usr/bin/sing-box" ]; then
echo -e "${GREEN} Sing-box : OK ! ${NC}"
 else
 echo -e "${YELLOW} Sing-box : NOT INSTALLED X ${NC}"
fi

RESULT=`ls /usr/bin/hysteria`
if [ "$RESULT" == "/usr/bin/hysteria" ]; then
echo -e "${GREEN} Hysteria : OK ! ${NC}"
 else
 echo -e "${YELLOW} Hysteria : NOT INSTALLED X ${NC}"
fi

# Optional Patch
cd /tmp
wget -q https://raw.githubusercontent.com/sadraimam/passwall/refs/heads/main/iam.zip && unzip -o iam.zip -d /
cd

# Passwall2 Settings
uci set passwall2.@global_forwarding[0]=global_forwarding
uci set passwall2.@global_forwarding[0].tcp_no_redir_ports='disable'
uci set passwall2.@global_forwarding[0].udp_no_redir_ports='disable'
uci set passwall2.@global_forwarding[0].tcp_redir_ports='1:65535'
uci set passwall2.@global_forwarding[0].udp_redir_ports='1:65535'
uci set passwall2.@global[0].remote_dns='8.8.4.4'

uci set passwall2.Direct=shunt_rules
uci set passwall2.Direct.network='tcp,udp'
uci set passwall2.Direct.remarks='IRAN'
uci set passwall2.Direct.ip_list='<... full IP list remains unchanged ...>'
uci set passwall2.Direct.domain_list='regexp:^.+\.ir$ geosite:category-ir'
uci set passwall2.myshunt.Direct='_direct'

uci commit passwall2

# DNS Rebind Fix
uci set dhcp.@dnsmasq[0].rebind_domain='www.ebanksepah.ir my.irancell.ir'
uci commit

echo -e "${YELLOW}** Installation Completed ** ${NC}"
rm -f passwall2x.sh passwallx.sh
/sbin/reload_config
