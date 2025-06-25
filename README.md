# Toggle Rockwell Software

A PowerShell script to enable or disable Rockwell Automation software components' automatic startup behavior on Windows systems.

## Overview

This script provides a centralized way to toggle the automatic startup of Rockwell Automation software components including:
- Startup applications (registry entries)
- Windows services
- Device drivers

This script is especially useful for users who need to quickly enable or disable Rockwell software components that may conflict with ETS6, particularly regarding USB interface usage.

## Features

- **Startup Applications Management**: Toggles Rockwell applications in the Windows startup registry
- **Service Management**: Controls automatic startup of Rockwell-related Windows services
- **Driver Management**: Manages the RSSERIAL driver startup behavior
- **Administrative Privileges**: Automatically elevates to administrator privileges when needed
- **Safe Operation**: Moves disabled startup applications to a separate registry location instead of deleting them
- **Autoruns Compatible**: The script uses the same registry locations as Autoruns, so any changes made by the script are visible in Autoruns after a refresh.

## Requirements

- Windows operating system
- PowerShell 7.5 or later
- Administrative privileges (script will auto-elevate if needed)

## Usage

### Basic Usage

Run the script from PowerShell:

```powershell
.\ToggleRockwell.ps1
```

The script will prompt you to enter "On" or "Off":
- **On**: Enables automatic startup for all Rockwell components
- **Off**: Disables automatic startup for all Rockwell components

### Advanced Usage with Parameters

```powershell
.\ToggleRockwell.ps1 -ScriptOwner "DOMAIN\Username" -ScriptOwnerName "Username" -WorkingDir "C:\Custom\Path"
```

#### Parameters

- `ScriptOwner`: The owner of the script (auto-detected if not provided)
- `ScriptOwnerName`: The name portion of the script owner (auto-detected if not provided)
- `WorkingDir`: Working directory to restore after elevation (current directory if not provided)

## What the Script Does

### Startup Applications (`Toggle_StartupApps`)
- Searches for Rockwell-related entries in `HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run`
- When disabling: Moves entries to `AutorunsDisabled` subfolder
- When enabling: Restores entries from `AutorunsDisabled` subfolder

### Services (`Toggle_Services`)
- Identifies services with "Rockwell" in their name, display name, path, or publisher
- Sets startup type to:
  - **Disabled** when turning off
  - **Manual** for specific services: "Rockwell Event Multiplexer", "Rockwell Directory Multiplexer", "Rockwell Application Services"
  - **Automatic** for all other Rockwell services when turning on

### Drivers (`Toggle_Drivers`)
- Manages the RSSERIAL driver through registry
- Sets registry value at `HKLM:\SYSTEM\CurrentControlSet\Services\RSSERIAL\Start`:
  - **4** (disabled) when turning off
  - **3** (manual) when turning on

## Output

The script provides colored console output:
- **Cyan**: Individual component status changes
- **Yellow**: Section headers and informational messages
- **Green**: Completion message
- **Red/Warning**: Error messages and invalid input

## Safety Features

- **Non-destructive**: Disabled startup applications are moved to a safe location, not deleted
- **Error handling**: Uses `-ErrorAction Ignore` to handle missing services gracefully
- **Input validation**: Validates user input and provides clear error messages
- **Registry safety**: Creates registry paths if they don't exist

## Troubleshooting

### Common Issues

1. **Access Denied**: Ensure the script is running with administrative privileges
2. **No Rockwell Software Found**: Verify Rockwell Automation software is installed
3. **Registry Access Issues**: Check Windows permissions and antivirus software

### Manual Verification

To verify the script's actions:

```powershell
# Check startup applications
Get-ItemProperty -Path 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run' | Select-Object *Rockwell*

# Check services
Get-Service | Where-Object {$_.DisplayName -like "*Rockwell*"}

# Check RSSERIAL driver
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\RSSERIAL" -Name Start
```

## Version Information

- **Script**: ToggleRockwell.ps1
- **Compatible with**: Windows 10/11, Windows Server 2016+
- **PowerShell**: >= 7.5

## Notes

- The script requires a restart to fully apply some changes (especially drivers)
- Some Rockwell services are intentionally set to "Manual" rather than "Automatic" for optimal performance
- The script preserves the original working directory when run with elevation

## Author

This script is designed for system administrators and technicians working with Both ETS and Rockwell Automation software environments.
