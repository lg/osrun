# boot-1: This script is run as Administrator as OOBE.
$ErrorActionPreference = "Inquire"
Start-Transcript -Append C:\provision.txt
Write-Output "Starting $PSCommandPath on PowerShell $($PSVersionTable.PSVersion.ToString())"

#####

Write-Output "Installing all virtio drivers and agent"
Start-Process -FilePath "msiexec.exe" -ArgumentList "/qn", "/i", "E:\virtio-win-gt-x64.msi" -Wait
Start-Process -FilePath "e:\virtio-win-guest-tools.exe" -ArgumentList "/install", "/quiet", "/norestart" -Wait

Write-Output "Disabling System Restore"
Disable-ComputerRestore -Drive "C:"

Write-Output "Removing Recovery Environment"
Start-Process -FilePath "reagentc.exe" -ArgumentList "/disable" -Wait

Write-Output "Disabling OS Recovery"
Get-WmiObject Win32_OSRecoveryConfiguration -EnableAllPrivileges | Set-WmiInstance -Arguments @{ AutoReboot = $False }

Write-Output "Disabling Error Reporting"
Disable-WindowsErrorReporting

Write-Output "Disabling and deleting page file"
$computersys = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
$computersys.AutomaticManagedPagefile = $False
$computersys.Put()
$pagefile = Get-WmiObject win32_pagefilesetting
$pagefile.delete()

Write-Output "Disabling disk indexing"
$obj = Get-WmiObject -Class Win32_Volume -Filter "DriveLetter='C:'"
$obj | Set-WmiInstance -Arguments @{ IndexingEnabled = $False } | Out-Null
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0

Write-Output "Disabling Windows Search"
Set-Service WSearch -StartupType Disabled
Stop-Service -Name WSearch
Remove-Item -Path "C:\ProgramData\Microsoft\Search\Data\Applications\Windows\*" -Recurse -Force

Write-Output "Setting performance mode"
Start-Process -FilePath "powercfg.exe" -ArgumentList "-setactive", "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" -Wait

Write-Output "Disabling sleep and hibernation"
Start-Process -FilePath "powercfg.exe" -ArgumentList "-change", "-monitor-timeout-ac", "0" -Wait
Start-Process -FilePath "powercfg.exe" -ArgumentList "-change", "-standby-timeout-ac", "0" -Wait
Start-Process -FilePath "powercfg.exe" -ArgumentList "-change", "-disk-timeout-ac", "0" -Wait
Start-Process -FilePath "powercfg.exe" -ArgumentList "-change", "-hibernate-timeout-ac", "0" -Wait
Start-Process -FilePath "powercfg.exe" -ArgumentList "/h", "off" -Wait
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateFileSizePercent" -Value 0
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabled" -Value 0

#####

Write-Output "Running Windows Update"
Set-Service wuauserv -StartupType Manual
Start-Service wuauserv
Install-PackageProvider -Name NuGet -Force
Install-Module PSWindowsUpdate -Force
Add-WUServiceManager -MicrosoftUpdate -Confirm:$false
Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -Install -IgnoreReboot
Set-Service wuauserv -StartupType Disabled
Stop-Service wuauserv -Force

#####

Write-Output "Making sure long paths are enabled so we can access all files"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1

Write-Output "Disabling NTP time sync"
Start-Process -FilePath "w32tm.exe" -ArgumentList "/config", "/syncfromflags:NO" -Wait

Write-Output "Enabling Explorer performance settings"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2

Write-Output "Giving Explorer sensible folder view defaults"
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideDrivesWithNoMedia" -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "AutoCheckSelect" -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSuperHidden" -Value 1

Write-Output "Making Explorer not combine taskbar buttons"
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarGlomLevel" -Value 2

Write-Output "Adding Run and Admin Tools to Start button"
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_ShowRun" -Value 1
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "StartMenuAdminTools" -Value 1

Write-Output "Removing Chat/Teams icon from taskbar"
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat" -Name "ChatIcon" -Value 3

Write-Output "Removing remaining ads"
New-Item -Path "HKCU:\HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Force | Out-Null
New-ItemProperty -Path "HKCU:\HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name DisableWindowsConsumerFeatures -Value 1 -PropertyType DWORD -Force | Out-Null

Write-Output "Disabling Widgets"
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Value 0

Write-Output "Hiding Windows Security notifications"
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" -Name "DisableNotifications" -Value 1

Write-Output "Hiding Suggested Content from Start Menu"
$registryKeys = @("DisableSoftLanding", "SubscribedContent-338393Enabled", "SubscribedContent-338389Enabled",
  "SubscribedContent-353694Enabled", "SubscribedContent-353696Enabled", "DisableWindowsConsumerFeatures")
New-Item -Path "HKLM:\HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Force | Out-Null
foreach ($key in $registryKeys) {
  New-ItemProperty -Path "HKLM:\HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name $key -Value 1 -PropertyType DWORD -Force | Out-Null
}
$registryKeys = @("ContentDeliveryAllowed", "FeatureManagementEnabled", "OemPreInstalledAppsEnabled",
  "PreInstalledAppsEnabled", "SilentInstalledAppsEnabled", "SoftLandingEnabled", "SystemPaneSuggestionsEnabled")
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Force | Out-Null
foreach ($key in $registryKeys) {
  Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name $key -Value 0
}

Write-Output "Downloading and extracting SpaceMonger"
Invoke-WebRequest -Uri "https://archive.org/download/spcmn140_zip/spcmn140.zip" -OutFile "C:\sm.zip"
Expand-Archive -Path "C:\sm.zip" -DestinationPath "C:\" -Force
Remove-Item "C:\sm.zip"

Write-Output "Downloading and extracting RegistryChangesView..."
Invoke-WebRequest -Uri "https://www.nirsoft.net/utils/registrychangesview-x64.zip" -OutFile "C:\rcv.zip"
Expand-Archive -Path "C:\rcv.zip" -DestinationPath "C:\" -Force
Remove-Item "C:\rcv.zip"

#####

Write-Output "Rebooting to apply Windows Updates and continue with A:\boot-2.ps1"
New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "boot-2" -Value "powershell -ExecutionPolicy Bypass -File A:\boot-2.ps1"
Restart-Computer -Force
