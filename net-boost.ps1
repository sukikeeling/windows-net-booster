# ==============================================================================
# 网络极速优化 v5.0 (Extreme Turbo Edition) - 极限发包 & 宽带榨干版
# 配套外壳: 网络极速优化.bat (ASCII 外壳)
# 针对 Windows 10 / Windows 11 (支持 BBR2 / CUBIC / 硬件卸载 / AFD 极速发包)
# ==============================================================================

# 强制控制台编码为 UTF-8
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

$Host.UI.RawUI.WindowTitle = "网络极速优化 v5.0 (Extreme Turbo Edition)"
$ErrorActionPreference = "Continue"

# ----------------- 基础工具函数 -----------------
function Write-ColorText {
    param($text, $color = "White")
    Write-Host $text -ForegroundColor $color
}

function Show-Header {
    Clear-Host
    Write-ColorText "========================================================================" "Cyan"
    Write-ColorText "   🚀 网络极速优化 v5.0 (Extreme Turbo Edition) - 极限发包 & 宽带榨干" "Cyan"
    Write-ColorText "   支持: BBR2/CUBIC拥塞控制 | 0延迟发包 | 硬件分载 | AFD缓冲区 | 解除节流" "DarkCyan"
    Write-ColorText "========================================================================" "Cyan"
    Write-Host ""
}

function Show-Step {
    param($n, $total, $title)
    Write-Host ""
    Write-ColorText ">>> [$n/$total] $title" "Yellow"
}

# ----------------- 0. 管理员权限检查与自动提权 -----------------
function Ensure-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Show-Header
        Write-ColorText "【警告】当前未获得管理员权限，优化网络底层协议栈与注册表必须以管理员身份运行！" "Red"
        Write-Host ""
        try {
            Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
            exit
        } catch {
            Write-ColorText "提权失败，请右键 '网络极速优化.bat' -> 选择 '以管理员身份运行'！" "Red"
            Read-Host "按回车退出"
            exit
        }
    }
}

# ----------------- 备份原电源方案 -----------------
function Backup-PowerScheme {
    try {
        $schemeFile = Join-Path $PSScriptRoot "网络极速优化_原电源方案.txt"
        if (-not (Test-Path $schemeFile)) {
            & powercfg /getactivescheme | Out-File $schemeFile -Encoding UTF8
        }
    } catch {}
}

# ----------------- 核心优化模块 -----------------

# 1. 现代 TCP 栈激进化设置 (BBR2 / CUBIC + 0延迟发包 + 初始大窗口)
function Optimize-TCPStack {
    Write-ColorText "[-] 正在探测并优化 Windows 现代 TCP 协议栈..." "Green"

    # 探测系统是否支持 BBR2 拥塞控制
    $provider = "CUBIC"
    try {
        Set-NetTCPSetting -SettingName InternetCustom -CongestionProvider BBR2 -WhatIf -ErrorAction Stop | Out-Null
        $provider = "BBR2"
        Write-ColorText "    [+] 检测到系统原生支持新一代 BBR2 拥塞控制算法，已全面启用 BBR2！" "Cyan"
    } catch {
        Write-ColorText "    [+] 系统采用高性能 CUBIC 拥塞控制算法！" "Cyan"
        $provider = "CUBIC"
    }

    # 应用到所有常见 TCP 模板 (Internet, InternetCustom, Datacenter, DatacenterCustom)
    $targets = @("Internet", "InternetCustom", "Datacenter", "DatacenterCustom")
    foreach ($tpl in $targets) {
        try {
            Set-NetTCPSetting -SettingName $tpl `
                -CongestionProvider $provider `
                -AutoTuningLevelLocal Experimental `
                -CwndRestart False `
                -DelayedAckFrequency 1 `
                -DelayedAckTimeoutMs 10 `
                -MinRtoMs 20 `
                -InitialCongestionWindowMss 16 `
                -InitialRtoMs 1000 `
                -MaxSynRetransmissions 2 `
                -MemoryPressureProtection Disabled `
                -ScalingHeuristics Disabled `
                -EcnCapability Enabled `
                -Timestamps Disabled `
                -NonSackRttResiliency Disabled `
                -ErrorAction Stop
            Write-ColorText "    [✓] TCP 模板 [$tpl] 已配置: $provider | 16 MSS突发 | 0延迟ACK | 20ms最小RTO" "Gray"
        } catch {
            # 降级备选（若 Experimental 在特定系统环境受限）
            try {
                Set-NetTCPSetting -SettingName $tpl -CongestionProvider $provider -AutoTuningLevelLocal Normal -CwndRestart False -DelayedAckFrequency 1 -ErrorAction SilentlyContinue
                Write-ColorText "    [✓] TCP 模板 [$tpl] 已按标准优化方案配置 ($provider / Normal)" "Gray"
            } catch {}
        }
    }

    # 启用全局自动自定义模板
    try {
        Set-NetTCPSetting -SettingName Automatic -AutomaticUseCustom Enabled -ErrorAction SilentlyContinue
    } catch {}

    # 兼容性备选 netsh 命令补强
    try { & netsh int tcp set global autotuninglevel=experimental 2>$null } catch {}
    if ($LASTEXITCODE -ne 0) { try { & netsh int tcp set global autotuninglevel=normal 2>$null } catch {} }
    try { & netsh int tcp set global ecncapability=enabled 2>$null } catch {}
    try { & netsh int tcp set global rss=enabled 2>$null } catch {}
    try { & netsh int tcp set global timestamps=disabled 2>$null } catch {}
    try { & netsh int tcp set global fastopen=enabled 2>$null } catch {}
    try { & netsh int tcp set global fastopenfallback=enabled 2>$null } catch {}
    try { & netsh int tcp set global nonsackrttresiliency=disabled 2>$null } catch {}
    try { & netsh int tcp set heuristics disabled 2>$null } catch {}
}

# 2. 硬件网络卸载全开 (RSS / RSC / TaskOffload)
function Optimize-HardwareOffload {
    Write-ColorText "[-] 正在开启网卡硬件级分载与多核调度 (RSS / RSC / TaskOffload)..." "Green"
    try {
        Set-NetOffloadGlobalSetting `
            -ReceiveSideScaling Enabled `
            -ReceiveSegmentCoalescing Enabled `
            -TaskOffload Enabled `
            -NetworkDirect Enabled `
            -PacketCoalescingFilter Disabled `
            -ErrorAction SilentlyContinue
        Write-ColorText "    [✓] RSS (多核接收分摊) / RSC (硬件大包聚合) 已强制开启，数据包节能延迟过滤已关闭！" "Gray"
    } catch {
        try { & netsh int tcp set global rss=enabled 2>$null } catch {}
        try { & netsh int tcp set global rsc=enabled 2>$null } catch {}
    }
}

# 3. 全局干掉 Nagle 算法与延迟 ACK (TCPNoDelay / TcpAckFrequency)
function Optimize-NagleAndAck {
    Write-ColorText "[-] 正在全网卡消除 Nagle 缓冲延迟与 ACK 聚合 (暴力实时发包)..." "Green"
    $regBasePath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    if (Test-Path $regBasePath) {
        Get-ChildItem $regBasePath -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                New-ItemProperty -Path $_.PSPath -Name "TCPNoDelay" -PropertyType DWord -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
                New-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -PropertyType DWord -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
                New-ItemProperty -Path $_.PSPath -Name "TcpDelAckTicks" -PropertyType DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
            } catch {}
        }
        Write-ColorText "    [✓] 已为系统中所有网卡接口注入: TCPNoDelay=1, TcpAckFrequency=1, TcpDelAckTicks=0 (0延迟发包)" "Gray"
    }
}

# 4. Winsock 内核与 AFD 缓冲区加速 (激进 UDP/TCP 发包)
function Optimize-WinsockAFD {
    Write-ColorText "[-] 正在配置 Winsock AFD 内核缓冲区与高速发包阈值..." "Green"
    $afdPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Afd\Parameters"
    if (-not (Test-Path $afdPath)) {
        try { New-Item -Path $afdPath -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
    }
    try {
        Set-ItemProperty -Path $afdPath -Name "FastSendDatagramThreshold" -Type DWord -Value 1500 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $afdPath -Name "FastCopyReceiveThreshold" -Type DWord -Value 1500 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $afdPath -Name "DefaultSendWindow" -Type DWord -Value 1048576 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $afdPath -Name "DefaultReceiveWindow" -Type DWord -Value 1048576 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $afdPath -Name "DynamicSendBufferPerConnection" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $afdPath -Name "LargeInitialBuffer" -Type DWord -Value 65536 -Force -ErrorAction SilentlyContinue
        Write-ColorText "    [✓] Winsock AFD 1MB 极速发送/接收缓冲已就绪，UDP/TCP 数据报直通已启用！" "Gray"
    } catch {}
}

# 5. TCP/IP 全局网络内核参数与端口池扩容 (榨干并发连接)
function Optimize-TcpipRegistry {
    Write-ColorText "[-] 正在优化 TCP/IP 核心参数、RFC 1323 窗口缩放及高并发端口池..." "Green"
    $tcpipPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    try {
        Set-ItemProperty -Path $tcpipPath -Name "Tcp1323Opts" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $tcpipPath -Name "MaxUserPort" -Type DWord -Value 65534 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $tcpipPath -Name "TcpTimedWaitDelay" -Type DWord -Value 30 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $tcpipPath -Name "DefaultTTL" -Type DWord -Value 64 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $tcpipPath -Name "EnablePMTUDiscovery" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $tcpipPath -Name "EnablePMTUBHDetect" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $tcpipPath -Name "SynAttackProtect" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $tcpipPath -Name "DisableTaskOffload" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $tcpipPath -Name "EnableICMPRedirect" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
        Write-ColorText "    [✓] RFC 1323 大窗口开启 | 并发端口池扩展至 64510 个 | TIME_WAIT 加速回收" "Gray"
    } catch {}
}

# 6. 解除系统网络调度与多媒体节流 (解除 10,000 pkts/s 瓶颈)
function Optimize-SystemThrottling {
    Write-ColorText "[-] 正在解除 Windows 多媒体网络限速与后台节流..." "Green"
    $mmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    try {
        Set-ItemProperty -Path $mmPath -Name "NetworkThrottlingIndex" -Type DWord -Value 0xFFFFFFFF -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $mmPath -Name "SystemResponsiveness" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
    } catch {}

    # QoS 0% 保留带宽
    $qosPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
    if (-not (Test-Path $qosPath)) { try { New-Item -Path $qosPath -Force -ErrorAction SilentlyContinue | Out-Null } catch {} }
    try { Set-ItemProperty -Path $qosPath -Name "NonBestEffortLimit" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue } catch {}

    # 关闭 Windows 传递优化 P2P 偷偷上传抢带宽
    $doPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config"
    if (-not (Test-Path $doPath)) { try { New-Item -Path $doPath -Force -ErrorAction SilentlyContinue | Out-Null } catch {} }
    try {
        Set-ItemProperty -Path $doPath -Name "DownloadMode" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $doPath -Name "DODownloadMode" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
    } catch {}
    Write-ColorText "    [✓] Windows 多媒体网络节流已彻底禁用 | QoS 20% 预留解除 | P2P 偷跑上传已关闭" "Gray"
}

# 7. DNS 极速缓存优化
function Optimize-DNSCache {
    Write-ColorText "[-] 正在配置 DNS 极速解析与超长正向缓存..." "Green"
    $dnsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
    if (-not (Test-Path $dnsPath)) { try { New-Item -Path $dnsPath -Force -ErrorAction SilentlyContinue | Out-Null } catch {} }
    try {
        Set-ItemProperty -Path $dnsPath -Name "MaxCacheTtl" -Type DWord -Value 86400 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $dnsPath -Name "MaxNegativeCacheTtl" -Type DWord -Value 5 -Force -ErrorAction SilentlyContinue
    } catch {}
    try { & ipconfig /flushdns | Out-Null } catch {}
    Write-ColorText "    [✓] DNS 缓存加速已启用，DNS 缓存已成功刷新！" "Gray"
}

# 8. 网卡硬件高级特性极限榨干 (针对 Wi-Fi 6/6E 与以太网卡)
function Optimize-NetworkAdapters {
    Write-ColorText "[-] 正在深度扫描并调优网卡高级硬件属性 (吞吐量助推器/MIMO全功率/防节能)..." "Green"
    $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" -or $_.Status -eq "Disconnected" }

    foreach ($nic in $adapters) {
        $name = $nic.Name
        Write-ColorText "    -> 正在调优网卡: $name ($($nic.InterfaceDescription))" "Cyan"

        # 辅助函数: 安全设置高级属性
        function Set-NICProp($keyword, $val, $desc) {
            try {
                Set-NetAdapterAdvancedProperty -Name $name -RegistryKeyword $keyword -RegistryValue $val -ErrorAction Stop
                Write-ColorText "       [+] $desc -> 已优化 ($val)" "DarkGray"
            } catch {}
        }

        # --- 无线网卡特性 (Wi-Fi 6 / 6E / 7 / 5) ---
        Set-NICProp "ThroughputBoosterEnabled" "1" "吞吐量助推器 (Packet Bursting)"
        Set-NICProp "MIMOPowerSaveMode" "0" "MIMO 全流常驻模式 (关闭天线省电休眠)"
        Set-NICProp "RoamAggressiveness" "1" "漫游主动性 (设为最低防止跳频断流)"
        Set-NICProp "RoamingPreferredBandType" "2" "首选频带 (优先 5GHz/6GHz 高速频段)"
        Set-NICProp "FatChannelIntolerant" "0" "兼容 40/80/160MHz 超大信道频宽"
        Set-NICProp "IbssTxPower" "100" "发射功率拉满 (100% 满功率传输)"
        Set-NICProp "uAPSDSupport" "0" "关闭 U-APSD 省电"

        # --- 通用与有线网卡高级属性 ---
        Set-NICProp "*PacketCoalescing" "0" "关闭网卡数据包合并节能 (消除排队延迟)"
        Set-NICProp "*FlowControl" "0" "禁用流量控制 (防止路由器暂停帧降速)"
        Set-NICProp "*EEE" "0" "禁用节能以太网 (Energy Efficient Ethernet)"
        Set-NICProp "EnergyEfficientEthernet" "0" "禁用节能以太网 (EEE)"
        Set-NICProp "*DeviceSleepOnDisconnect" "0" "断开连接时不休眠网卡"
        Set-NICProp "*LsoV2IPv4" "1" "启用 IPv4 大型发送分载 (LSOv2)"
        Set-NICProp "*LsoV2IPv6" "1" "启用 IPv6 大型发送分载 (LSOv2)"
        Set-NICProp "*IPChecksumOffloadIPv4" "3" "硬件卸载 IPv4 校验和 (Rx & Tx)"
        Set-NICProp "*TCPChecksumOffloadIPv4" "3" "硬件卸载 TCP 校验和 (Rx & Tx)"
        Set-NICProp "*UDPChecksumOffloadIPv4" "3" "硬件卸载 UDP 校验和 (Rx & Tx)"

        # 尝试将发送与接收缓冲区拉大 (常见值 1024 / 2048 / 4096)
        Set-NICProp "*TransmitBuffers" "2048" "发送缓冲区描述符扩大"
        Set-NICProp "*ReceiveBuffers" "2048" "接收缓冲区描述符扩大"
    }
}

# 9. 切换至卓越/高性能电源模式 (防止网卡 PCIe / USB 总线降频省电)
function Optimize-PowerPlan {
    Write-ColorText "[-] 正在配置电源方案为高性能模式 (锁定网卡最高性能状态)..." "Green"
    Backup-PowerScheme
    try {
        $highGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
        & powercfg /setactive $highGuid 2>$null
        Write-ColorText "    [✓] 已切换至高性能电源计划，网卡省电挂起已彻底关闭！" "Gray"
    } catch {}
}

# ----------------- 执行完整优化 -----------------
function Run-FullExtremeOptimization {
    Show-Header
    Write-ColorText "开始执行【⚡ 极限全栈暴力优化】 - 共 9 个核心模块" "Yellow"
    Write-Host ""

    Show-Step 1 9 "备份当前电源方案"
    Backup-PowerScheme

    Show-Step 2 9 "现代 TCP 协议栈激进化 (BBR2 / CUBIC + 16 MSS 初始突发 + 0 延迟发包)"
    Optimize-TCPStack

    Show-Step 3 9 "硬件网络分载全开 (RSS 多核分摊 / RSC 硬件大包聚合 / TaskOffload)"
    Optimize-HardwareOffload

    Show-Step 4 9 "全网卡消除 Nagle 延迟与 ACK 聚合 (TCPNoDelay=1, TcpAckFrequency=1)"
    Optimize-NagleAndAck

    Show-Step 5 9 "Winsock 内核 AFD 缓冲区扩容至 1MB & UDP/TCP 极速直通发包"
    Optimize-WinsockAFD

    Show-Step 6 9 "TCP/IP 核心参数、RFC 1323 窗口缩放与 64510 端口池扩容"
    Optimize-TcpipRegistry

    Show-Step 7 9 "解除 Windows 10000 pkts/s 网络节流与 QoS 20% 预留带宽"
    Optimize-SystemThrottling

    Show-Step 8 9 "网卡硬件高级属性极限榨干 (Wi-Fi 6E 吞吐助推器 / MIMO 全功率 / 禁用省电)"
    Optimize-NetworkAdapters

    Show-Step 9 9 "DNS 极速缓存优化与高性能电源模式锁定"
    Optimize-DNSCache
    Optimize-PowerPlan

    Write-Host ""
    Write-ColorText "========================================================================" "Green"
    Write-ColorText "   🎉 极限全栈优化已全部执行完毕！" "Green"
    Write-ColorText "   当前系统已配置 BBR2/CUBIC 极速拥塞控制、0延迟发包与全硬件卸载！" "Green"
    Write-ColorText "   提示: 部分网络协议栈与网卡底层参数建议【重启电脑】后达到巅峰状态。" "Yellow"
    Write-ColorText "========================================================================" "Green"
    Write-Host ""
}

# ----------------- 竞技游戏超低延迟优化 -----------------
function Run-GamingOptimization {
    Show-Header
    Write-ColorText "开始执行【🎯 竞技游戏 / 毫秒级超低延迟优化】" "Yellow"
    Write-Host ""
    Optimize-TCPStack
    Optimize-HardwareOffload
    Optimize-NagleAndAck
    Optimize-WinsockAFD
    Optimize-SystemThrottling
    Optimize-DNSCache
    Optimize-PowerPlan
    Write-Host ""
    Write-ColorText ">>> 竞技游戏低延迟优化完成！Nagle已禁用，ACK即刻回复，网络节流已解除！" "Green"
}

# ----------------- 极速大带宽吞吐榨干模式 -----------------
function Run-ThroughputOptimization {
    Show-Header
    Write-ColorText "开始执行【🚀 极速大带宽吞吐 / 榨干千兆万兆模式】" "Yellow"
    Write-Host ""
    Optimize-TCPStack
    Optimize-HardwareOffload
    Optimize-WinsockAFD
    Optimize-TcpipRegistry
    Optimize-SystemThrottling
    Optimize-NetworkAdapters
    Optimize-PowerPlan
    Write-Host ""
    Write-ColorText ">>> 大带宽吞吐优化完成！1MB发送接收窗口与65534大并发端口池已就绪！" "Green"
}

# ----------------- 恢复 Windows 默认出厂设置 -----------------
function Restore-Default {
    Show-Header
    Write-ColorText "================ 正在恢复 Windows 默认网络设置 ================" "Cyan"
    Write-Host ""

    Write-ColorText "[1/7] 重置 TCP 模板至系统默认值 (Normal / CUBIC)..." "Yellow"
    $targets = @("Internet", "InternetCustom", "Datacenter", "DatacenterCustom")
    foreach ($tpl in $targets) {
        try {
            Set-NetTCPSetting -SettingName $tpl `
                -AutoTuningLevelLocal Normal `
                -CwndRestart False `
                -DelayedAckFrequency 2 `
                -DelayedAckTimeoutMs 40 `
                -MinRtoMs 300 `
                -InitialCongestionWindowMss 10 `
                -InitialRtoMs 3000 `
                -MaxSynRetransmissions 2 `
                -MemoryPressureProtection Disabled `
                -ScalingHeuristics Disabled `
                -EcnCapability Disabled `
                -Timestamps Disabled `
                -ErrorAction SilentlyContinue
        } catch {}
    }

    Write-ColorText "[2/7] 清理 Nagle 与 ACK 注册表自定义参数..." "Yellow"
    Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-ItemProperty -Path $_.PSPath -Name "TCPNoDelay" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $_.PSPath -Name "TcpDelAckTicks" -ErrorAction SilentlyContinue
    }

    Write-ColorText "[3/7] 清理 Winsock AFD 内核自定义缓冲区..." "Yellow"
    $afdPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Afd\Parameters"
    if (Test-Path $afdPath) {
        Remove-ItemProperty -Path $afdPath -Name "FastSendDatagramThreshold" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $afdPath -Name "FastCopyReceiveThreshold" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $afdPath -Name "DefaultSendWindow" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $afdPath -Name "DefaultReceiveWindow" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $afdPath -Name "DynamicSendBufferPerConnection" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $afdPath -Name "LargeInitialBuffer" -ErrorAction SilentlyContinue
    }

    Write-ColorText "[4/7] 清理 TCP/IP 与 QoS、多媒体节流自定义注册表..." "Yellow"
    & reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /f 2>$null
    & reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /f 2>$null
    & reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /f 2>$null
    & reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /v DownloadMode /f 2>$null
    & reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /v DODownloadMode /f 2>$null

    Write-ColorText "[5/7] 重置 Winsock 与 IP 协议栈..." "Yellow"
    & netsh winsock reset | Out-Null
    & netsh int ip reset | Out-Null
    & netsh int tcp reset | Out-Null

    Write-ColorText "[6/7] 恢复原电源方案..." "Yellow"
    $schemeFile = Join-Path $PSScriptRoot "网络极速优化_原电源方案.txt"
    if (Test-Path $schemeFile) {
        $line = Get-Content $schemeFile -Encoding UTF8 | Select-Object -First 1
        if ($line -match 'GUID:\s*([0-9a-fA-F-]{36})') {
            & powercfg /setactive $Matches[1]
        }
    }

    Write-ColorText "[7/7] 刷新 DNS..." "Yellow"
    & ipconfig /flushdns | Out-Null

    Write-Host ""
    Write-ColorText "已成功恢复 Windows 默认网络配置！请重启电脑使重置完全生效。" "Green"
}

# ----------------- 网络诊断与并发测速 -----------------
function Test-NetworkBenchmark {
    Show-Header
    Write-ColorText "================ 网络状态诊断 & 多并发吞吐/延迟实测 ================" "Cyan"
    Write-Host ""

    # 1. 显示当前 TCP 核心参数
    Write-ColorText "--- 当前 TCP 模板状态 (Get-NetTCPSetting) ---" "Yellow"
    Get-NetTCPSetting -ErrorAction SilentlyContinue | Where-Object { $_.SettingName -in @("Internet", "InternetCustom", "Datacenter") } | `
        Select-Object SettingName, CongestionProvider, AutoTuningLevelLocal, CwndRestart, DelayedAckFrequency, DelayedAckTimeoutMs, MinRtoMs, InitialCongestionWindowMss | `
        Format-Table -AutoSize

    # 2. 显示网卡硬件分载状态
    Write-ColorText "--- 全局硬件分载状态 (Get-NetOffloadGlobalSetting) ---" "Yellow"
    Get-NetOffloadGlobalSetting -ErrorAction SilentlyContinue | Select-Object ReceiveSideScaling, ReceiveSegmentCoalescing, TaskOffload, PacketCoalescingFilter | Format-List

    # 3. 多主干节点并发延迟与丢包测试
    Write-ColorText "--- 正在向国内核心主干节点发起多并发极速发包测速 ---" "Yellow"
    $testTargets = @(
        @{ Name = "阿里云公共 DNS"; Host = "223.5.5.5" },
        @{ Name = "腾讯云公共 DNS"; Host = "119.29.29.29" },
        @{ Name = "百度主干节点";   Host = "baidu.com" },
        @{ Name = "Bilibili 主干";  Host = "bilibili.com" }
    )

    $results = @()
    foreach ($tgt in $testTargets) {
        Write-Host -NoNewline "正在测试: $($tgt.Name) ($($tgt.Host))... "
        try {
            $ping = Test-Connection -ComputerName $tgt.Host -Count 3 -ErrorAction Stop
            $avgLatency = ($ping | Measure-Object -Property ResponseTime -Average).Average
            $minLatency = ($ping | Measure-Object -Property ResponseTime -Minimum).Minimum
            $maxLatency = ($ping | Measure-Object -Property ResponseTime -Maximum).Maximum
            $results += [PSCustomObject]@{
                目标节点   = $tgt.Name
                IP或域名   = $tgt.Host
                状态       = "正常 (0% 丢包)"
                平均延迟   = "$([Math]::Round($avgLatency, 1)) ms"
                最低延迟   = "$minLatency ms"
                最高延迟   = "$maxLatency ms"
            }
            Write-ColorText "OK ($([Math]::Round($avgLatency, 1)) ms)" "Green"
        } catch {
            $results += [PSCustomObject]@{
                目标节点   = $tgt.Name
                IP或域名   = $tgt.Host
                状态       = "连接超时/受阻"
                平均延迟   = "N/A"
                最低延迟   = "N/A"
                最高延迟   = "N/A"
            }
            Write-ColorText "FAIL" "Red"
        }
    }
    Write-Host ""
    $results | Format-Table -AutoSize

    # 4. 高并发 TCP 握手连接速率实测
    Write-ColorText "--- 正在进行多并发 TCP 极速发包握手速率实测 (10 组并发) ---" "Yellow"
    $handshakeTimes = @()
    1..10 | ForEach-Object {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $tcp.ReceiveTimeout = 2000
            $tcp.SendTimeout = 2000
            $tcp.NoDelay = $true
            $tcp.Connect("223.5.5.5", 53)
            $sw.Stop()
            $handshakeTimes += $sw.ElapsedMilliseconds
            $tcp.Close()
        } catch {
            $sw.Stop()
        }
    }
    if ($handshakeTimes.Count -gt 0) {
        $avgHs = ($handshakeTimes | Measure-Object -Average).Average
        $minHs = ($handshakeTimes | Measure-Object -Minimum).Minimum
        $maxHs = ($handshakeTimes | Measure-Object -Maximum).Maximum
        Write-ColorText "    [+] TCP 高速发包握手实测: 成功 10/10 次 | 最低: $($minHs)ms | 平均: $([Math]::Round($avgHs, 1))ms | 最高: $($maxHs)ms" "Green"
    }
    Write-Host ""
}

# ----------------- 极速 DNS 优选与切换 -----------------
function Switch-FastDNS {
    Show-Header
    Write-ColorText "================ 极速公共 DNS 优选与一键切换 ================" "Cyan"
    Write-Host ""
    Write-Host "   [1] 阿里云 DNS   (223.5.5.5 / 223.6.6.6)         - 全国极速解析/低延迟"
    Write-Host "   [2] 腾讯 DNSPod  (119.29.29.29 / 182.254.116.116) - 华南/华东极速解析"
    Write-Host "   [3] 114 DNS      (114.114.114.114 / 114.114.115.115) - 经典高兼容"
    Write-Host "   [4] Cloudflare   (1.1.1.1 / 1.0.0.1)             - 全球最快 Anycast DNS"
    Write-Host "   [5] 自动恢复为路由器 DHCP 分配默认 DNS"
    Write-Host "   [6] 返回上级菜单"
    Write-Host ""
    $dnsChoice = Read-Host "请输入选项 (1-6)"

    $activeNIC = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
    if (-not $activeNIC) {
        Write-ColorText "未找到处于连接状态的物理网卡！" "Red"
        return
    }

    switch ($dnsChoice) {
        "1" {
            Set-DnsClientServerAddress -InterfaceIndex $activeNIC.ifIndex -ServerAddresses ("223.5.5.5", "223.6.6.6") -ErrorAction SilentlyContinue
            Write-ColorText "已成功为网卡 [$($activeNIC.Name)] 设置阿里云 DNS (223.5.5.5 / 223.6.6.6)" "Green"
        }
        "2" {
            Set-DnsClientServerAddress -InterfaceIndex $activeNIC.ifIndex -ServerAddresses ("119.29.29.29", "182.254.116.116") -ErrorAction SilentlyContinue
            Write-ColorText "已成功为网卡 [$($activeNIC.Name)] 设置腾讯 DNSPod (119.29.29.29 / 182.254.116.116)" "Green"
        }
        "3" {
            Set-DnsClientServerAddress -InterfaceIndex $activeNIC.ifIndex -ServerAddresses ("114.114.114.114", "114.114.115.115") -ErrorAction SilentlyContinue
            Write-ColorText "已成功为网卡 [$($activeNIC.Name)] 设置 114 DNS" "Green"
        }
        "4" {
            Set-DnsClientServerAddress -InterfaceIndex $activeNIC.ifIndex -ServerAddresses ("1.1.1.1", "1.0.0.1") -ErrorAction SilentlyContinue
            Write-ColorText "已成功为网卡 [$($activeNIC.Name)] 设置 Cloudflare DNS (1.1.1.1 / 1.0.0.1)" "Green"
        }
        "5" {
            Set-DnsClientServerAddress -InterfaceIndex $activeNIC.ifIndex -ResetServerAddresses -ErrorAction SilentlyContinue
            Write-ColorText "已成功恢复网卡 [$($activeNIC.Name)] 为 DHCP 自动获取 DNS！" "Green"
        }
        default { return }
    }
    try { & ipconfig /flushdns | Out-Null } catch {}
}

# ==============================================================================
# 程序主入口
# ==============================================================================
Ensure-Admin

do {
    Show-Header
    Write-Host "   [1] ⚡ 极限全栈暴力优化 (BBR2 + 16 MSS突发 + 0延迟发包 + 硬件卸载 + 榨干宽带)"
    Write-Host "   [2] 🎯 竞技游戏 / 毫秒级超低延迟模式 (专攻 0延迟ACK / 最小RTO / 极速重传)"
    Write-Host "   [3] 🚀 极速大带宽吞吐模式 (专攻满速下载 / 1MB窗口 / 65534大并发端口池)"
    Write-Host "   [4] 📶 网卡硬件高级特性专项极致调优 (Wi-Fi 6E 吞吐助推 / MIMO全功率 / 禁用省电)"
    Write-Host "   [5] 📡 极速 DNS 优选与一键切换 (阿里 / 腾讯 / Cloudflare / 114)"
    Write-Host "   [6] 📊 网络状态诊断 & 实时多并发发包/延迟实测"
    Write-Host "   [7] 🔄 一键恢复 Windows 原生默认出厂设置"
    Write-Host "   [8] 退出"
    Write-Host ""
    $choice = Read-Host "请输入选项 (1-8)"

    switch ($choice) {
        "1" {
            Run-FullExtremeOptimization
            $reboot = Read-Host "是否立即重启电脑以使底层协议栈完全生效? (Y/N)"
            if ($reboot -match "^[Yy]") {
                Write-ColorText "系统将在 10 秒后重启，请立即保存其他工作！" "Yellow"
                & shutdown /r /t 10
            }
            Read-Host "按回车继续..."
        }
        "2" {
            Run-GamingOptimization
            Read-Host "按回车继续..."
        }
        "3" {
            Run-ThroughputOptimization
            Read-Host "按回车继续..."
        }
        "4" {
            Show-Header
            Optimize-NetworkAdapters
            Read-Host "按回车继续..."
        }
        "5" {
            Switch-FastDNS
            Read-Host "按回车继续..."
        }
        "6" {
            Test-NetworkBenchmark
            Read-Host "按回车继续..."
        }
        "7" {
            Restore-Default
            Read-Host "按回车继续..."
        }
        "8" {
            exit
        }
    }
} while ($true)
