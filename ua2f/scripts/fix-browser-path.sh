#!/bin/sh
# Browser follow-up: avoid an identical truncated UA and flow-offload bypass.
set -eu
command -v fw3 >/dev/null
[ "$(uci -q get ua2f.main.mode)" = NFQUEUE ]
backup=/root/router-repair-20261024-1748/browser-followup-before
mkdir -p "$backup/etc/config"
for config in ua2f firewall; do
    [ -f "$backup/etc/config/$config" ] || cp -p "/etc/config/$config" "$backup/etc/config/$config"
done
# 105 bytes: the complete marker now fits the user's 111-byte browser UA.
agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/155.0.0.0 Safari/537.36 CoolApkMarket'
uci set ua2f.main.custom_ua="$agent"
uci set 'firewall.@defaults[0].flow_offloading=0'
uci set 'firewall.@defaults[0].flow_offloading_hw=0'
uci commit ua2f
uci commit firewall
/etc/init.d/firewall reload
/etc/init.d/ua2f restart
attempt=0
while ! grep -q '^10010 ' /proc/net/netfilter/nfnetlink_queue; do
    attempt=$((attempt + 1))
    [ "$attempt" -lt 10 ] || { echo 'UA2F queue did not start'; exit 1; }
    sleep 1
done
/etc/init.d/ua2f status
uci get ua2f.main.custom_ua
uci get 'firewall.@defaults[0].flow_offloading'
uci get 'firewall.@defaults[0].flow_offloading_hw'
if iptables-save -t filter | grep -q -- '-j FLOWOFFLOAD'; then
    echo 'Unexpected active FLOWOFFLOAD rule' >&2
    exit 1
fi
iptables -t mangle -C ua2f -j NFQUEUE --queue-num 10010 --queue-bypass
ip6tables -t mangle -C ua2f -j NFQUEUE --queue-num 10010 --queue-bypass
echo 'PASS: UA2F restarted; IPv4/IPv6 queue rules present; flow offloading disabled.'
