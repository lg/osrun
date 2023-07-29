# boot-2: This script is run on first reboot after first login of Administrator, do final cleanup here before snapshot boot.
$ErrorActionPreference = "Inquire"

Write-Output "One last disable of Windows Update, including removing permissions to download more"
Set-Service wuauserv -StartupType Disabled
Stop-Service wuauserv -Force
& takeown.exe /f c:\Windows\SoftwareDistribution /r /d y /skipsl | Out-Null
& icacls.exe "c:\Windows\SoftwareDistribution" /inheritance:r /t /c *>&1 | Out-Null
& icacls.exe "c:\Windows\SoftwareDistribution" /remove:g SYSTEM /t /c *>&1 | Out-Null

#####

Write-Output "Clearing all remaining temp files and caches"
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force *>&1 | Out-Null
Remove-Item -Path "C:\Users\Administrator\AppData\Local\Temp\*" -Recurse -Force *>&1 | Out-Null
Remove-Item -Path "C:\Users\Administrator\AppData\Local\Microsoft\Windows\INetCache\*" -Recurse -Force *>&1 | Out-Null

Write-Output "Removing unused windows components"
& Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase | Out-Null

Write-Output "Defragmenting and trimming"
Optimize-Volume -DriveLetter C -Defrag -ReTrim -SlabConsolidate | Out-Null

Write-Output "Compressing drive"
& compact.exe /compactos:always *>&1 | Out-Null

#####

Write-Output "Snapshotting registry now and in 60s"
Start-Process -FilePath "C:\RegistryChangesView.exe" -ArgumentList "/CreateSnapshot c:\reg0" -Wait | Out-Null
Write-Output "Successfully provisioned image."

Stop-Computer -Force

# TODO:
# - something still broken with C:\Windows\SoftwareDistribution
# - dont let the start menu auto popup
# - remove the 'we are adding a new feature to windows'
# - remove pinned items
# - Add Services to right click