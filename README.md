# Windows 11 Debloat & Optimization Scripts

A collection of PowerShell scripts to disable unnecessary Windows services, telemetry, and resource-hogging features. Designed for power users with modern hardware (SSD + plenty of RAM).

## Why?

Windows 11 includes many services that:
- **Consume excessive memory** (SysMain/Superfetch can use 50+ GB during cache rebuilding)
- **Cause disk I/O spikes** (Windows Search indexing, telemetry)
- **Send telemetry data** to Microsoft
- **Re-enable themselves** after Windows Updates

These scripts disable the bloat and create a scheduled task to keep it disabled.

## What Gets Disabled

### Services

| Service | Description | Why Disable |
|---------|-------------|-------------|
| SysMain | Superfetch/pre-caching | Unnecessary with SSD, can cause massive memory leaks |
| DiagTrack | Telemetry | Privacy, uses CPU/disk/network |
| WSearch | Windows Search indexing | Causes disk spikes, use Everything instead |
| WerSvc | Windows Error Reporting | Uploads crash data to Microsoft |
| PcaSvc | Program Compatibility Assistant | Annoying popups for "old" apps |
| CDPSvc | Connected Devices Platform | Known memory leak issues |
| MapsBroker | Downloaded Maps Manager | Unnecessary if you have internet |
| lfsvc | Geolocation | Privacy |
| RemoteRegistry | Remote registry access | Security risk |
| TabletInputService | Touch keyboard | Unnecessary on desktop |
| Hyper-V services | VM integration | Unnecessary if not using VMs |

### Registry/Features

- Game DVR background recording
- Telemetry (policy level)
- Cortana
- Windows tips/suggestions/ads

## Installation

### Quick Start

1. **Clone the repo:**
   ```powershell
   git clone https://github.com/YOUR_USERNAME/windows-debloat.git
   cd windows-debloat
   ```

2. **Run the debloat script (as Administrator):**
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   .\scripts\disable-bloat-services.ps1
   ```

3. **Install the enforcement scheduled task:**
   ```powershell
   .\scripts\install-enforcement-task.ps1
   ```

### Manual Installation

1. Download the scripts from this repository
2. Right-click PowerShell → Run as Administrator
3. Navigate to the scripts folder
4. Run: `.\disable-bloat-services.ps1`
5. Run: `.\install-enforcement-task.ps1`

## Scripts

### `disable-bloat-services.ps1`

Main script that:
- Stops and disables bloat services
- Applies registry optimizations
- Disables telemetry at policy level

### `enforce-bloat-disabled.ps1`

Runs on a schedule to:
- Check if Windows re-enabled any services
- Re-disable them automatically
- Log any changes to `bloat_enforcement.log`

### `install-enforcement-task.ps1`

Creates a scheduled task that:
- Runs at system startup (2 min delay)
- Runs every 6 hours
- Runs as SYSTEM with highest privileges
- Executes the enforcement script

### `uninstall.ps1`

Reverses all changes:
- Re-enables disabled services
- Removes scheduled task
- Restores default settings

## Scheduled Task

The enforcement task runs:
- **At startup** (with 2 minute delay)
- **Every 6 hours**

This catches Windows Update re-enabling services and disables them again.

Check the log at: `%USERPROFILE%\Scripts\bloat_enforcement.log`

## Customization

Edit `disable-bloat-services.ps1` to customize which services to disable.

### Services You Might Want to Keep

- **WSearch** - If you use Windows Search frequently (consider [Everything](https://www.voidtools.com/) as alternative)
- **WbioSrvc** - If you use fingerprint/face login
- **TabletInputService** - If you use touch/pen input
- **Spooler** - If you have a printer

## Requirements

- Windows 10/11
- PowerShell 5.1+ (or PowerShell 7)
- Administrator privileges

## Tested On

- Windows 11 25H2
- Intel/AMD systems with NVMe SSD
- 32-64 GB RAM

## Disclaimer

These scripts modify Windows system settings and services. While they've been tested and are safe for most users:

- **Create a system restore point** before running
- **Review the scripts** before executing
- Some features may break if you disable services you actually need
- Changes can be reversed with `uninstall.ps1`

## License

MIT License - Use at your own risk.

## Contributing

Pull requests welcome! Please test changes on a VM first.
