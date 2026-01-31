#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Reverses all changes made by the debloat scripts.

.DESCRIPTION
    This script:
    - Re-enables all disabled services
    - Removes the enforcement scheduled task
    - Restores default registry settings

.NOTES
    Run as Administrator
#>

Write-Host "Windows Debloat Uninstaller" -ForegroundColor Cyan
Write-Host "===========================" -ForegroundColor Cyan
Write-Host ""

# Services to re-enable
$servicesToEnable = @(
    @{Name="SysMain"; StartType="Automatic"},
    @{Name="DiagTrack"; StartType="Automatic"},
    @{Name="dmwappushservice"; StartType="Manual"},
    @{Name="WSearch"; StartType="Automatic"},
    @{Name="WerSvc"; StartType="Manual"},
    @{Name="wercplsupport"; StartType="Manual"},
    @{Name="PcaSvc"; StartType="Automatic"},
    @{Name="CDPSvc"; StartType="Automatic"},
    @{Name="MapsBroker"; StartType="Automatic"},
    @{Name="lfsvc"; StartType="Manual"},
    @{Name="RemoteRegistry"; StartType="Disabled"},  # Keep disabled for security
    @{Name="TrkWks"; StartType="Automatic"},
    @{Name="TabletInputService"; StartType="Manual"},
    @{Name="WbioSrvc"; StartType="Manual"}
)

Write-Host "Re-enabling services..." -ForegroundColor Yellow
$enabled = 0

foreach ($svc in $servicesToEnable) {
    $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
    if ($service) {
        try {
            Set-Service -Name $svc.Name -StartupType $svc.StartType -ErrorAction Stop
            Write-Host "[OK] $($svc.Name) set to $($svc.StartType)" -ForegroundColor Green
            $enabled++
        }
        catch {
            Write-Host "[FAIL] $($svc.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "Removing scheduled task..." -ForegroundColor Yellow

$taskName = "Enforce Bloat Disabled"
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "[OK] Scheduled task removed" -ForegroundColor Green
}
else {
    Write-Host "[SKIP] Scheduled task not found" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Restoring registry settings..." -ForegroundColor Yellow

# Re-enable Game DVR
$gameBarPath = "HKCU:\System\GameConfigStore"
if (Test-Path $gameBarPath) {
    Set-ItemProperty -Path $gameBarPath -Name "GameDVR_Enabled" -Value 1 -ErrorAction SilentlyContinue
    Write-Host "[OK] Game DVR re-enabled" -ForegroundColor Green
}

# Remove telemetry policy (let Windows use default)
$telemetryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
if (Test-Path $telemetryPath) {
    Remove-ItemProperty -Path $telemetryPath -Name "AllowTelemetry" -ErrorAction SilentlyContinue
    Write-Host "[OK] Telemetry policy removed (using Windows default)" -ForegroundColor Green
}

# Remove Cortana policy
$cortanaPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
if (Test-Path $cortanaPath) {
    Remove-ItemProperty -Path $cortanaPath -Name "AllowCortana" -ErrorAction SilentlyContinue
    Write-Host "[OK] Cortana policy removed" -ForegroundColor Green
}

# Remove Game DVR policy
$gameDVRPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
if (Test-Path $gameDVRPolicy) {
    Remove-Item -Path $gameDVRPolicy -Recurse -ErrorAction SilentlyContinue
    Write-Host "[OK] Game DVR policy removed" -ForegroundColor Green
}

Write-Host ""
Write-Host "===========================" -ForegroundColor Cyan
Write-Host "Uninstall complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Re-enabled $enabled services." -ForegroundColor Gray
Write-Host "A restart is recommended for all changes to take effect." -ForegroundColor Yellow
Write-Host ""
