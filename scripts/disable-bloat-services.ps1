#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Disables unnecessary Windows services and features that consume resources.

.DESCRIPTION
    This script stops and disables Windows services known to cause:
    - Excessive memory usage (SysMain/Superfetch)
    - Disk I/O spikes (Windows Search, telemetry)
    - Privacy concerns (telemetry, error reporting)

    Designed for power users with SSD + plenty of RAM where these services
    provide minimal benefit.

.NOTES
    Run as Administrator
    Create a system restore point before running
#>

Write-Host "Windows Debloat Script" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan
Write-Host ""

# Services to disable - grouped by category
$servicesToDisable = @(
    # Memory/Performance hogs
    @{Name="SysMain"; Desc="Superfetch - pre-caching (unnecessary with SSD)"},
    @{Name="DiagTrack"; Desc="Telemetry - sends data to Microsoft"},
    @{Name="dmwappushservice"; Desc="WAP Push Message Routing - telemetry related"},

    # Indexing (causes disk/CPU spikes)
    @{Name="WSearch"; Desc="Windows Search indexing - uses disk/CPU"},

    # Error reporting
    @{Name="WerSvc"; Desc="Windows Error Reporting - uploads crash data"},
    @{Name="wercplsupport"; Desc="Problem Reports Control Panel"},

    # Compatibility bloat
    @{Name="PcaSvc"; Desc="Program Compatibility Assistant - nags about old apps"},

    # Unused features
    @{Name="MapsBroker"; Desc="Downloaded Maps Manager"},
    @{Name="lfsvc"; Desc="Geolocation Service"},
    @{Name="RemoteRegistry"; Desc="Remote Registry - security risk"},
    @{Name="Fax"; Desc="Fax service"},
    @{Name="TrkWks"; Desc="Distributed Link Tracking Client"},
    @{Name="RetailDemo"; Desc="Retail Demo Service"},

    # Touch/Tablet (disable if desktop - comment out if you use touch)
    @{Name="TabletInputService"; Desc="Touch Keyboard and Handwriting"},
    @{Name="WbioSrvc"; Desc="Windows Biometric (fingerprint/face login)"},

    # Connected Devices (known memory leaks)
    @{Name="CDPSvc"; Desc="Connected Devices Platform Service"},

    # Hyper-V (disable if not using VMs - comment out if you use Hyper-V)
    @{Name="vmickvpexchange"; Desc="Hyper-V Data Exchange"},
    @{Name="vmicguestinterface"; Desc="Hyper-V Guest Interface"},
    @{Name="vmicshutdown"; Desc="Hyper-V Shutdown"},
    @{Name="vmicheartbeat"; Desc="Hyper-V Heartbeat"},
    @{Name="vmicvmsession"; Desc="Hyper-V VM Session"},
    @{Name="vmicrdv"; Desc="Hyper-V Remote Desktop"},
    @{Name="vmictimesync"; Desc="Hyper-V Time Sync"},
    @{Name="vmicvss"; Desc="Hyper-V VSS"}
)

# Uncomment to also disable Print Spooler (if you don't have a printer)
# $servicesToDisable += @{Name="Spooler"; Desc="Print Spooler"}

$disabled = 0
$skipped = 0
$notFound = 0

foreach ($svc in $servicesToDisable) {
    $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue

    if (-not $service) {
        $notFound++
        continue
    }

    $currentStartup = (Get-CimInstance Win32_Service -Filter "Name='$($svc.Name)'" -ErrorAction SilentlyContinue).StartMode

    if ($currentStartup -eq "Disabled") {
        Write-Host "[SKIP] $($svc.Name) - Already disabled" -ForegroundColor Gray
        $skipped++
        continue
    }

    try {
        # Stop if running
        if ($service.Status -eq 'Running') {
            Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
        }

        # Disable
        Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction Stop
        Write-Host "[OK]   $($svc.Name) - $($svc.Desc)" -ForegroundColor Green
        $disabled++
    }
    catch {
        Write-Host "[FAIL] $($svc.Name) - Could not disable: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "==============================" -ForegroundColor Cyan
Write-Host "Disabled: $disabled services" -ForegroundColor Green
Write-Host "Skipped:  $skipped (already disabled)" -ForegroundColor Gray
Write-Host "Not found: $notFound (not installed)" -ForegroundColor Gray
Write-Host ""

# Additional optimizations
Write-Host "Applying additional optimizations..." -ForegroundColor Yellow

# Disable Game DVR / Game Bar background recording
$gameBarPath = "HKCU:\System\GameConfigStore"
if (Test-Path $gameBarPath) {
    Set-ItemProperty -Path $gameBarPath -Name "GameDVR_Enabled" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $gameBarPath -Name "GameDVR_FSEBehaviorMode" -Value 2 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $gameBarPath -Name "GameDVR_FSEBehavior" -Value 2 -ErrorAction SilentlyContinue
}

$gameDVRPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
if (-not (Test-Path $gameDVRPolicy)) { New-Item -Path $gameDVRPolicy -Force | Out-Null }
Set-ItemProperty -Path $gameDVRPolicy -Name "AllowGameDVR" -Value 0 -ErrorAction SilentlyContinue
Write-Host "[OK]   Game DVR/Bar background recording disabled" -ForegroundColor Green

# Disable telemetry
$telemetryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
if (-not (Test-Path $telemetryPath)) { New-Item -Path $telemetryPath -Force | Out-Null }
Set-ItemProperty -Path $telemetryPath -Name "AllowTelemetry" -Value 0 -ErrorAction SilentlyContinue
Write-Host "[OK]   Telemetry level set to minimal" -ForegroundColor Green

# Disable Cortana
$cortanaPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
if (-not (Test-Path $cortanaPath)) { New-Item -Path $cortanaPath -Force | Out-Null }
Set-ItemProperty -Path $cortanaPath -Name "AllowCortana" -Value 0 -ErrorAction SilentlyContinue
Write-Host "[OK]   Cortana disabled" -ForegroundColor Green

# Disable tips and suggestions
$cdmPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
if (Test-Path $cdmPath) {
    Set-ItemProperty -Path $cdmPath -Name "SoftLandingEnabled" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $cdmPath -Name "SubscribedContent-338388Enabled" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $cdmPath -Name "SubscribedContent-338389Enabled" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $cdmPath -Name "SubscribedContent-310093Enabled" -Value 0 -ErrorAction SilentlyContinue
}
Write-Host "[OK]   Windows tips and suggestions disabled" -ForegroundColor Green

Write-Host ""
Write-Host "==============================" -ForegroundColor Cyan
Write-Host "Optimization complete!" -ForegroundColor Green
Write-Host ""
Write-Host "NOTE: Some changes require a restart to take full effect." -ForegroundColor Yellow
Write-Host ""
Write-Host "Services you may want to RE-ENABLE if needed:" -ForegroundColor Cyan
Write-Host "  Set-Service -Name 'WSearch' -StartupType Automatic  # Windows Search" -ForegroundColor Gray
Write-Host "  Set-Service -Name 'WbioSrvc' -StartupType Automatic # Biometric login" -ForegroundColor Gray
Write-Host "  Set-Service -Name 'TabletInputService' -StartupType Automatic # Touch input" -ForegroundColor Gray
Write-Host ""
