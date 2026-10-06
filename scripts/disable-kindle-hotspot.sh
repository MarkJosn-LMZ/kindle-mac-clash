#!/bin/sh
# 清空 kindle 热点锚点。不执行 pfctl -d，避免关掉系统正在使用的包过滤。

set -eu

sudo pfctl -a com.apple/kindle-vpn -F all
echo "已清空锚点 com.apple/kindle-vpn。"
echo "如果还保存着 enable 脚本打印的 Token，可以再执行：sudo pfctl -X <Token>"
echo "然后到「系统设置 → 通用 → 共享」关掉互联网共享。"
