# This file is run after on first logon of the administrator account.

$ErrorActionPreference = "Inquire"

# This script is re-run after a reboot, this block handles the post-reboot (and service updated) final steps.
if (Get-ScheduledTask -TaskName "ConfigureScript" -ErrorAction SilentlyContinue) {
  Write-Output "Welcome back!"

  Write-Output "Removing software using winget (which should be available)"
  $software = "Clipchamp", "Cortana", "XBox", "Feedback Hub", "Get Help", "Microsoft Tips", "Office", "OneDrive",
    "Microsoft News", "Microsoft Solitaire Collection", "Microsoft Sticky Notes", "Microsoft People", "Microsoft To Do",
    "Microsoft Photos", "MSN Weather", "Windows Camera", "Windows Voice Recorder", "Microsoft Store", "Xbox TCUI",
    "Xbox Game Bar Plugin", "Xbox Game Bar", "Xbox Identity Provider", "Xbox Game Speech Window", "Your Phone",
    "Windows Media Player", "Movies & TV", "Quick Assist", "Mail and Calendar", "Windows Maps", "Store Experience Host",
    "Windows Calculator", "Power Automate", "Windows Calculator", "Snipping Tool", "Paint", "Windows Web Experience Pack"
  $software | ForEach-Object { & winget.exe uninstall $_ --accept-source-agreements }

  Write-Output "Upgrading the remaining winget packages..."
  & winget upgrade --all | Out-Default

  Write-Output "Enabling WinRM."
  $connectionProfile = Get-NetConnectionProfile
  Set-NetConnectionProfile -Name $connectionProfile.Name -NetworkCategory Private
  winrm quickconfig -quiet
  winrm set winrm/config/service '@{AllowUnencrypted="true"}'
  winrm set winrm/config/service/auth '@{Basic="true"}'

  Write-Output "All done! Unregistering this script and final reboot for good measure"
  Unregister-ScheduledTask -TaskName "ConfigureScript" -Confirm:$false
  Restart-Computer -Force

  exit
}

Start-Transcript -Path "C:\debug.txt" -NoClobber -Append -Force

Write-Output "Disabling Windows Update"
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Value 1 -Type DWord -Force
Set-Service wuauserv -Startup disabled

Write-Output "Installing virtio drivers (starts networking, display driver, etc)"
& msiexec /qn /i "E:\virtio-win-gt-x64.msi" | Out-Default

Write-Output "Disabling OS Recovery"
Get-WmiObject Win32_OSRecoveryConfiguration -EnableAllPrivileges | Set-WmiInstance -Arguments @{ AutoReboot = $False }

Write-Output "Setting performance mode"
& powercfg.exe -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Default

Write-Output "Disabling Error Reporting"
Disable-WindowsErrorReporting

Write-Output "Disabling scheduled tasks and disk cleanup"
Disable-ScheduledTask -TaskName 'ScheduledDefrag' -TaskPath '\Microsoft\Windows\Defrag'
Disable-ScheduledTask -TaskName 'ProactiveScan' -TaskPath '\Microsoft\Windows\Chkdsk'
Disable-ScheduledTask -TaskName 'Scheduled' -TaskPath '\Microsoft\Windows\Diagnosis'
Disable-ScheduledTask -TaskName 'SilentCleanup' -TaskPath '\Microsoft\Windows\DiskCleanup'
Disable-ScheduledTask -TaskName 'WinSAT' -TaskPath '\Microsoft\Windows\Maintenance'
Disable-ScheduledTask -TaskName 'StartComponentCleanup' -TaskPath '\Microsoft\Windows\Servicing'

Write-Output "Disabling disk indexing"
$obj = Get-WmiObject -Class Win32_Volume -Filter "DriveLetter='C:'"
$obj | Set-WmiInstance -Arguments @{ IndexingEnabled = $False } | Out-Default

Write-Output "Disabling NTP time sync"
& w32tm.exe /config /syncfromflags:NO | Out-Default

Write-Output "Enabling Explorer performance settings"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2

Write-Output "Giving Explorer sensible folder view defaults"
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideDrivesWithNoMedia" -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "AutoCheckSelect" -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSuperHidden" -Value 1

Write-Output "Making Explorer not combine taskbar buttons and no tray hiding"
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name TaskbarGlomLevel -Value 2
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name EnableAutoTray -Value 0

Write-Output "Adding Run and Admin Tools to Start button"
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_ShowRun" -Value 1
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "StartMenuAdminTools" -Value 1

Write-Output "Removing Chat/Teams icon from taskbar"
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat" -Name "ChatIcon" -Value 3

Write-Output "Installing WinGet and NuGet"
Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
Install-PackageProvider -Name NuGet -Force

Write-Output "Running Windows Update now"
Install-Module PSWindowsUpdate -Force
Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot

Write-Output "Creating scheduled task to finish up script post-reboot"
$taskAction = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument "-ExecutionPolicy Bypass -File a:\configure.ps1"
$taskTrigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$taskPrincipal = New-ScheduledTaskPrincipal -RunLevel Highest -UserID $env:USERNAME
Register-ScheduledTask -TaskName "ConfigureScript" -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -Force

Write-Output "Done! Rebooting."
Restart-Computer -Force



# TODO: web threat defense service, windows security health service
# todo: microsoft windows malicious software removal tool (thats gets installed by windows update, maybe skip it somehow)
