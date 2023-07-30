# boot-1: This script is run as Administrator during OOBE. Put everything that can only be run after the user is created.
$ErrorActionPreference = "Inquire"

Write-Output "Waiting for OneDrive to be running"
while (!(Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue)) { Start-Sleep -Seconds 1 }
Write-Output "Killing and uninstalling OneDrive"
Start-Process -FilePath "taskkill.exe" -ArgumentList "/f /im OneDrive.exe" -Wait -NoNewWindow | Out-Null
Start-Process -FilePath "C:\Windows\system32\OneDriveSetup.exe" -ArgumentList "/uninstall" -Wait -NoNewWindow

Write-Output "Installing all virtio drivers and agent and then rebooting with Administrator user"
& msiexec.exe /qn /i "D:\virtio\virtio-win-gt-x64.msi" /norestart | Out-Null
& "D:\virtio\virtio-win-guest-tools.exe" /install /quiet /norestart | Out-Null

# Write-Output "Running Windows Update"
# Set-Service wuauserv -StartupType Manual
# Start-Service wuauserv
# Install-PackageProvider -Name NuGet -Force | Out-Null
# Install-Module PSWindowsUpdate -Force | Out-Null
# Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot -Verbose | Out-Null
# Set-Service wuauserv -StartupType Disabled
# Stop-Service wuauserv -Force

Write-Output "Removing delivery optimization files"
Delete-DeliveryOptimizationCache -Force | Out-Null

Write-Output "Disabling Content Delivery Manager"
New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SilentInstalledAppsEnabled" -Value 0

Write-Output "Enabling Explorer performance settings"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2

Write-Output "Removing remaining ads"
New-Item -Path "HKCU:\HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Force | Out-Null
New-ItemProperty -Path "HKCU:\HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name DisableWindowsConsumerFeatures -Value 1 -PropertyType DWORD -Force | Out-Null

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

#####

Write-Output "Rebooting to D:\boot-2.ps1"
New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "boot-2" -Value "cmd /c `"powershell -NoLogo -ExecutionPolicy Bypass -NoExit -File D:\boot-2.ps1 *>&1 >> \\10.0.2.4\qemu\status.txt`""
Restart-Computer -Force
