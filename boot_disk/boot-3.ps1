$ErrorActionPreference = "Inquire"
Start-Transcript -Append C:\provision.txt
Write-Output "Starting $PSCommandPath on PowerShell $($PSVersionTable.PSVersion.ToString())"
Add-Content -Path \\10.0.2.4\qemu\status.txt -Value "Clearing final files and starting OpenSSH" -ErrorAction SilentlyContinue

###

Write-Output "Final cleanup of disk space"
Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase

Write-Output "Clearing all remaining temp files and caches"
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force
Remove-Item -Path "C:\Users\Administrator\AppData\Local\Temp\*" -Recurse -Force
Remove-Item -Path "C:\Users\Administrator\AppData\Local\Microsoft\Windows\INetCache\*" -Recurse -Force
# Remove-Item -Path "C:\Windows\SoftwareDistribution\*" -Recurse -Force -ErrorAction Ignore

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

Read-Host -Prompt "Done! Press Enter to enable OpenSSH and autologin and exit"

Write-Output "Schedule OpenSSH to start on boot"
Set-Service sshd -StartupType Automatic
Start-Service sshd

Write-Output "Have a wonderful day!"
Add-Content -Path \\10.0.2.4\qemu\status.txt -Value "Completed!" -ErrorAction SilentlyContinue
Read-Host -Prompt "Press ENTER to exit"


# TODO: 2->3 needs Administrator to be saved
# TODO: dont let the start menu auto popup
# TODO: remove the 'we are adding a new feature to windows'
# TODO: remove pinned items