#!/bin/sh
# Start a temporary loopback-only HTTP endpoint to verify both IP families.
set -eu
testdir=$(mktemp -d /tmp/ua2f-verify.XXXXXX)
server_pid=
cleanup() {
    if [ -n "$server_pid" ]; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi
    case "$testdir" in
        /tmp/ua2f-verify.??????) rm -rf -- "$testdir" ;;
        *) printf 'Unexpected temporary path: %s\n' "$testdir" >&2; return 1 ;;
    esac
}
trap cleanup EXIT HUP INT TERM
command -v nginx >/dev/null
cat > "$testdir/nginx.conf" <<EOF
pid $testdir/nginx.pid;
error_log stderr;
events { worker_connections 32; }
http {
    access_log off;
    server {
        listen 127.0.0.1:18089;
        listen [::1]:18089;
        location / { default_type text/plain; return 200 "\$http_user_agent\\n"; }
    }
}
EOF
nginx -p "$testdir/" -c "$testdir/nginx.conf" -g 'daemon off;' >"$testdir/server.log" 2>&1 &
server_pid=$!
sleep 1
kill -0 "$server_pid" 2>/dev/null || { cat "$testdir/server.log"; exit 1; }
# Use the exact 111-byte browser UA from the failed user check. A longer probe
# would miss the custom-UA truncation false negative fixed in the follow-up.
agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36'
expected=$(uci -q get ua2f.main.custom_ua)
ipv4=$(curl --noproxy '*' -4 -fsS --max-time 10 -A "$agent" http://127.0.0.1:18089/ | sed 's/[[:space:]]*$//')
[ "$ipv4" = "$expected" ] || { printf 'IPv4 failed: %s\n' "$ipv4"; exit 1; }
printf 'IPv4 PASS: %s\n' "$ipv4"
ipv6=$(curl --noproxy '*' -6 -g -fsS --max-time 10 -A "$agent" 'http://[::1]:18089/' | sed 's/[[:space:]]*$//')
[ "$ipv6" = "$expected" ] || { printf 'IPv6 failed: %s\n' "$ipv6"; exit 1; }
printf 'IPv6 PASS: %s\n' "$ipv6"
iptables-legacy -t mangle -nvL ua2f
ip6tables-legacy -t mangle -nvL ua2f
cat /proc/net/netfilter/nfnetlink_queue
