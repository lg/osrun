# boot-1: This script is run as Administrator as OOBE.

Write-Output "Running Windows Update"
Set-Service wuauserv -StartupType Manual
Start-Service wuauserv
Install-PackageProvider -Name NuGet -Force
Install-Module PSWindowsUpdate -Force
Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot -Verbose | Out-Null
Set-Service wuauserv -StartupType Disabled
Stop-Service wuauserv -Force

Write-Output "Removing delivery optimization files"
Delete-DeliveryOptimizationCache -Force

Write-Output "Uninstalling OneDrive"
Start-Process -FilePath "taskkill.exe" -ArgumentList "/f /im OneDrive.exe" -Wait -NoNewWindow
Start-Process -FilePath "C:\Windows\system32\OneDriveSetup.exe" -ArgumentList "/uninstall" -Wait -NoNewWindow

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

Write-Output "Rebooting to apply Windows Updates and continue with A:\boot-2.ps1"
New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "boot-2" -Value "powershell `"powershell -NoLogo -ExecutionPolicy Bypass -NoExit -File A:\boot-2.ps1 2>&1 | tee \\10.0.2.4\qemu\status.txt`""
Restart-Computer -Force
