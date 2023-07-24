# boot-2: This script is run after Windows Updates are applied.

# Write-Output "Installing OpenSSH (while Windows Update is still usable)"
# Set-Service wuauserv -StartupType Automatic
# Start-Service wuauserv
# Add-WindowsCapability -Online -Name OpenSSH.Server | Out-Null
# Enable-NetFirewallRule OpenSSH*
# Set-Service sshd -StartupType Automatic

Write-Output "One last disable of Windows Update, including removing permissions to download more"
Set-Service wuauserv -StartupType Disabled
Stop-Service wuauserv -Force
& takeown.exe /f c:\Windows\SoftwareDistribution /r /d y /skipsl | Out-Null
& icacls.exe "c:\Windows\SoftwareDistribution" /inheritance:r /t /c *>&1 | Out-Null
& icacls.exe "c:\Windows\SoftwareDistribution" /remove:g SYSTEM /t /c *>&1 | Out-Null
# Remove-Item -Path "C:\Windows\SoftwareDistribution\*" -Recurse -Force | Out-Null

#####

Write-Output "Clearing all remaining temp files and caches"
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force *>&1 | Out-Null
Remove-Item -Path "C:\Users\Administrator\AppData\Local\Temp\*" -Recurse -Force *>&1 | Out-Null
Remove-Item -Path "C:\Users\Administrator\AppData\Local\Microsoft\Windows\INetCache\*" -Recurse -Force *>&1 | Out-Null
# Remove-Item -Path "C:\ProgramData\Microsoft\Search\Data\Applications\Windows\*" -Recurse -Force -ErrorAction SilentlyContinue

Write-Output "Removing unused windows components"
& Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase | Out-Null

Write-Output "Defragmenting and trimming"
Optimize-Volume -DriveLetter C -Defrag -ReTrim -SlabConsolidate | Out-Null

Write-Output "Compressing drive"
& compact.exe /compactos:always *>&1 | Out-Null

#####

Write-Output "Snapshot 0s"
Start-Process -FilePath "C:\RegistryChangesView.exe" -ArgumentList "/CreateSnapshot c:\reg0" -Wait | Out-Null

#Write-Output "Done"
#Read-Host -Prompt "Done! Press Enter to exit"
Write-Output "Successfully provisioned image."

Stop-Computer -Force

# TODO:
# - something still broken with C:\Windows\SoftwareDistribution
# - dont let the start menu auto popup
# - remove the 'we are adding a new feature to windows'
# - remove pinned items
# - Add Services to right click