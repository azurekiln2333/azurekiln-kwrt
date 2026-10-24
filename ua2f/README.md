# UA2F 修复说明

UA 改写测试通过。浏览器刷新结果尚未确认。
缓冲区参数已恢复。
两个当前接收缓冲区均为 8 MiB。

| 本次改动 | 对应文件或操作 |
| --- | --- |
| 补装队列组件 | 安装 `iptables-mod-nfqueue` 和 `kmod-ipt-nfqueue` |
| 统一防火墙后端 | `/usr/sbin/` 下三个 IPv4 iptables 软链接指向 `xtables-legacy-multi` |
| 缩短 UA | `/etc/config/ua2f` 的 `main.custom_ua` 从 125 字节缩短为 105 字节 |
| 关闭流量卸载 | `/etc/config/firewall` 的 `flow_offloading`、`flow_offloading_hw` 均为 `0` |
| 恢复队列规则 | 重启 UA2F。服务自动生成 IPv4／IPv6 队列 `10010` 规则 |
| 启用开机启动 | 服务管理器在 `/etc/rc.d/` 中生成启动链接 |
| 扩大接收缓冲区 | `/etc/sysctl.conf` 保存 4 MiB 默认值和 8 MiB 上限 |

UA2F 程序没有修改。
`/etc/init.d/ua2f` 没有修改。
服务自动生成 `/var/etc/ua2f.include`。

| 文件或目录 | 用途 |
| --- | --- |
| [ua-rewrite-troubleshooting.md](ua-rewrite-troubleshooting.md) | UA 改写排查 |
| [buffer-troubleshooting.md](buffer-troubleshooting.md) | 间歇失效和缓冲区排查 |
| `config-backup.zip` | 修改前后配置。压缩包内用 `before/` 和 `after/` 区分 |
| `packages/` | 本次固件使用的依赖包 |
| `scripts/` | 本次使用的修复脚本 |

重装系统后，不能只覆盖配置文件。
新系统需要安装 UA2F。
新系统需要安装匹配内核的依赖。
新系统需要匹配防火墙后端。
配置迁移只涉及 UA2F 配置和卸载开关。
不要整份覆盖新系统的 `firewall` 配置。
服务启动后会自动生成规则。

现有依赖包和脚本只适用于本次固件。
本次固件使用 fw3 和内核 `6.12.112`。
路由器备份位于 `/root/router-repair-20261024-1748/`。
