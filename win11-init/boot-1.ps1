# boot-1: This script is run as Administrator during OOBE. Most configuration and installation should have been done in
# the previous step, this should just be the final cleanup and optimization.
$ErrorActionPreference = "Inquire"

#####

Write-Output "Installing QEMU agent (virtio already installed)"
& "C:\virtio-win-guest-tools.exe" /install /quiet | Out-Null
Remove-Item -Path "C:\virtio-win-guest-tools.exe" -Force | Out-Null

Write-Output "Disabling all scheduled tasks with a scheduled time or idle trigger"
Get-ScheduledTask | Where-Object State -NE "Disabled" |
  Where-Object { $_.Triggers | Where-Object { $_.CimClass -Like "*idle*" } } |
  Disable-ScheduledTask -ErrorAction SilentlyContinue |
  Out-Null
Get-ScheduledTask | Where-Object State -NE "Disabled" |
  Get-ScheduledTaskInfo | Where-Object { $_.NextRunTime -ne $null } |
  ForEach-Object { Disable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue } |
  Out-Null

Write-Output "Waiting for active installation processes to end"
$BadProcesses = @("msiexec", "TiWorker", "backgroundTaskHost", "TrustedInstaller")
While ($StillRunning = ($BadProcesses | ForEach-Object { Get-Process -Name $_ -ErrorAction SilentlyContinue |
    Where-Object { $_.Threads.Count -ne $_.Threads.Where({ $_.WaitReason -eq "Suspended" }).Count }} ).Name) {
  Write-Output "Still running: $($StillRunning -join ', ')"
  Sleep 30
}

#####

Write-Output "Removing delivery optimization files"
Delete-DeliveryOptimizationCache -Force 2>&1 | Out-Null

Write-Output "Clearing all remaining temp files and caches"
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue *>&1 | Out-Null
Remove-Item -Path "C:\Users\Administrator\AppData\Local\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue *>&1 | Out-Null
Remove-Item -Path "C:\Users\Administrator\AppData\Local\Microsoft\Windows\INetCache\*" -Recurse -Force -ErrorAction SilentlyContinue *>&1 | Out-Null

Write-Output "Removing unused windows components"
& Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase | Out-Null

Write-Output "Compressing drive"
& compact.exe /compactos:always *>&1 | Out-Null

Write-Output "Defragmenting and trimming"
Optimize-Volume -DriveLetter C -Defrag
Optimize-Volume -DriveLetter C -ReTrim

Write-Output "Final wait for installation processes to end"
While ($StillRunning = ($BadProcesses | ForEach-Object { Get-Process -Name $_ -ErrorAction SilentlyContinue |
    Where-Object { $_.Threads.Count -ne $_.Threads.Where({ $_.WaitReason -eq "Suspended" }).Count }} ).Name) {
  Write-Output "Still running: $($StillRunning -join ', ')"
  Sleep 30
}

Write-Output "Successfully provisioned image."

#####

Stop-Computer -Force
