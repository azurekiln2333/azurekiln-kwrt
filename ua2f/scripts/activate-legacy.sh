#!/bin/sh
# This fw3 router uses the legacy ruleset. No firewall/network restart needed.
set -eu
command -v fw3 >/dev/null
if command -v fw4 >/dev/null; then
    echo 'fw4 is present; this script is only for the verified fw3 router.'
    exit 1
fi
[ -x /usr/sbin/xtables-legacy-multi ]
opkg status iptables-mod-nfqueue | grep -q '^Status: install .* installed$'
opkg status kmod-ipt-nfqueue | grep -q '^Status: install .* installed$'
backup=/root/router-repair-20261024-1748/before
mkdir -p "$backup/etc/config" "$backup/etc/init.d"
[ -f "$backup/etc/config/ua2f" ] || cp -p /etc/config/ua2f "$backup/etc/config/ua2f"
[ -f "$backup/etc/init.d/ua2f" ] || cp -p /etc/init.d/ua2f "$backup/etc/init.d/ua2f"
if [ ! -f "$backup/backend-links.txt" ]; then
    ls -l /usr/sbin/iptables /usr/sbin/iptables-save /usr/sbin/iptables-restore > "$backup/backend-links.txt"
fi
# Prove both families can create queue rules before changing the live service.
for tool in iptables-legacy ip6tables-legacy; do
    "$tool" -t mangle -N ua2f_repair_check
    if ! "$tool" -t mangle -A ua2f_repair_check -j NFQUEUE --queue-num 10010 --queue-bypass; then
        "$tool" -t mangle -F ua2f_repair_check
        "$tool" -t mangle -X ua2f_repair_check
        exit 1
    fi
    "$tool" -t mangle -F ua2f_repair_check
    "$tool" -t mangle -X ua2f_repair_check
done
# Stop using the old backend first, so its incomplete IPv4 rules are removed.
/etc/init.d/ua2f stop
ln -sfn xtables-legacy-multi /usr/sbin/iptables
ln -sfn xtables-legacy-multi /usr/sbin/iptables-save
ln -sfn xtables-legacy-multi /usr/sbin/iptables-restore
/etc/init.d/ua2f enable
/etc/init.d/ua2f start
attempt=0
while ! grep -q '^10010 ' /proc/net/netfilter/nfnetlink_queue; do
    attempt=$((attempt + 1))
    [ "$attempt" -lt 10 ] || { echo 'UA2F queue did not start'; exit 1; }
    sleep 1
done
iptables --version
ip6tables --version
/etc/init.d/ua2f status
iptables-legacy -t mangle -S ua2f
ip6tables-legacy -t mangle -S ua2f
iptables-legacy -t mangle -C ua2f -j NFQUEUE --queue-num 10010 --queue-bypass
ip6tables-legacy -t mangle -C ua2f -j NFQUEUE --queue-num 10010 --queue-bypass
cat /proc/net/netfilter/nfnetlink_queue
