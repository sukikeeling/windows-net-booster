# Windows 网络极速优化 v5.0 / Windows Network Booster (Extreme Turbo Edition)

> 你的网速与延迟，可能正被 Windows 的"默认保守策略"偷偷按住。  
> 一键解除 Windows 系统级协议栈与硬件限制 —— **榨干宽带吞吐，实现毫秒级极速发包**。

一个专业的 PowerShell 一键全栈网络优化工具（`net-boost.bat` 纯 ASCII 外壳 + `net-boost.ps1` 核心优化引擎），支持 **BBR2 / CUBIC 激进拥塞控制**、**0 延迟即刻发包**、**Winsock AFD 1MB 内核缓冲**、**硬件分载 (RSS/RSC)**、**Wi-Fi 6E 硬件吞吐助推**、**极速 DNS 优选** 与 **多并发实时测速诊断**。

**⚠️ 本工具修改的是 Windows 系统底层网络栈与网卡硬件参数，支持一键安全恢复出厂设置。**

---

## ⚡ v5.0 重磅升级亮点 (Extreme Turbo)

| 核心维度 | 传统优化脚本 / Windows 默认 | v5.0 Extreme Turbo 架构升级 |
| :--- | :--- | :--- |
| **拥塞控制算法** | 使用已被现代 Win10/11 弃用的 `netsh ctcp` | 探测并全面启用 **BBR2 (Bottleneck Bandwidth & RTT v2)** / **CUBIC**，抗丢包且不腰斩拥塞窗口 |
| **TCP 初始爆发** | 慢启动 2~4 MSS，连接建立爬升缓慢 | **16 MSS 初始突发窗口**，握手后瞬间全速发包；禁用 `CwndRestart`（空闲不退回慢启动） |
| **小包延迟与即时发包** | 仅注册表部分接口注入 Nagle | **0 延迟发包全套方案**：`TCPNoDelay=1` + `TcpAckFrequency=1` + `TcpDelAckTicks=0` + `DelayedAckTimeoutMs=10` |
| **丢包极速重传** | 默认最小 RTO 为 300ms（丢包卡顿明显） | **`MinRtoMs = 20ms`**，毫秒级检测丢包并秒发重传包，极大提升竞技游戏与突发流量流畅度 |
| **Winsock AFD 内核缓冲** | 未对 AFD 内核驱动进行优化 | 注入 **AFD 1MB 极速发送/接收缓冲区**，设置 `FastSendDatagramThreshold=1500`（UDP/TCP 零排队直通发包） |
| **系统与多媒体节流** | 默认限制 10,000 包/秒，系统保留 20% | `NetworkThrottlingIndex = 0xFFFFFFFF` 彻底解禁节流；`SystemResponsiveness = 0` 算力 100% 倾斜网络 |
| **并发端口池能力** | 默认端口数有限，容易发生端口耗尽 | `MaxUserPort = 65534` 扩展至 **64,510 个并发端口**，`TcpTimedWaitDelay = 30s` 极速释放连接 |
| **网卡硬件高级特性** | 未调优无线/有线网卡高级属性 | 针对 **Wi-Fi 6/6E/7 (如 Intel AX211)** 开启 **吞吐量助推器 (Throughput Booster)**，关闭 **MIMO 节能 (SMPS)**；有线网卡拉满发送/接收描述符并禁用 EEE 节能 |
| **硬件分载 (Offload)** | 部分开启或受限 | **RSS（多核软中断分摊）+ RSC（硬件大包聚合）+ TaskOffload 全开**，关闭节电合并延迟 |

---

## 🛠️ 主菜单功能一览

1. **[1] ⚡ 极限全栈暴力优化**：一键应用全部 9 项核心加速（BBR2/CUBIC + 16 MSS 爆发 + 0 延迟发包 + AFD 缓冲区 + 硬件卸载）。
2. **[2] 🎯 竞技游戏 / 毫秒级超低延迟模式**：聚焦 0 延迟 ACK、20ms 最小 RTO、禁用 Nagle 与解除网络节流。
3. **[3] 🚀 极速大带宽吞吐模式**：专为满速多线程下载（Steam/BT/IDM）设计，拉满 1MB 内核窗口与 65,534 并发端口池。
4. **[4] 📶 网卡硬件高级特性专项调优**：深度扫描并释放 Wi-Fi 6/6E / 以太网卡最高硬件性能。
5. **[5] 📡 极速 DNS 优选与一键切换**：内置阿里 DNS (223.5.5.5)、腾讯 DNSPod (119.29.29.29)、Cloudflare (1.1.1.1)、114 及自动恢复 DHCP。
6. **[6] 📊 网络状态诊断 & 实时多并发发包/延迟实测**：内置多主干节点测速与 10 组高并发 TCP 握手发包速率测试。
7. **[7] 🔄 一键恢复 Windows 原生出厂设置**：全自动清理自定义注册表并还原默认 TCP 栈与电源方案。
8. **[8] 退出**。

---

## 🚀 使用方法

1. 下载 `net-boost.bat` 和 `net-boost.ps1`，放在**同一个文件夹**下。
2. **右键 `net-boost.bat` → 选择“以管理员身份运行”**（或直接双击，未提权时支持一键自动申请提权）。
3. 在主菜单输入 `1` 运行【⚡ 极限全栈暴力优化】。
4. 跑完全部模块后，根据提示输入 `Y` 重启电脑（**底层协议栈与网卡参数重启后完全生效**）。

---

## 🔄 一键恢复默认设置

如果需要恢复 Windows 原生网络配置，随时重新运行脚本并在主菜单选择 **`7`**：

- 重置 TCP 模板至 Windows 官方默认标准
- 清理 Nagle 与 ACK 注册表自定义参数
- 清理 Winsock AFD 内核自定义缓冲区
- 删除 QoS 预留、多媒体网络节流与传递优化注册表项
- 重置 Winsock / IP 协议栈并刷新 DNS
- 恢复优化前的原系统电源方案

---

## 🛡️ 为什么是 bat + ps1 架构

- `net-boost.bat`：纯 ASCII 外壳，仅一行调用，杜绝 CMD 乱码与递归崩溃。
- `net-boost.ps1`：以标准 `UTF-8 with BOM` 编码存储，承载全部底层优化、异常捕获与诊断实测逻辑。

---

## 兼容性

- 支持 **Windows 11 / Windows 10 (x64)** 所有主流版本
- 自动适配 Wi-Fi 6 / 6E / 7 无线网卡与 Realtek / Intel / Broadcom 千兆/万兆有线网卡

---

## License

[MIT](LICENSE)
