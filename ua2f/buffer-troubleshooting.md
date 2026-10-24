# 间歇失效与缓冲区排查

本文区分 UDP 数据包与 UDP 连接销毁通知。
旧排查发现了连接事件接收缓冲区溢出。
旧排查没有证明它导致全部断网。

## 旧记录在哪里

旧工作区是 `D:\My2KProjects`。
旧修复记录位于：

```text
D:\My2KProjects\router-ua2f-repair\README.md
```

旧会话编号：

```text
01a1453e-af6b-7311-b2e9-0b720636ebb5
```

修复时间是 2026-10-17 01:03 CST。

## UDP 到底进了哪里

Netlink 是内核向程序发送消息的通道。
conntrack 是内核记录连接状态的机制。

| 通道 | 内容 | 本次检查结果 |
| --- | --- | --- |
| NFQUEUE | 需要交给 UA2F 的数据包 | IPv4／IPv6 入口规则限定 TCP |
| conntrack 事件 | 连接销毁通知 | 旧版本订阅没有按 TCP 过滤通知 |

旧版本使用以下订阅：

```c
nfct_open(CONNTRACK, NF_NETLINK_CONNTRACK_DESTROY);
```

这个订阅包含 UDP 连接销毁通知。
这些通知会占用 Netlink 接收缓冲区。
这不表示 UA2F 把 UDP 数据包送入 NFQUEUE。

旧记录显示，约一万条连接中有九千多条 UDP。
当时事件套接字累计丢失 15121 条通知。
日志出现 `No buffer space available`。
UDP 连接集中过期可能触发通知突发。
当时没有连续采样证明突发的具体来源。

## 以前修改了哪里

`/etc/sysctl.conf` 增加了两项配置：

```text
net.core.rmem_default=4194304
net.core.rmem_max=8388608
```

默认接收缓冲区为 4 MiB。
普通缓冲区申请的上限为 8 MiB。

`/etc/sysctl.d/50-local.conf` 删除了冲突项：

```text
net.core.rmem_max=262144
```

旧修复还调整了已经打开的套接字。
工具名称是 `netlink-rcvbuf`。
工具通过 `SO_RCVBUF` 申请 4 MiB。
内核按加倍记账方式报告 8 MiB。
当时两个 UA2F Netlink 套接字均报告 8 MiB。

当时没有重启 UA2F 或防火墙。
旧修复没有添加 TCP 事件过滤。

## 默认值与实际容量

`rmem_default` 控制新套接字的默认容量。
`rmem_max` 限制普通 `SO_RCVBUF` 申请。
提高上限不会自动扩大已有套接字。

旧进程的 8 MiB 来自工具在线调整。
旧修复预期新进程使用 4 MiB 默认容量。
工具在线调整的数值不会跨进程重启保留。

## 本次修复前的读数

读取时间为 2026-10-24 23:36 至 2026-10-25 00:03 CST。

| 项目 | 读数或文件 |
| --- | --- |
| `net.core.rmem_default` | `212992` 字节，约 208 KiB |
| `net.core.rmem_max` | `262144` 字节，256 KiB |
| 256 KiB 上限来源 | `/etc/sysctl.d/50-local.conf` |
| 另一份上限配置 | `/etc/sysctl.d/50-adguardhome.conf` 写有 `7500000` |
| NFQUEUE 套接字累计丢包 | `209` |
| 连接事件套接字累计丢失 | `218` |
| 软件／硬件流量卸载 | 两项均为 `0` |

启动脚本先读取 `/etc/sysctl.d/*.conf`。
启动脚本最后读取 `/etc/sysctl.conf`。
`50-local.conf` 覆盖了前面的接收上限。
修复前的 `/etc/sysctl.conf` 没有旧修复参数。
旧修复参数消失的原因尚未查明。

两个丢失计数属于不同套接字。
不要把两个计数相加。
累计计数不能证明当前仍持续丢失。

本次重新上传了旧缓冲区工具。
修复前，两个套接字的实际容量均为 212992 字节。

## 本次修复结果

修复时间为 2026-10-25 01:23 CST。

`/etc/sysctl.conf` 保存以下配置：

```text
net.core.rmem_default=4194304
net.core.rmem_max=8388608
```

`/etc/sysctl.d/50-local.conf` 删除了冲突项。
该项原值是 `net.core.rmem_max=262144`。
连接数量上限没有修改。

| 检查项 | 修复后读数 |
| --- | --- |
| 系统默认接收容量 | `4194304` 字节，4 MiB |
| 普通接收容量申请上限 | `8388608` 字节，8 MiB |
| NFQUEUE 套接字实际容量 | `8388608` 字节，8 MiB |
| 连接事件套接字实际容量 | `8388608` 字节，8 MiB |
| UA2F 进程编号 | 修改前后均为 `32278` |

本次通过工具在线扩大了两个现有套接字。
本次没有重启 UA2F 或防火墙。
新套接字的默认容量为 4 MiB。
现有套接字的 8 MiB 不会跨进程重启保留。
尚未验证整机重启后的实际容量。
扩大缓冲区不代表间歇失效已经解决。

修复脚本位于 `scripts/fix-buffer.sh`。
路由器备份和工具位于：

```text
/root/ua2f-buffer-repair-20261025.IIBcEg/
```

## 下次失效时怎么排查

重启前保存现场。
在路由器运行：

```sh
date
/etc/init.d/ua2f status
sysctl net.core.rmem_default net.core.rmem_max
cat /proc/net/netfilter/nfnetlink_queue
cat /proc/net/netlink
ls -l /proc/$(pidof ua2f)/fd
logread | grep -iE 'ua2f|no buffer|conntrack'
iptables -t mangle -S
ip6tables -t mangle -S
```

1. 用套接字 inode 关联两处输出。
2. 间隔 60 秒再次读取计数。
3. 检查哪一个丢失计数增长。
4. 分别测试 DNS、HTTP 和代理出口。

`/proc/net/netlink` 的 `Rmem` 是当前占用。
这个字段不是缓冲区容量。

如果事件丢失增长，检查接收缓冲区。
如果 NFQUEUE 丢包增长，检查数据包处理。
如果两处计数稳定，继续检查 DNS 和代理。

防火墙重载还会重载 OpenClash 规则。
一起重启两项服务会掩盖恢复原因。
需要重启时，每次只重启一项服务。

后续可评估 TCP 事件过滤。
过滤应发生在通知进入套接字之前。
仅在回调中忽略 UDP，仍会占用接收缓冲区。
该方案需要修改 UA2F 的订阅实现。
本次没有应用该方案。
