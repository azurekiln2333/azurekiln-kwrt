#!/bin/sh
# Run on this router beside the verified netlink-rcvbuf helper.
# Updates only receive-buffer parameters and existing UA2F Netlink sockets.
set -eu

backup=$(CDPATH= cd "$(dirname "$0")" && pwd)
helper="$backup/netlink-rcvbuf"
[ -x "$helper" ]
[ ! -e "$backup/before-state.txt" ] || { echo 'This repair directory was already used.'; exit 1; }
[ "$(uname -m)" = x86_64 ]
pid=$(pidof ua2f)
case "$pid" in ''|*[!0-9]*) echo 'Expected one UA2F process.'; exit 1 ;; esac

mkdir -p "$backup/before/etc/sysctl.d" "$backup/after/etc/sysctl.d"
cp -p /etc/sysctl.conf "$backup/before/etc/sysctl.conf"
cp -p /etc/sysctl.d/50-local.conf "$backup/before/etc/sysctl.d/50-local.conf"
{
    date
    printf 'ua2f_pid=%s\n' "$pid"
    sysctl net.core.rmem_default net.core.rmem_max
    "$helper" "$pid"
    cat /proc/net/netfilter/nfnetlink_queue
    awk 'NR==1 || $2==12' /proc/net/netlink
} > "$backup/before-state.txt"

# Preserve file permissions and unrelated parameters.
temporary=$(mktemp /etc/sysctl.conf.ua2f-buffer.XXXXXX)
cp -p /etc/sysctl.conf "$temporary"
awk '!/^[[:space:]]*net[.]core[.]rmem_(default|max)[[:space:]]*=/' /etc/sysctl.conf > "$temporary"
printf '\n# UA2F Netlink receive buffers\nnet.core.rmem_default=4194304\nnet.core.rmem_max=8388608\n' >> "$temporary"
mv "$temporary" /etc/sysctl.conf

temporary=$(mktemp /etc/sysctl.d/50-local.conf.ua2f-buffer.XXXXXX)
cp -p /etc/sysctl.d/50-local.conf "$temporary"
awk '!/^[[:space:]]*net[.]core[.]rmem_max[[:space:]]*=/' /etc/sysctl.d/50-local.conf > "$temporary"
mv "$temporary" /etc/sysctl.d/50-local.conf

# Do not reload unrelated sysctl values or restart any service.
sysctl -w net.core.rmem_max=8388608 net.core.rmem_default=4194304
[ "$(pidof ua2f)" = "$pid" ]
"$helper" "$pid" --rcvbuf 4194304 > "$backup/applied-sockets.txt"
[ "$(grep -c 'rcvbuf_after=8388608$' "$backup/applied-sockets.txt")" -ge 2 ]
if grep -v 'rcvbuf_after=8388608$' "$backup/applied-sockets.txt"; then
    echo 'Unexpected socket buffer size.' >&2
    exit 1
fi
[ "$(sysctl -n net.core.rmem_default)" = 4194304 ]
[ "$(sysctl -n net.core.rmem_max)" = 8388608 ]
[ "$(pidof ua2f)" = "$pid" ]

cp -p /etc/sysctl.conf "$backup/after/etc/sysctl.conf"
cp -p /etc/sysctl.d/50-local.conf "$backup/after/etc/sysctl.d/50-local.conf"
{
    date
    printf 'ua2f_pid=%s\n' "$pid"
    sysctl net.core.rmem_default net.core.rmem_max
    "$helper" "$pid"
    cat /proc/net/netfilter/nfnetlink_queue
    awk 'NR==1 || $2==12' /proc/net/netlink
} > "$backup/after-state.txt"
cat "$backup/applied-sockets.txt"
cat "$backup/after-state.txt"
printf 'PASS: configuration and live UA2F buffers updated; no services restarted. Backup: %s\n' "$backup"
