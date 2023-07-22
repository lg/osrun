# boot-2: This script is run after Windows Updates are applied.

Write-Output "Installing OpenSSH (while Windows Update is still usable)"
Set-Service wuauserv -StartupType Automatic
Start-Service wuauserv
Add-WindowsCapability -Online -Name OpenSSH.Server
Enable-NetFirewallRule OpenSSH*

Write-Output "One last disable of Windows Update, including removing permissions to download more"
Set-Service wuauserv -StartupType Disabled
Stop-Service wuauserv -Force
Start-Process -FilePath "takeown.exe" -ArgumentList "/f c:\Windows\SoftwareDistribution /r /d y /skipsl" -Wait | Out-Null
Start-Process -FilePath "icacls.exe" -ArgumentList "c:\Windows\SoftwareDistribution /inheritance:r /t /c" -Wait -NoNewWindow | Out-Null
Start-Process -FilePath "icacls.exe" -ArgumentList "c:\Windows\SoftwareDistribution /remove:g SYSTEM /t /c" -Wait -NoNewWindow | Out-Null
Remove-Item -Path "C:\Windows\SoftwareDistribution\*" -Recurse -Force | Out-Null

#####

Write-Output "Final cleanup of disk space"
Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase

Write-Output "Clearing all remaining temp files and caches"
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force
Remove-Item -Path "C:\Users\Administrator\AppData\Local\Temp\*" -Recurse -Force
Remove-Item -Path "C:\Users\Administrator\AppData\Local\Microsoft\Windows\INetCache\*" -Recurse -Force
Remove-Item -Path "C:\Windows\SoftwareDistribution\*" -Recurse -Force -ErrorAction Ignore

###

Write-Output "Snapshot 0s"
& C:\RegistryChangesView.exe /CreateSnapshot c:\reg0

Sleep 30
Write-Output "Snapshot 30s"
& C:\RegistryChangesView.exe /CreateSnapshot c:\reg30

Sleep 120
Write-Output "Snapshot 2m"
& C:\RegistryChangesView.exe /CreateSnapshot c:\reg120

Sleep 300
Write-Output "Snapshot 7m"
& C:\RegistryChangesView.exe /CreateSnapshot c:\reg300

#####

# Read-Host -Prompt "Done! Press Enter to enable OpenSSH and autologin and exit"

Write-Output "Schedule OpenSSH to start on boot"
Set-Service sshd -StartupType Automatic

Write-Output "Successfully provisioned image."
Stop-Computer -Force

#####

Write-Output "Rebooting to let things finish up and then running A:\boot-3.ps1"
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "boot-3" -Value "powershell `"powershell -NoLogo -ExecutionPolicy Bypass -NoExit -File A:\boot-3.ps1 2>&1 | tee \\10.0.2.4\qemu\status.txt`""
Restart-Computer -Force

###############

# Write-Output "Waiting for upgrades to complete and winget to become available"
# While (!(Test-Path C:\Users\Administrator\AppData\Local\Microsoft\WindowsApps\winget.exe -ErrorAction SilentlyContinue)) { Sleep 1 }

# Write-Output "Removing software using winget"
# $software = @("Clipchamp", "Cortana", "XBox", "Feedback Hub", "Get Help", "Microsoft Tips", "Office", "OneDrive",
#   "Microsoft News", "Microsoft Solitaire Collection", "Microsoft Sticky Notes", "Microsoft People", "Microsoft To Do",
#   "Microsoft Photos", "MSN Weather", "Windows Camera", "Windows Voice Recorder", "Microsoft Store", "Xbox TCUI",
#   "Xbox Game Bar Plugin", "Xbox Game Bar", "Xbox Identity Provider", "Xbox Game Speech Window", "Your Phone",
#   "Windows Media Player", "Movies & TV", "Quick Assist", "Mail and Calendar", "Windows Maps", "Store Experience Host",
#   "Windows Calculator", "Power Automate", "Snipping Tool", "Paint", "Windows Web Experience Pack")
# $software | ForEach-Object { & winget.exe uninstall $_ --accept-source-agreements }

# Write-Output "Upgrading the remaining winget packages..."
# & winget upgrade --all | Out-Default





#

######## ONLY CLEANING FROM HERE ##########



# TODO:
# - Log to serial
# - Add Services to right click
