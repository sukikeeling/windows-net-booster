# 网络极速优化 v4.0 (PowerShell 引擎版)
# 配套外壳: 网络极速优化.bat (纯 ASCII, 仅一行调用本脚本)
# 本机系统代码页 65001, 本文件必须保持 UTF-8 WITH BOM, 否则中文会乱

# ============ 可选项(按需修改) ============
$DisableIPv6 = $true   # $true = 关闭 IPv6(不需要 IPv6 时推荐) / $false = 保留 IPv6
# ==========================================

$Host.UI.RawUI.WindowTitle = "网络极速优化 v4.0"
$ErrorActionPreference = "Continue"

function Show-Step {
    param($n, $total, $msg)
    Write-Host ""
    Write-Host "=== [$n/$total] $msg ===" -ForegroundColor Cyan
}

function Step-Pause {
    if ($script:StepMode) {
        Write-Host ""
        Write-Host "======== 本步完成, 按回车进入下一步 ========" -ForegroundColor Yellow
        Read-Host | Out-Null
    }
}

function Restore-Default {
    Clear-Host
    Write-Host ""
    Write-Host "========== 恢复 Windows 默认网络设置 ==========" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[1/6] 重置网络栈..."
    & netsh winsock reset
    & netsh int ip reset
    & netsh int tcp reset
    Write-Host ""
    Write-Host "[2/6] 删除 QoS 预留带宽设置..."
    & reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /f
    Write-Host ""
    Write-Host "[3/6] 删除多媒体网络节流设置..."
    & reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /f
    Write-Host ""
    Write-Host "[4/6] 删除传递优化 P2P 设置..."
    & reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /v DownloadMode /f
    & reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /v DODownloadMode /f
    Write-Host ""
    Write-Host "[5/6] 恢复 IPv6..."
    & reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" /v DisabledComponents /f
    Write-Host ""
    Write-Host "[6/6] 删除 Nagle 设置并恢复原电源方案..."
    Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" | ForEach-Object {
        Remove-ItemProperty -Path $_.PSPath -Name TCPNoDelay -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $_.PSPath -Name TcpAckFrequency -ErrorAction SilentlyContinue
    }
    $schemeFile = Join-Path $PSScriptRoot "网络极速优化_原电源方案.txt"
    if (Test-Path $schemeFile) {
        $line = Get-Content $schemeFile -Encoding UTF8 | Select-Object -First 1
        if ($line -match 'GUID:\s*([0-9a-fA-F-]{36})') {
            & powercfg /setactive $Matches[1]
        }
    }
    Write-Host ""
    Write-Host "已恢复默认设置, 请重启电脑生效。"
}

# ---------- 0. 管理员权限检查 ----------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host ""
    Write-Host "当前不是管理员权限, 优化需要管理员权限才能生效!" -ForegroundColor Red
    Write-Host ""
    $ans = Read-Host "是否尝试自动获取管理员权限? (Y=自动提权 / N=退出后手动右键以管理员身份运行)"
    if ($ans -match "^[Yy]") {
        Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        Write-Host "已在新窗口中启动, 请切换到新窗口操作。"
        Write-Host "如果 5 秒内没有新窗口出现, 请手动右键 网络极速优化.bat -> 以管理员身份运行。"
    } else {
        Write-Host "已退出。请手动右键 网络极速优化.bat -> 以管理员身份运行。"
    }
    Read-Host "按回车退出"
    exit
}

# ---------- 主菜单 ----------
do {
    Clear-Host
    Write-Host ""
    Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host "   网络极速优化 v4.0    (已获得管理员权限)" -ForegroundColor Cyan
    Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   [1] 一步步优化   (每步完成按回车进入下一步)"
    Write-Host "   [2] 一键全自动   (不暂停, 直接跑完 10 步)"
    Write-Host "   [3] 恢复默认设置"
    Write-Host "   [4] 退出"
    Write-Host ""
    $choice = Read-Host "请输入选项 1-4"
} while ($choice -notmatch "^[1-4]$")

switch ($choice) {
    "1" { $script:StepMode = $true }
    "2" { $script:StepMode = $false }
    "3" { Restore-Default; Read-Host "按回车退出"; exit }
    "4" { exit }
}

# ---------- 优化主流程 ----------
Clear-Host
Write-Host ""
Write-Host "  开始优化 - 共 10 步" -ForegroundColor Cyan
if ($script:StepMode) {
    Write-Host "  模式: 一步步 (每步完成按回车进入下一步)"
} else {
    Write-Host "  模式: 全自动"
}
Write-Host ""
Read-Host "按回车开始"

# [1/10] 记录电源方案
Show-Step 1 10 "记录当前电源方案(供以后恢复用)"
& powercfg /getactivescheme | Out-File (Join-Path $PSScriptRoot "网络极速优化_原电源方案.txt") -Encoding UTF8
& powercfg /getactivescheme
Step-Pause

# [2/10] 刷新 DNS
Show-Step 2 10 "刷新 DNS 缓存"
& ipconfig /flushdns
Step-Pause

# [3/10] 重置网络栈
Show-Step 3 10 "重置 Winsock / IP 协议栈(重启后生效)"
& netsh winsock reset
& netsh int ip reset
Step-Pause

# [4/10] TCP 全局优化
Show-Step 4 10 "TCP 全局优化"
& netsh int tcp set global autotuninglevel=normal
& netsh int tcp set global congestionprovider=ctcp
& netsh int tcp set global ecncapability=enabled
& netsh int tcp set global rss=enabled
& netsh int tcp set global timestamps=disabled
& netsh int tcp set global fastopen=enabled
& netsh int tcp set global fastopenfallback=enabled
& netsh int tcp set global nonsackrttresiliency=disabled
Step-Pause

# [5/10] 高性能电源
Show-Step 5 10 "切换高性能电源计划(防止网卡降频省电断流)"
& powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
& powercfg /getactivescheme
Step-Pause

# [6/10] QoS
Show-Step 6 10 "解除 QoS 预留带宽"
& reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /t REG_DWORD /d 0 /f
Step-Pause

# [7/10] 多媒体节流
Show-Step 7 10 "解除 Windows 多媒体网络节流(默认限速 10 包/秒)"
& reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /t REG_DWORD /d 0xFFFFFFFF /f
Step-Pause

# [8/10] Nagle
Show-Step 8 10 "关闭 Nagle 算法(降低小包延迟)"
Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" | ForEach-Object {
    New-ItemProperty -Path $_.PSPath -Name TCPNoDelay -PropertyType DWord -Value 1 -Force | Out-Null
    New-ItemProperty -Path $_.PSPath -Name TcpAckFrequency -PropertyType DWord -Value 1 -Force | Out-Null
}
Write-Host "已为所有网卡接口写入 TCPNoDelay=1 / TcpAckFrequency=1"
Step-Pause

# [9/10] 传递优化
Show-Step 9 10 "关闭 Windows 更新传递优化(P2P 上传)"
& reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /v DownloadMode /t REG_DWORD /d 0 /f
& reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /v DODownloadMode /t REG_DWORD /d 0 /f
Step-Pause

# [10/10] IPv6
Show-Step 10 10 "关闭 IPv6(可选, 顶部 DisableIPv6 可改)"
if ($DisableIPv6) {
    & reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" /v DisabledComponents /t REG_DWORD /d 0xFF /f
} else {
    Write-Host "已跳过 IPv6(保留)"
}
Step-Pause

# ---------- 校验 ----------
Write-Host ""
Write-Host "============ 校验结果 ============" -ForegroundColor Green
Write-Host ""
Write-Host "--- TCP 全局设置 ---"
& netsh int tcp show global
Write-Host ""
Write-Host "--- QoS 预留带宽 ---"
& reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit
Write-Host ""
Write-Host "--- 多媒体网络节流 ---"
& reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex
Write-Host ""
Write-Host "--- 传递优化 P2P ---"
& reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /v DODownloadMode
Write-Host ""
Write-Host "--- IPv6 ---"
& reg query "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" /v DisabledComponents
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "   优化执行完毕!" -ForegroundColor Green
Write-Host "   重要: 重置了网络栈, 必须【重启电脑】才完全生效" -ForegroundColor Yellow
Write-Host "   恢复默认: 重新运行本文件, 主菜单选 3"
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
$reboot = Read-Host "是否立即重启电脑? (Y=重启 / N=稍后手动重启)"
if ($reboot -match "^[Yy]") {
    Write-Host "10 秒后重启, 请立即保存其他工作!"
    & shutdown /r /t 10
} else {
    Write-Host "已取消自动重启, 请稍后手动重启。"
}
Read-Host "按回车退出"
exit
