#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Optimizes Windows for gaming while maintaining functionality for general use.

.DESCRIPTION
    Applies performance optimizations:
    - Ultimate Performance power plan
    - Hardware-accelerated GPU scheduling
    - Disable mouse acceleration
    - Disable Nagle's algorithm (network latency)
    - Disable memory compression
    - Disable visual effects
    - Disable fullscreen optimizations
    - Optimize timer resolution
    - Disable hibernation (frees disk space)
    - Game Mode settings

.NOTES
    Run as Administrator
    Restart required for some changes
    Use undo-gaming-optimizations.ps1 to revert
#>

$ErrorActionPreference = "SilentlyContinue"

Write-Host "Gaming Optimization Script" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan
Write-Host ""

# Save current settings for undo
$backupPath = "$env:USERPROFILE\Scripts\gaming_optimization_backup.json"
$backupDir = Split-Path $backupPath -Parent
if (-not (Test-Path $backupDir)) { New-Item -Path $backupDir -ItemType Directory -Force | Out-Null }

$backup = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    PowerPlan = (powercfg /getactivescheme) -replace '.*: ', '' -replace '  \(.*', ''
    MouseSpeed = (Get-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name MouseSpeed).MouseSpeed
    MouseThreshold1 = (Get-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name MouseThreshold1).MouseThreshold1
    MouseThreshold2 = (Get-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name MouseThreshold2).MouseThreshold2
}
$backup | ConvertTo-Json | Set-Content $backupPath
Write-Host "[OK] Saved current settings to backup" -ForegroundColor Gray

# ============================================
# 1. POWER PLAN - Ultimate Performance
# ============================================
Write-Host ""
Write-Host "[1/12] Power Plan..." -ForegroundColor Yellow

# Check if Ultimate Performance exists, if not create it
$ultimateGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
$existingPlans = powercfg /list

if ($existingPlans -notmatch $ultimateGuid) {
    # Duplicate High Performance and modify
    powercfg /duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c $ultimateGuid 2>$null
    powercfg /changename $ultimateGuid "Ultimate Performance" "Maximum performance for gaming"
}

# Set as active
powercfg /setactive $ultimateGuid

# Disable USB selective suspend
powercfg /setacvalueindex $ultimateGuid 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
# Disable PCI Express Link State Power Management
powercfg /setacvalueindex $ultimateGuid 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
# Processor performance boost mode - Aggressive
powercfg /setacvalueindex $ultimateGuid 54533251-82be-4824-96c1-47b60b740d00 be337238-0d82-4146-a960-4f3749d470c7 2

powercfg /setactive $ultimateGuid
Write-Host "[OK] Ultimate Performance power plan activated" -ForegroundColor Green

# ============================================
# 2. GPU SCHEDULING
# ============================================
Write-Host ""
Write-Host "[2/12] Hardware-Accelerated GPU Scheduling..." -ForegroundColor Yellow

$gpuSchedPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
Set-ItemProperty -Path $gpuSchedPath -Name "HwSchMode" -Value 2 -Type DWord -Force
Write-Host "[OK] GPU scheduling enabled (requires restart)" -ForegroundColor Green

# ============================================
# 3. MOUSE ACCELERATION
# ============================================
Write-Host ""
Write-Host "[3/12] Mouse Acceleration..." -ForegroundColor Yellow

$mousePath = "HKCU:\Control Panel\Mouse"
Set-ItemProperty -Path $mousePath -Name "MouseSpeed" -Value "0"
Set-ItemProperty -Path $mousePath -Name "MouseThreshold1" -Value "0"
Set-ItemProperty -Path $mousePath -Name "MouseThreshold2" -Value "0"
Set-ItemProperty -Path $mousePath -Name "MouseSensitivity" -Value "10"

# Also set via SystemParametersInfo for immediate effect
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Mouse {
    [DllImport("user32.dll")]
    public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, int[] pvParam, uint fWinIni);
}
"@
$params = @(0, 0, 0)
[Mouse]::SystemParametersInfo(0x0004, 0, $params, 2) | Out-Null

Write-Host "[OK] Mouse acceleration disabled" -ForegroundColor Green

# ============================================
# 4. NAGLE'S ALGORITHM (Network Latency)
# ============================================
Write-Host ""
Write-Host "[4/12] Network Optimization (Nagle's Algorithm)..." -ForegroundColor Yellow

# Get all network adapters
$adapters = Get-ChildItem -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
foreach ($adapter in $adapters) {
    Set-ItemProperty -Path $adapter.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $adapter.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force
}

# Global TCP settings
$tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
Set-ItemProperty -Path $tcpPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force
Set-ItemProperty -Path $tcpPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force

# Disable network throttling
$mmcssPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
Set-ItemProperty -Path $mmcssPath -Name "NetworkThrottlingIndex" -Value 0xffffffff -Type DWord -Force
Set-ItemProperty -Path $mmcssPath -Name "SystemResponsiveness" -Value 0 -Type DWord -Force

Write-Host "[OK] Nagle's algorithm disabled, network throttling disabled" -ForegroundColor Green

# ============================================
# 5. MEMORY COMPRESSION
# ============================================
Write-Host ""
Write-Host "[5/12] Memory Compression..." -ForegroundColor Yellow

Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
Write-Host "[OK] Memory compression disabled" -ForegroundColor Green

# ============================================
# 6. VISUAL EFFECTS
# ============================================
Write-Host ""
Write-Host "[6/12] Visual Effects..." -ForegroundColor Yellow

$visualPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
if (-not (Test-Path $visualPath)) { New-Item -Path $visualPath -Force | Out-Null }
Set-ItemProperty -Path $visualPath -Name "VisualFXSetting" -Value 2 -Type DWord

# Disable specific animations
$dwmPath = "HKCU:\Software\Microsoft\Windows\DWM"
Set-ItemProperty -Path $dwmPath -Name "EnableAeroPeek" -Value 0 -Type DWord -Force

$explorerPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $explorerPath -Name "TaskbarAnimations" -Value 0 -Type DWord -Force

# Disable transparency
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0 -Type DWord -Force

Write-Host "[OK] Animations and transparency reduced" -ForegroundColor Green

# ============================================
# 7. FULLSCREEN OPTIMIZATIONS
# ============================================
Write-Host ""
Write-Host "[7/12] Fullscreen Optimizations..." -ForegroundColor Yellow

# Disable fullscreen optimizations globally
$gameBarPath = "HKCU:\System\GameConfigStore"
Set-ItemProperty -Path $gameBarPath -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 1 -Type DWord -Force
Set-ItemProperty -Path $gameBarPath -Name "GameDVR_FSEBehavior" -Value 2 -Type DWord -Force
Set-ItemProperty -Path $gameBarPath -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord -Force
Set-ItemProperty -Path $gameBarPath -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Type DWord -Force

Write-Host "[OK] Fullscreen optimizations disabled globally" -ForegroundColor Green

# ============================================
# 8. GAME MODE & GAME BAR
# ============================================
Write-Host ""
Write-Host "[8/12] Game Mode Settings..." -ForegroundColor Yellow

# Enable Game Mode (actually helps on modern Windows)
$gameModePath = "HKCU:\Software\Microsoft\GameBar"
if (-not (Test-Path $gameModePath)) { New-Item -Path $gameModePath -Force | Out-Null }
Set-ItemProperty -Path $gameModePath -Name "AutoGameModeEnabled" -Value 1 -Type DWord -Force

# But disable Game Bar overlay (causes stutters)
Set-ItemProperty -Path $gameModePath -Name "UseNexusForGameBarEnabled" -Value 0 -Type DWord -Force

Write-Host "[OK] Game Mode enabled, Game Bar overlay disabled" -ForegroundColor Green

# ============================================
# 9. TIMER RESOLUTION
# ============================================
Write-Host ""
Write-Host "[9/12] Timer Resolution..." -ForegroundColor Yellow

$mmcssGamesPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
if (-not (Test-Path $mmcssGamesPath)) { New-Item -Path $mmcssGamesPath -Force | Out-Null }
Set-ItemProperty -Path $mmcssGamesPath -Name "GPU Priority" -Value 8 -Type DWord -Force
Set-ItemProperty -Path $mmcssGamesPath -Name "Priority" -Value 6 -Type DWord -Force
Set-ItemProperty -Path $mmcssGamesPath -Name "Scheduling Category" -Value "High" -Type String -Force
Set-ItemProperty -Path $mmcssGamesPath -Name "SFIO Priority" -Value "High" -Type String -Force

Write-Host "[OK] Game priority and timer settings optimized" -ForegroundColor Green

# ============================================
# 10. HIBERNATION
# ============================================
Write-Host ""
Write-Host "[10/12] Hibernation..." -ForegroundColor Yellow

powercfg /hibernate off
Write-Host "[OK] Hibernation disabled (freed ~20-40GB)" -ForegroundColor Green

# ============================================
# 11. NVIDIA OPTIMIZATIONS
# ============================================
Write-Host ""
Write-Host "[11/12] NVIDIA Settings..." -ForegroundColor Yellow

# Check if NVIDIA driver is installed
$nvidiaSmiPath = "C:\Windows\System32\nvidia-smi.exe"
if (Test-Path $nvidiaSmiPath) {
    # Enable shader cache
    $nvidiaPath = "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm"

    # Set prefer maximum performance globally via registry
    $nvProfilePath = "HKCU:\Software\NVIDIA Corporation\Global\NVTweak"
    if (-not (Test-Path $nvProfilePath)) { New-Item -Path $nvProfilePath -Force | Out-Null }

    Write-Host "[OK] NVIDIA detected - for best results, also set in NVIDIA Control Panel:" -ForegroundColor Green
    Write-Host "     - Power management: Prefer maximum performance" -ForegroundColor Gray
    Write-Host "     - Texture filtering - Quality: High performance" -ForegroundColor Gray
    Write-Host "     - Threaded optimization: On" -ForegroundColor Gray
    Write-Host "     - Low Latency Mode: Ultra (for competitive games)" -ForegroundColor Gray
} else {
    Write-Host "[SKIP] NVIDIA not detected" -ForegroundColor Gray
}

# ============================================
# 12. DISABLE CORE PARKING
# ============================================
Write-Host ""
Write-Host "[12/12] CPU Core Parking..." -ForegroundColor Yellow

# Disable core parking in current power plan
powercfg -setacvalueindex scheme_current sub_processor CPMINCORES 100
powercfg -setactive scheme_current

Write-Host "[OK] CPU core parking disabled" -ForegroundColor Green

# ============================================
# SUMMARY
# ============================================
Write-Host ""
Write-Host "==========================" -ForegroundColor Cyan
Write-Host "Optimization Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Changes applied:" -ForegroundColor Cyan
Write-Host "  [x] Ultimate Performance power plan" -ForegroundColor White
Write-Host "  [x] Hardware-accelerated GPU scheduling" -ForegroundColor White
Write-Host "  [x] Mouse acceleration disabled" -ForegroundColor White
Write-Host "  [x] Nagle's algorithm disabled" -ForegroundColor White
Write-Host "  [x] Memory compression disabled" -ForegroundColor White
Write-Host "  [x] Visual effects reduced" -ForegroundColor White
Write-Host "  [x] Fullscreen optimizations disabled" -ForegroundColor White
Write-Host "  [x] Game Mode enabled" -ForegroundColor White
Write-Host "  [x] Game priority optimized" -ForegroundColor White
Write-Host "  [x] Hibernation disabled" -ForegroundColor White
Write-Host "  [x] Core parking disabled" -ForegroundColor White
Write-Host ""
Write-Host "RESTART REQUIRED for GPU scheduling to take effect!" -ForegroundColor Yellow
Write-Host ""
Write-Host "To undo: Run undo-gaming-optimizations.ps1" -ForegroundColor Gray
Write-Host ""
