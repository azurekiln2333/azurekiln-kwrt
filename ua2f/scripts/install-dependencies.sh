#!/bin/sh
# For this router only: Kwrt x86_64, kernel 6.12.112~1-r1, xtables 1.8.10-r3.
set -eu
[ "$(uname -r)" = "6.12.112" ] || { echo 'Kernel mismatch'; exit 1; }
opkg status kernel | grep -q '^Version: 6.12.112~1-r1$'
opkg status libxtables12 | grep -q '^Version: 1.8.10-r3$'
dest=/root/router-repair-20261024-1748/packages
mkdir -p "$dest"
cd "$dest"
curl --fail --location --connect-timeout 10 --max-time 50 --retry 1 \
  'https://dl.openwrt.ai/releases/25.12/targets/x86/64/6.12.112/kmod-ipt-nfqueue_6.12.112-r1_x86_64.ipk' \
  -o kmod-ipt-nfqueue_6.12.112-r1_x86_64.ipk
curl --fail --location --connect-timeout 10 --max-time 50 --retry 1 \
  'https://dl.openwrt.ai/releases/25.12/targets/x86/64/6.12.112/iptables-mod-nfqueue_1.8.10-r3_x86_64.ipk' \
  -o iptables-mod-nfqueue_1.8.10-r3_x86_64.ipk
cat > SHA256SUMS <<'SUMS'
f3615bdc7bb573d033a0bb5df4a51e88b645c3d5f615a8e2e896ad2882635bf4  kmod-ipt-nfqueue_6.12.112-r1_x86_64.ipk
05fe9cc2a7214c48e5d467d97d87113271cfc7d73f8fe0d5cca55d968df7c9d6  iptables-mod-nfqueue_1.8.10-r3_x86_64.ipk
SUMS
sha256sum -c SHA256SUMS
opkg --noaction install ./kmod-ipt-nfqueue_6.12.112-r1_x86_64.ipk ./iptables-mod-nfqueue_1.8.10-r3_x86_64.ipk
opkg install ./kmod-ipt-nfqueue_6.12.112-r1_x86_64.ipk ./iptables-mod-nfqueue_1.8.10-r3_x86_64.ipk
