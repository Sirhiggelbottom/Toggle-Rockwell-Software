param (
  [string]$ScriptOwner,
  [string]$ScriptOwnerName,
  [string]$WorkingDir
)

if (-not $ScriptOwner -or -not $ScriptOwnerName) {
  $ScriptOwner = (Get-Acl $MyInvocation.MyCommand.Path).Owner
  $ScriptOwnerName = ($ScriptOwner -split '\\')[-1]
}

if ( -not $WorkingDir ) {
  $WorkingDir = (Get-Location).Path
}

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Start-Process -FilePath pwsh -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "$PSCommandPath",
    "-ScriptOwner", "$ScriptOwner",
    "-ScriptOwnerName", "$ScriptOwnerName",
    "-WorkingDir", "`"$WorkingDir`""
  ) -Verb RunAs
  
  exit
}

if ($WorkingDir) {
  try {
    Set-Location -Path $WorkingDir
  }
  catch {
    Write-Warning "Could not restore original working directory: $WorkingDir"
  }
}

function Toggle_StartupApps {
  param(
    [bool]$State
  )
  $path = 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run'

  $disabledApplicationsPath = 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run\AutorunsDisabled'
  if (-not (Test-Path -Path $disabledApplicationsPath) ){
    New-Item -Path $disabledApplicationsPath -Force
  }

  $amountEnabledApps = (Get-ItemProperty -Path $path | ForEach-Object {$_.PSObject.Properties | Where-Object {$_.Name -like "*Rockwell*" -or $_.Value -like "*Rockwell*"} }).Length
  $amountDisabledApps = (Get-ItemProperty -Path $disabledApplicationsPath | ForEach-Object {$_.PSObject.Properties | Where-Object {$_.Name -like "*Rockwell*" -or $_.Value -like "*Rockwell*"} }).Length
  
  if ($State -eq $false){
    if($amountEnabledApps -gt 0){
      Get-ItemProperty -Path $path | ForEach-Object {
        $props = $_.PSObject.Properties | Where-Object { $_.Name -like "*Rockwell*" -or $_.Value -like "*Rockwell*" }

        $props | ForEach-Object {
          $valueName = $_.Name
          $regPath = $disabledApplicationsPath
          $value = $_.Value
          $type = if( $_.TypeNameOfValue -eq "System.String") {"String"} else { break }

          $null = New-ItemProperty -Path $regPath -Name $valueName -Value $value -PropertyType $type -Force
          Write-Host "Application, $($valueName): Automatic startup turned off" -ForegroundColor Cyan

          Remove-ItemProperty -Path $path -Name $valueName
        }
      }
    } else {
      Write-Host "There aren't any applications to turn off" -ForegroundColor Yellow
    }
    
  } elseif ($State -eq $true ){
    if ($amountDisabledApps -gt 0){
      Get-ItemProperty -Path $disabledApplicationsPath | ForEach-Object {
        $props = $_.PSObject.Properties | Where-Object { $_.Name -like "*Rockwell*" -or $_.Value -like "*Rockwell*" }

        $props | ForEach-Object {
          $valueName = $_.Name
          $regPath = $path
          $value = $_.Value
          $type = if( $_.TypeNameOfValue -eq "System.String") {"String"} else { break }

          $null = New-ItemProperty -Path $regPath -Name $valueName -Value $value -PropertyType $type -Force
          Write-Host "Application, $($valueName): Automatic startup turned on" -ForegroundColor Cyan

          Remove-ItemProperty -Path $disabledApplicationsPath -Name $valueName
        }
      }
    } else {
      Write-Host "There aren't any applications to turn on" -ForegroundColor Yellow
    }
    
  }
  
}


function Toggle_Services {
  param(
    [bool]$state
  )
  $manual_Services = @("Rockwell Event Multiplexer", "Rockwell Directory Multiplexer", "Rockwell Application Services", "RSLinx Classic")

  
  
  $allServices | Where-Object { $_.DisplayName -like "*Rockwell*" -or $_.Name -like "*Rockwell*" -or $_.Path -like "*Rockwell*" -or $_.Publisher -like "*Rockwell*" } | ForEach-Object {

    $displayName = $_.DisplayName
    $name = $_.Name

    if ($state -eq $false){

      Set-Service -Name $name -StartupType Disabled
      Write-Host "Service, $($displayName): Automatic startup turned off" -ForegroundColor Cyan

    } elseif ($state -eq $true){

      if( $manual_Services -contains $displayName ){

        Set-Service -Name $name -StartupType Manual
        Write-Host "Service, $($displayName): Automatic startup turned on" -ForegroundColor Cyan

      } else {

        Set-Service -Name $name -StartupType Automatic
        Write-Host "Service, $($displayName): Automatic startup turned on" -ForegroundColor Cyan

      }

    }
 
  }

}

function Toggle_Drivers {
  param(
    [bool]$state
  )

  $regpath = "HKLM:\SYSTEM\CurrentControlSet\Services\RSSERIAL"

  if(Test-Path -Path $regpath){

    if ($state -eq $false){
      Set-ItemProperty -Path $regpath -Name Start -Value 4
      Write-Host "Driver, RSSERIAL: Automatic startup turned off" -ForegroundColor Cyan
    } elseif ($state -eq $true){
      Set-ItemProperty -Path $regpath -Name Start -Value 3
      Write-Host "Driver, RSSERIAL: Automatic startup turned on" -ForegroundColor Cyan
    }

  }
  
}





$togglePrompt = Read-Host "Toggle Rockwell Software (On/Off)"






if ($togglePrompt.Equals("on", [System.StringComparison]::OrdinalIgnoreCase)){
  $toggleSwitch = $true
} elseif ($togglePrompt.Equals("off", [System.StringComparison]::OrdinalIgnoreCase)) {
  $toggleSwitch = $false
} else {
  Write-Warning "Invalid format!`nPress any key to exit"
  [System.Console]::ReadKey() > $null
  exit
}

$allServices = Get-Service -ErrorAction Ignore | ForEach-Object {
  $displayName = $_.DisplayName
  $name = (Get-Service -ErrorAction Ignore -DisplayName $displayName | Select-Object -Property Name).Name
  $imagePath = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$name" | Select-Object -Property ImagePath).ImagePath
  
  if ($imagePath) {
      $exePath = ($imagePath -split '\.exe')[0] + '.exe'
      $imagePath -match '^(.+\.\w+).*$'
      $path = $Matches[1]
      if (Test-Path $exePath) {
          $fileInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($exePath)
          $publisher = $fileInfo.CompanyName
      } else {
          $publisher = $null
      }
  } else {
      $exePath = $null
      $publisher = $null
  }

  [PSCustomObject]@{
      DisplayName = $displayName
      Name        = $name
      Path        = $path
      Publisher   = $publisher
  }
}

Write-Host "Toggling Startup Apps: $($togglePrompt.ToUpper())`n" -ForegroundColor Yellow
Toggle_StartupApps($toggleSwitch)
Write-Host "`nToggling Startup Services: $($togglePrompt.ToUpper())`n" -ForegroundColor Yellow
Toggle_Services($toggleSwitch)
Write-Host "`nToggling Startup Drivers: $($togglePrompt.ToUpper())`n" -ForegroundColor Yellow
Toggle_Drivers($toggleSwitch)

Write-Host "`nDone.`nPress any key to exit..." -ForegroundColor Green
[System.Console]::ReadKey() > $null