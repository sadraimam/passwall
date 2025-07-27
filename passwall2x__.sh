#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

echo "Running as root..."
sleep 2
clear

# Create lock directory to prevent errors
mkdir -p /var/lock
touch /var/lock/opkg.lock

uci set system.@system[0].zonename='Asia/Tehran'
uci set network.wan.peerdns="0"
uci set network.wan6.peerdns="0"
uci set network.wan.dns='1.1.1.1'
uci set network.wan6.dns='2001:4860:4860::8888'
uci set system.@system[0].timezone='<+0330>-3:30'
uci commit system
uci commit network
uci commit
/sbin/reload_config

SNNAP=`grep -o SNAPSHOT /etc/openwrt_release | sed -n '1p'`

if [ "$SNNAP" == "SNAPSHOT" ]; then
    echo -e "${YELLOW} SNAPSHOT Version Detected ! ${NC}"
    rm -f passwalls.sh && wget https://raw.githubusercontent.com/sadraimam/passwall/main/passwalls.sh && chmod 777 passwalls.sh && sh passwalls.sh
    exit 1
else           
    echo -e "${GREEN} Updating Packages ... ${NC}"
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

### Install package ###
echo -e "${YELLOW}Cleaning up space before installation...${NC}"
opkg clean
rm -rf /tmp/opkg-lists/*
rm -f /tmp/*.ipk /tmp/*.zip /tmp/*.tar.gz

opkg update
opkg remove dnsmasq
opkg install dnsmasq-full
opkg install wget-ssl
opkg install unzip
opkg install luci-app-passwall2
opkg install kmod-nft-socket
opkg install kmod-nft-tproxy
opkg install ca-bundle
opkg install kmod-inet-diag
opkg install kernel
opkg install kmod-netlink-diag
opkg install kmod-tun
opkg install ipset

### Verify Passwall2 Installation ###
RESULT5=`ls /etc/init.d/passwall2 2>/dev/null`
if [ "$RESULT5" == "/etc/init.d/passwall2" ]; then
    echo -e "${GREEN} Passwall.2 Installed Successfully ! ${NC}"
else
    echo -e "${RED} Can not Download Packages ... Check your internet Connection . ${NC}"
    exit 1
fi

### Verify dnsmasq-full Installation ###
DNS=`ls /usr/lib/opkg/info/dnsmasq-full.control 2>/dev/null`
if [ "$DNS" == "/usr/lib/opkg/info/dnsmasq-full.control" ]; then
    echo -e "${GREEN} dnsmasq-full Installed successfully ! ${NC}"
else           
    echo -e "${RED} Package : dnsmasq-full not installed ! (Bad internet connection .) ${NC}"
    exit 1
fi

### Install Xray-core ###
echo -e "${YELLOW}Cleaning up before Xray installation...${NC}"
rm -f /tmp/xray*
rm -f /tmp/Xray*

opkg install xray-core
RESULT=`ls /usr/bin/xray 2>/dev/null`
if [ "$RESULT" == "/usr/bin/xray" ]; then
    echo -e "${GREEN} XRAY : OK ! ${NC}"
else
    echo -e "${YELLOW} XRAY : NOT INSTALLED ${NC}"
    echo -e "${YELLOW} Installing Xray from GitHub ... ${NC}"
    # Determine architecture
    case $(uname -m) in
        x86_64) ARCH="64" ;;
        aarch64) ARCH="arm64-v8a" ;;
        armv7l) ARCH="arm32-v7a" ;;
        *) ARCH="64" ;;
    esac
    
    wget -O /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-$ARCH.zip"
    unzip -o /tmp/xray.zip xray -d /usr/bin/
    chmod +x /usr/bin/xray
    rm -f /tmp/xray.zip
    
    # Verify installation
    if [ -f "/usr/bin/xray" ]; then
        echo -e "${GREEN} XRAY installed successfully! ${NC}"
    else
        echo -e "${RED} Failed to install XRAY! ${NC}"
    fi
fi

### Install Sing-box ###
echo -e "${YELLOW}Cleaning up before Sing-box installation...${NC}"
rm -f /tmp/sing-box*

# Determine architecture
case $(uname -m) in
    x86_64) ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    armv7l) ARCH="armv7" ;;
    *) ARCH="amd64" ;;
esac

echo -e "${YELLOW} Installing Sing-box from GitHub ... ${NC}"
wget -O /tmp/sing-box.tar.gz "https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-linux-$ARCH.tar.gz"
tar -xzf /tmp/sing-box.tar.gz -C /tmp
cp /tmp/sing-box-*/sing-box /usr/bin/
chmod +x /usr/bin/sing-box
rm -rf /tmp/sing-box*

# Verify installation
if [ -f "/usr/bin/sing-box" ]; then
    echo -e "${GREEN} SING-BOX installed successfully! ${NC}"
else
    echo -e "${RED} Failed to install SING-BOX! ${NC}"
fi

### Install Hysteria ###
echo -e "${YELLOW}Cleaning up before Hysteria installation...${NC}"
rm -f /tmp/hysteria*

echo -e "${YELLOW} Installing Hysteria from GitHub ... ${NC}"
wget -O /usr/bin/hysteria "https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-$ARCH"
chmod +x /usr/bin/hysteria

# Verify installation
if [ -f "/usr/bin/hysteria" ]; then
    echo -e "${GREEN} HYSTERIA installed successfully! ${NC}"
else
    echo -e "${RED} Failed to install HYSTERIA! ${NC}"
fi

### Additional Configuration ###
cd /tmp
rm -f iam.zip
wget -q https://raw.githubusercontent.com/sadraimam/passwall/refs/heads/main/iam.zip
unzip -o iam.zip -d /
cd
rm -f iam.zip

uci set system.@system[0].zonename='Asia/Tehran'
uci set system.@system[0].timezone='<+0330>-3:30'

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

uci commit passwall2
uci commit system

uci set dhcp.@dnsmasq[0].rebind_domain='www.ebanksepah.ir my.irancell.ir'
uci commit

echo -e "${YELLOW}** Installation Completed ** ${NC}"

# Final cleanup
rm -f passwall2x.sh passwallx.sh
rm -rf /tmp/opkg-lists/*
/sbin/reload_config
