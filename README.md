# 用 Mac 热点和 Clash Verge 让 Kindle 访问日亚

日区亚马逊账号在中国境内经常连不上。Kindle 不能安装 VPN，也不会填写代理。这篇教程用 Mac 开热点，再把热点上的流量送进 Clash Verge 的 TUN，让 Kindle 走日本节点访问日亚。

以下步骤在 macOS 上、用 Clash Verge（核心是 mihomo）实际跑通过：Kindle 实验浏览器可以打开 `https://www.amazon.co.jp`，重启后内置图书商店也可以使用。

## 为什么只开热点不够

Mac 的「互联网共享」会把 Kindle 的流量从你选中的那块物理网卡发出去。Clash 的「允许局域网」只是打开本机代理端口。Kindle 没有代理设置，不会去连这个端口。

还会遇到第二个问题：热点把 DNS 设成 Mac 自己（通常是 `192.168.2.1`）。这个地址由系统解析，不经过 Clash。在中国，`www.amazon.co.jp` 可能被解析成一个根本不是亚马逊的地址。Kindle 连上去会失败，实验浏览器或商店常见提示是错误 100。

所以要做两件事：

1. 把热点网段的 IPv4 流量做 NAT，送进 Clash 的 TUN。
2. 把热点设备的 DNS 查询改送到 `1.1.1.1`，让它跟着隧道走。

## 准备

- Mac 用网线上网。无线网卡要腾出来当热点，同一张 Wi-Fi 不能同时连着路由器又发射热点。打开热点后，Mac 原来的 Wi-Fi 连接会断开。
- 已安装 Clash Verge，并且 TUN 模式能让电脑自己打开日亚。
- Kindle 用数据线连过电脑，系统能够把它识别成磁盘（后面只需要它加入热点，不需要一直插着线）。
- 一个可用的日本节点。日区商店认出口地区，香港或美国节点经常进不去。

先在 Clash Verge 里确认：

- TUN 模式和服务模式都开着。
- 第一次测试可以用全局模式，节点选手动的日本节点。规则模式也可以，只要带 `amazon` 的域名走代理。
- 电脑浏览器能打开 `https://www.amazon.co.jp`。

## 第一步：用网线共享出热点

系统设置 → 通用 → 共享 → 互联网共享：

- 共享来源选以太网。
- 共享给 Wi-Fi，设置热点名称和密码。
- 打开互联网共享。

Kindle 连上这个热点。此时它通常已经有网，但出口仍在国内，日亚还是打不开。

在 Mac 终端确认接口。访问公网的接口应是 `utun` 开头，热点网卡应是 `bridge100`：

```bash
route -n get 1.1.1.1 | awk '/interface:/{print}'
ifconfig bridge100 | awk '/inet /{print}'
```

正常会看到类似：

```text
interface: utun1024
inet 192.168.2.1 netmask 0xffffff00 broadcast 192.168.2.255
```

`utun` 后面的数字每次启动 Clash 都可能变。后面的脚本会自己读取，不要写死。

## 第二步：加载防火墙规则

仓库里的 `scripts/enable-kindle-hotspot.sh` 会做这些事：

- 读取当前 TUN 接口和热点网段。
- 若公网路由不是 `utun`，直接退出。
- 把规则写入锚点 `com.apple/kindle-vpn`，不修改 `/etc/pf.conf`，也不关闭系统包过滤。

在仓库目录执行：

```bash
chmod +x scripts/enable-kindle-hotspot.sh scripts/disable-kindle-hotspot.sh
./scripts/enable-kindle-hotspot.sh
```

终端会向你要 Mac 密码。成功时能看到三条规则：

- `nat on utun...`：热点网段从 Clash 的隧道出去。
- 两条 `rdr`：热点上的 53 端口改送到 `1.1.1.1`。
- `pass in quick on bridge100`：放行这个网段。

`pfctl: Use of -f option...` 是 macOS 的固定提示。因为指定了锚点，规则只写进 `com.apple/kindle-vpn`。`round-robin` 也是 `(utun接口)` 这种写法的正常标记。

脚本会打印一个 token。收尾时如果还要用 `pfctl -X` 释放这次启用，把 token 留着。日常只关热点的话，可以不处理它。

## 第三步：在 Kindle 上验证

把 Kindle 的 Wi-Fi 关掉再打开，让它丢掉刚才解析到的错误地址。然后打开实验浏览器，访问：

```text
https://www.amazon.co.jp
```

能看到日亚首页，这条链路就通了。

不要在 Mac 上用 `dig @192.168.2.1` 判断成败。这条查询从本机发出，不经过 `bridge100`，即使用了重定向，结果仍可能是污染地址。

## 图书商店仍然打不开

实验浏览器能开日亚，只说明网页通了。内置图书商店走另一组服务器，并且按设备上绑定的账户决定商店区域。

如果提示「Kindle 商店暂不可用，请稍后重试」：

1. 在电脑浏览器（同样走日本节点）打开 `https://www.amazon.co.jp/mycd`，进入设置，把国家/地区设为日本。
2. 在 Kindle 上打开「设置 → 我的账户」。未注册就用日区账号注册；如果还绑着其他区域的账号，先注销再注册。
3. 注册完成后重启 Kindle，再打开图书商店。

重启前，商店可能仍去连北美接口。重启并完成日区账户绑定后，商店会改用日区服务。

## 这组规则会不会影响 Mac

不会改变 Mac 自己的上网。规则只匹配热点网段（默认 `192.168.2.0/24`）里的设备。

连上这个热点的其他设备也会从 Clash 的日本节点出去，DNS 同样被送到 `1.1.1.1`。

下面几种情况会让 Kindle 再次失败，Mac 本身仍然正常：

- Clash 重启后 TUN 编号变了。重新执行 `scripts/enable-kindle-hotspot.sh`。
- Clash 关着，热点还开着。DNS 仍被强制送到 `1.1.1.1`，域名可能解析失败。
- Mac 重启。规则在内存里，重启后消失，需要重新执行脚本。

不用的时候，关掉互联网共享即可。Mac 的 Wi-Fi 会回到原来的局域网。

要卸掉规则：

```bash
./scripts/disable-kindle-hotspot.sh
```

不要执行 `sudo pfctl -d`，那会关掉系统正在使用的包过滤。

## 文件

- `scripts/enable-kindle-hotspot.sh`：检测接口并加载规则。
- `scripts/disable-kindle-hotspot.sh`：清空 `com.apple/kindle-vpn` 锚点。
