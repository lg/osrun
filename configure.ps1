$ErrorActionPreference = "Stop"

Start-Transcript -Path "C:\debug.txt" -NoClobber -Append -Force

Write-Output "Disabling Windows Update"
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Value 1 -Type DWord -Force
Set-Service wuauserv -Startup disabled

Write-Output "Installing virtio drivers (starts networking, display driver, etc)"
& msiexec /qn /i "E:\virtio-win-gt-x64.msi" | Out-Default

Write-Output "Disabling OS Recovery"
Get-WmiObject Win32_OSRecoveryConfiguration -EnableAllPrivileges | Set-WmiInstance -Arguments @{ AutoReboot=$False }

Write-Output "Disabling sleep and hibernation"
& powercfg -change -monitor-timeout-ac 0 | Out-Default
& powercfg -change -standby-timeout-ac 0 | Out-Default
& powercfg -change -disk-timeout-ac 0 | Out-Default
& powercfg -change -hibernate-timeout-ac 0 | Out-Default
& powercfg.exe /h off | Out-Default
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateFileSizePercent" -Value 0
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabled" -Value 0

Write-Output "Setting performance mode"
& powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Default

Write-Output "Disabling System Restore"
Disable-ComputerRestore -Drive "C:"

Write-Output "Disabling Error Reporting"
Disable-WindowsErrorReporting

Write-Output "Disabling scheduled tasks and disk cleanup"
Disable-ScheduledTask -TaskName 'ScheduledDefrag' -TaskPath '\Microsoft\Windows\Defrag'
Disable-ScheduledTask -TaskName 'ProactiveScan' -TaskPath '\Microsoft\Windows\Chkdsk'
Disable-ScheduledTask -TaskName 'Scheduled' -TaskPath '\Microsoft\Windows\Diagnosis'
Disable-ScheduledTask -TaskName 'SilentCleanup' -TaskPath '\Microsoft\Windows\DiskCleanup'
Disable-ScheduledTask -TaskName 'WinSAT' -TaskPath '\Microsoft\Windows\Maintenance'
Disable-ScheduledTask -TaskName 'StartComponentCleanup' -TaskPath '\Microsoft\Windows\Servicing'

Write-Output "Disabling NTP time sync"
& w32tm.exe /config /syncfromflags:NO | Out-Default

Write-Output "Enabling Explorer performance settings"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2

Write-Output "Giving Explorer sensible defaults"
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-ItemProperty $key HideFileExt 0
Set-ItemProperty $key HideDrivesWithNoMedia 0
Set-ItemProperty $key Hidden 1
Set-ItemProperty $key AutoCheckSelect 0

Write-Output "Making Explorer not combine taskbar buttons and no tray hiding"
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name TaskbarGlomLevel -Value 2
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name EnableAutoTray -Value 0

Write-Output "Adding Run and Admin Tools to Start button"
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_ShowRun" -Value 1
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "StartMenuAdminTools" -Value 1

read-host “Press ENTER to continue to disable windows defender. Reboot will not enable winrm for now.”

# TODO: Needs anti-tamper first
Write-Output "Disabling Windows Defender"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -Value 1 -Type DWord -Force
# Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows Defender\Features" -Name "TamperProtection" -Value 0 -Type DWord -Force
# Set-MpPreference -DisableRealtimeMonitoring $true

Write-Output "Running Windows Update now"
Install-PackageProvider -Name NuGet -Force
Install-Module PSWindowsUpdate -Force
Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot

Write-Output "Disabling swap file"
$computersys = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
$computersys.AutomaticManagedPagefile = $False
$computersys.Put()

Write-Output "Deleting swap file"
$pagefile = Get-WmiObject win32_pagefilesetting
$pagefile.delete()

Write-Output "Configuring winrm, NOTE: will only start on reboot"
$profile = Get-NetConnectionProfile
Set-NetConnectionProfile -Name $profile.Name -NetworkCategory Private
winrm quickconfig -quiet
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
# winrm set winrm/config/service/auth '@{Basic="true"}'
Stop-Service winrm

Write-Output "Done! Rebooting"

Restart-Computer -Force

# TODO: Disable one drive
# TODO: Disable windows searchindexing
# TODO: web threat defense service, windows security health service
# TODO: disable widgets
# todo: microsoft windows malicious software removal tool (thats gets installed by windows update, maybe skip it somehow)

# TODO: Disable Windows Defender
# TODO: Disable Windows Update automatic updates
# TODO: Disable Paging
# TODO: Disable Hibernation and remove the file