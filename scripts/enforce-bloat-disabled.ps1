<#
.SYNOPSIS
    Enforces that bloat services remain disabled.

.DESCRIPTION
    This script runs on a schedule to check if Windows has re-enabled
    any of the disabled services (common after Windows Updates) and
    disables them again.

    Logs changes to: %USERPROFILE%\Scripts\bloat_enforcement.log

.NOTES
    Designed to run as a scheduled task with SYSTEM privileges.
#>

$logPath = "$env:USERPROFILE\Scripts\bloat_enforcement.log"
$logDir = Split-Path $logPath -Parent
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Services that must stay disabled
$blockedServices = @(
    "SysMain",           # Superfetch - memory hog
    "DiagTrack",         # Telemetry
    "dmwappushservice",  # WAP Push telemetry
    "WSearch",           # Search indexing
    "WerSvc",            # Error reporting
    "wercplsupport",     # Error reporting UI
    "PcaSvc",            # Compatibility assistant
    "CDPSvc",            # Connected Devices (memory leak)
    "MapsBroker",        # Downloaded Maps
    "lfsvc",             # Geolocation
    "RemoteRegistry",    # Security risk
    "TrkWks",            # Distributed Link Tracking
    "RetailDemo",        # Retail Demo
    "TabletInputService", # Touch keyboard
    "WbioSrvc",          # Biometric
    "Fax"                # Fax
)

$fixed = @()
$alreadyDisabled = 0

foreach ($serviceName in $blockedServices) {
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

    if (-not $service) { continue }

    $startMode = (Get-CimInstance Win32_Service -Filter "Name='$serviceName'" -ErrorAction SilentlyContinue).StartMode

    if ($startMode -ne "Disabled") {
        # Windows re-enabled this service - disable it again
        try {
            if ($service.Status -eq 'Running') {
                Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
            }
            Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop
            $fixed += $serviceName
        }
        catch {
            Add-Content -Path $logPath -Value "[$timestamp] FAILED to disable $serviceName : $($_.Exception.Message)"
        }
    }
    else {
        $alreadyDisabled++
    }
}

# Re-enforce registry settings
$registryFixes = @()

# Game DVR
$gameBarPath = "HKCU:\System\GameConfigStore"
if (Test-Path $gameBarPath) {
    $gameDVR = (Get-ItemProperty -Path $gameBarPath -Name "GameDVR_Enabled" -ErrorAction SilentlyContinue).GameDVR_Enabled
    if ($gameDVR -ne 0) {
        Set-ItemProperty -Path $gameBarPath -Name "GameDVR_Enabled" -Value 0 -ErrorAction SilentlyContinue
        $registryFixes += "GameDVR"
    }
}

# Telemetry
$telemetryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
if (Test-Path $telemetryPath) {
    $telemetry = (Get-ItemProperty -Path $telemetryPath -Name "AllowTelemetry" -ErrorAction SilentlyContinue).AllowTelemetry
    if ($telemetry -ne 0) {
        Set-ItemProperty -Path $telemetryPath -Name "AllowTelemetry" -Value 0 -ErrorAction SilentlyContinue
        $registryFixes += "Telemetry"
    }
}

# Log only if something was fixed
if ($fixed.Count -gt 0 -or $registryFixes.Count -gt 0) {
    $logEntry = "[$timestamp] Fixed services: $($fixed -join ', ')"
    if ($registryFixes.Count -gt 0) {
        $logEntry += " | Registry: $($registryFixes -join ', ')"
    }
    Add-Content -Path $logPath -Value $logEntry
    Write-Host $logEntry
}
else {
    # Only log a heartbeat once per day
    $lastLog = Get-Content -Path $logPath -Tail 1 -ErrorAction SilentlyContinue
    $today = Get-Date -Format "yyyy-MM-dd"
    if (-not $lastLog -or $lastLog -notmatch $today) {
        Add-Content -Path $logPath -Value "[$timestamp] All services verified disabled ($alreadyDisabled services checked)"
    }
}
