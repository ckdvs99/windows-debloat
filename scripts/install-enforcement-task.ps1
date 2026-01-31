#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs a scheduled task to enforce bloat services stay disabled.

.DESCRIPTION
    Creates a scheduled task that runs:
    - At system startup (2 minute delay)
    - Every 6 hours

    The task runs as SYSTEM with highest privileges to ensure it can
    disable services even after Windows Updates re-enable them.

.NOTES
    Run as Administrator
#>

$taskName = "Enforce Bloat Disabled"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$enforcementScript = Join-Path $scriptDir "enforce-bloat-disabled.ps1"

# Verify the enforcement script exists
if (-not (Test-Path $enforcementScript)) {
    Write-Host "Error: enforce-bloat-disabled.ps1 not found in $scriptDir" -ForegroundColor Red
    exit 1
}

# Copy script to user's Scripts folder for persistence
$userScriptsDir = "$env:USERPROFILE\Scripts"
if (-not (Test-Path $userScriptsDir)) {
    New-Item -Path $userScriptsDir -ItemType Directory -Force | Out-Null
}
Copy-Item -Path $enforcementScript -Destination "$userScriptsDir\enforce-bloat-disabled.ps1" -Force
$installedScript = "$userScriptsDir\enforce-bloat-disabled.ps1"

Write-Host "Installing scheduled task: $taskName" -ForegroundColor Cyan
Write-Host ""

# Remove existing task if present
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "Removing existing task..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Find PowerShell executable
$pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwshPath) {
    $pwshPath = (Get-Command powershell -ErrorAction SilentlyContinue).Source
}

# Create the action
$action = New-ScheduledTaskAction -Execute $pwshPath -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$installedScript`""

# Create triggers
$triggerStartup = New-ScheduledTaskTrigger -AtStartup
$triggerStartup.Delay = "PT2M"  # 2 minute delay

$triggerDaily = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Hours 6)

$triggers = @($triggerStartup, $triggerDaily)

# Create settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -MultipleInstances IgnoreNew

# Create principal (run as SYSTEM with highest privileges)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Register the task
try {
    $task = Register-ScheduledTask `
        -TaskName $taskName `
        -Action $action `
        -Trigger $triggers `
        -Settings $settings `
        -Principal $principal `
        -Description "Ensures Windows bloat services stay disabled after updates"

    Write-Host "[OK] Task created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Task details:" -ForegroundColor Cyan
    Write-Host "  Name:    $taskName" -ForegroundColor Gray
    Write-Host "  Runs at: System startup + every 6 hours" -ForegroundColor Gray
    Write-Host "  Runs as: SYSTEM (elevated)" -ForegroundColor Gray
    Write-Host "  Script:  $installedScript" -ForegroundColor Gray
    Write-Host "  Log:     $userScriptsDir\bloat_enforcement.log" -ForegroundColor Gray
    Write-Host ""

    # Run it now to verify
    Write-Host "Running task now to verify..." -ForegroundColor Yellow
    Start-ScheduledTask -TaskName $taskName
    Start-Sleep -Seconds 3

    $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
    if ($taskInfo.LastTaskResult -eq 0) {
        Write-Host "[OK] Task ran successfully!" -ForegroundColor Green
    }
    else {
        Write-Host "[WARN] Task completed with code: $($taskInfo.LastTaskResult)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "[FAIL] Could not create task: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
