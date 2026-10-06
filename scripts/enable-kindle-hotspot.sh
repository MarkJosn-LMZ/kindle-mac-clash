#!/bin/sh
# 把 macOS 互联网共享热点的 IPv4 流量送进 Clash Verge 的 TUN，
# 并把热点客户端的 DNS 重定向到 1.1.1.1。
# 只写入锚点 com.apple/kindle-vpn，不修改 /etc/pf.conf。

set -eu

TUN_IF=$(route -n get 1.1.1.1 | awk '/interface:/{print $2}')
HOTSPOT_IP=$(ifconfig bridge100 2>/dev/null | awk '/inet /{print $2; exit}')

if [ -z "${TUN_IF}" ] || [ -z "${HOTSPOT_IP}" ]; then
  echo "没有找到 TUN 或 bridge100。先打开 Clash 的 TUN，并开启「以太网 → Wi-Fi」互联网共享。" >&2
  exit 1
fi

case "${TUN_IF}" in
  utun*) ;;
  *)
    echo "访问 1.1.1.1 的接口是 ${TUN_IF}，不是 utun。先确认 Clash TUN 已接管本机流量。" >&2
    exit 1
    ;;
esac

HOTSPOT_NET=$(printf '%s\n' "${HOTSPOT_IP}" | awk -F. '{print $1"."$2"."$3".0/24"}')
PF_RULE_FILE=$(mktemp -t kindle-vpn)

cleanup() {
  rm -f "${PF_RULE_FILE}"
}
trap cleanup EXIT

cat > "${PF_RULE_FILE}" << EOF
nat on ${TUN_IF} inet from ${HOTSPOT_NET} to any -> (${TUN_IF})
rdr pass on bridge100 inet proto udp from ${HOTSPOT_NET} to any port 53 -> 1.1.1.1 port 53
rdr pass on bridge100 inet proto tcp from ${HOTSPOT_NET} to any port 53 -> 1.1.1.1 port 53
pass in quick on bridge100 inet from ${HOTSPOT_NET} to any keep state
EOF

echo "TUN=${TUN_IF}"
echo "热点地址=${HOTSPOT_IP}"
echo "热点网段=${HOTSPOT_NET}"
echo
echo "即将加载的规则："
cat "${PF_RULE_FILE}"
echo

sudo pfctl -vnf "${PF_RULE_FILE}"
sudo pfctl -E
sudo pfctl -a com.apple/kindle-vpn -f "${PF_RULE_FILE}"
echo
echo "已加载的 NAT / 重定向："
sudo pfctl -a com.apple/kindle-vpn -sn
echo
echo "已加载的放行规则："
sudo pfctl -a com.apple/kindle-vpn -sr
echo
echo "把上面 pfctl -E 打印的 Token 记下来。关闭热点即可停止共享；要卸掉规则请运行 scripts/disable-kindle-hotspot.sh。"
