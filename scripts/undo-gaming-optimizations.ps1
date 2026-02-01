#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Reverts gaming optimizations to Windows defaults.

.DESCRIPTION
    Undoes all changes made by gaming-optimizations.ps1

.NOTES
    Run as Administrator
#>

$ErrorActionPreference = "SilentlyContinue"

Write-Host "Undo Gaming Optimizations" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host ""

# ============================================
# 1. POWER PLAN - Back to Balanced
# ============================================
Write-Host "[1/11] Power Plan..." -ForegroundColor Yellow
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
Write-Host "[OK] Restored Balanced power plan" -ForegroundColor Green

# ============================================
# 2. GPU SCHEDULING - Disable
# ============================================
Write-Host "[2/11] GPU Scheduling..." -ForegroundColor Yellow
$gpuSchedPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
Set-ItemProperty -Path $gpuSchedPath -Name "HwSchMode" -Value 1 -Type DWord -Force
Write-Host "[OK] GPU scheduling set to default" -ForegroundColor Green

# ============================================
# 3. MOUSE ACCELERATION - Restore
# ============================================
Write-Host "[3/11] Mouse Acceleration..." -ForegroundColor Yellow
$mousePath = "HKCU:\Control Panel\Mouse"
Set-ItemProperty -Path $mousePath -Name "MouseSpeed" -Value "1"
Set-ItemProperty -Path $mousePath -Name "MouseThreshold1" -Value "6"
Set-ItemProperty -Path $mousePath -Name "MouseThreshold2" -Value "10"
Write-Host "[OK] Mouse acceleration restored to default" -ForegroundColor Green

# ============================================
# 4. NAGLE'S ALGORITHM - Restore
# ============================================
Write-Host "[4/11] Network Settings..." -ForegroundColor Yellow
$adapters = Get-ChildItem -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
foreach ($adapter in $adapters) {
    Remove-ItemProperty -Path $adapter.PSPath -Name "TcpAckFrequency" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $adapter.PSPath -Name "TCPNoDelay" -ErrorAction SilentlyContinue
}

$tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
Remove-ItemProperty -Path $tcpPath -Name "TcpAckFrequency" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $tcpPath -Name "TCPNoDelay" -ErrorAction SilentlyContinue

$mmcssPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
Set-ItemProperty -Path $mmcssPath -Name "NetworkThrottlingIndex" -Value 10 -Type DWord -Force
Set-ItemProperty -Path $mmcssPath -Name "SystemResponsiveness" -Value 20 -Type DWord -Force
Write-Host "[OK] Network settings restored to default" -ForegroundColor Green

# ============================================
# 5. MEMORY COMPRESSION - Enable
# ============================================
Write-Host "[5/11] Memory Compression..." -ForegroundColor Yellow
Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
Write-Host "[OK] Memory compression enabled" -ForegroundColor Green

# ============================================
# 6. VISUAL EFFECTS - Restore
# ============================================
Write-Host "[6/11] Visual Effects..." -ForegroundColor Yellow
$visualPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
Set-ItemProperty -Path $visualPath -Name "VisualFXSetting" -Value 0 -Type DWord -ErrorAction SilentlyContinue

$dwmPath = "HKCU:\Software\Microsoft\Windows\DWM"
Set-ItemProperty -Path $dwmPath -Name "EnableAeroPeek" -Value 1 -Type DWord -Force

$explorerPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $explorerPath -Name "TaskbarAnimations" -Value 1 -Type DWord -Force

Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 1 -Type DWord -Force
Write-Host "[OK] Visual effects restored" -ForegroundColor Green

# ============================================
# 7. FULLSCREEN OPTIMIZATIONS - Default
# ============================================
Write-Host "[7/11] Fullscreen Optimizations..." -ForegroundColor Yellow
$gameBarPath = "HKCU:\System\GameConfigStore"
Set-ItemProperty -Path $gameBarPath -Name "GameDVR_FSEBehavior" -Value 0 -Type DWord -Force
Set-ItemProperty -Path $gameBarPath -Name "GameDVR_FSEBehaviorMode" -Value 0 -Type DWord -Force
Write-Host "[OK] Fullscreen optimizations restored" -ForegroundColor Green

# ============================================
# 8. GAME BAR - Enable
# ============================================
Write-Host "[8/11] Game Bar..." -ForegroundColor Yellow
$gameModePath = "HKCU:\Software\Microsoft\GameBar"
Set-ItemProperty -Path $gameModePath -Name "UseNexusForGameBarEnabled" -Value 1 -Type DWord -Force
Write-Host "[OK] Game Bar restored" -ForegroundColor Green

# ============================================
# 9. HIBERNATION - Enable
# ============================================
Write-Host "[9/11] Hibernation..." -ForegroundColor Yellow
powercfg /hibernate on
Write-Host "[OK] Hibernation enabled" -ForegroundColor Green

# ============================================
# 10. CORE PARKING - Default
# ============================================
Write-Host "[10/11] CPU Core Parking..." -ForegroundColor Yellow
powercfg -setacvalueindex scheme_current sub_processor CPMINCORES 5
powercfg -setactive scheme_current
Write-Host "[OK] Core parking restored to default" -ForegroundColor Green

# ============================================
# 11. DELIVERY OPTIMIZATION - Restore Default
# ============================================
Write-Host "[11/11] Delivery Optimization..." -ForegroundColor Yellow

# Remove policy restrictions (restores Windows defaults)
$doRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
if (Test-Path $doRegPath) {
    Remove-ItemProperty -Path $doRegPath -Name "DODownloadMode" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $doRegPath -Name "DOPercentageMaxBackgroundBandwidth" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $doRegPath -Name "DOPercentageMaxForegroundBandwidth" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $doRegPath -Name "DOMaxCacheSize" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $doRegPath -Name "DOMaxCacheAge" -ErrorAction SilentlyContinue
}
Write-Host "[OK] Delivery Optimization restored to defaults" -ForegroundColor Green

Write-Host ""
Write-Host "=========================" -ForegroundColor Cyan
Write-Host "All settings restored to defaults!" -ForegroundColor Green
Write-Host ""
Write-Host "Restart recommended for all changes to take effect." -ForegroundColor Yellow
Write-Host ""
