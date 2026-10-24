# UA 改写排查

本文记录 2026-10-24 的排查。
设备使用 Kwrt、fw3 和 UA2F `5.2.0-r5`。
UA 指 HTTP 请求中的 `User-Agent` 字段。
NFQUEUE 指内核向程序投递数据包的队列。

## 排查顺序

1. 检查访问路径。
2. 检查队列组件。
3. 检查防火墙后端。
4. 检查队列规则。
5. 检查改写后的 UA。
6. 检查流量卸载。

## 1. 检查访问路径

让测试请求经过这台路由器。
Wi-Fi 优先时，浏览器可能经过其他网关。
代理或 VPN 也可能改变访问路径。

使用明文 HTTP 测试。
HTTPS 会加密 UA 字段。
本次修复不能改写 HTTPS 内的 UA。

浏览器检测地址：

```text
http://ua-check.stagoh.com/
```

## 2. 检查队列组件

原系统缺少两个组件。
进程启动不代表数据包进入队列。

| 组件 | 安装文件 |
| --- | --- |
| `iptables-mod-nfqueue` | `/usr/lib/iptables/libxt_NFQUEUE.so` |
| `kmod-ipt-nfqueue` | `/lib/modules/6.12.112/xt_NFQUEUE.ko` |
| 模块加载配置 | `/etc/modules.d/ipt-nfqueue` |

这两个组件已安装。
更换内核后需要重新匹配组件版本。

## 3. 检查防火墙后端

系统使用 fw3 的 legacy 规则。
原 IPv4 iptables 命令却使用 nft 后端。

以下三个软链接已指向 `xtables-legacy-multi`：

```text
/usr/sbin/iptables
/usr/sbin/iptables-save
/usr/sbin/iptables-restore
```

## 4. 检查队列规则

重启 UA2F 后，服务自动生成规则。
IPv4 和 IPv6 都使用队列 `10010`。
启动脚本内容没有修改。

在路由器运行：

```sh
/etc/init.d/ua2f status
iptables --version
ip6tables --version
iptables -t mangle -S
ip6tables -t mangle -S
cat /proc/net/netfilter/nfnetlink_queue
```

检查 UA2F 链的入口规则。
当前入口规则含 `-p tcp`。
不要只看链内的 NFQUEUE 规则。

## 5. 检查改写后的 UA

原浏览器 UA 长 111 字节。
原配置长 125 字节。
UA2F 截断了超出原字段长度的内容。
尾部的 `CoolApkMarket` 标记因此消失。
服务器收到的 UA 与浏览器原 UA 相同。

本次修改 `/etc/config/ua2f`。
修改项是 `main.custom_ua`。
新 UA 长 105 字节。
新 UA 保留 `CoolApkMarket` 标记。

用原始 111 字节 UA 再次测试。
服务器收到了含标记的新 UA。

## 6. 检查流量卸载

原规则包含 `FLOWOFFLOAD --hw`。
流量卸载可能绕过 UA2F 的逐包处理。

本次修改 `/etc/config/firewall`。
修改位置是 `config defaults` 段：

```text
option flow_offloading '0'
option flow_offloading_hw '0'
```

提交配置后，防火墙完成重载。
随后 UA2F 完成重启。

## 验证范围

- 路由器发起的公网 HTTP 改写测试通过。
- 本地 IPv4／IPv6 HTTP 改写测试通过。
- UA2F 服务重启后，规则恢复。
- 浏览器刷新结果尚未确认。
- 公网 IPv6 和整机重启尚未验证。

缓冲区问题见 [buffer-troubleshooting.md](buffer-troubleshooting.md)。
