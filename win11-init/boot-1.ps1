# boot-1: This script is run as Administrator during OOBE. Most configuration and installation should have been done in
# the previous step, this should just be the final cleanup and optimization.
$ErrorActionPreference = "Inquire"

#####

Write-Output "Installing QEMU agent (virtio already installed)"
& "C:\virtio-win-guest-tools.exe" /install /quiet | Out-Null

Write-Output "Waiting for all packages to be installed"
Do {
  Sleep 10
  $stagedPackages = Get-AppxPackage -AllUsers | Where-Object { $_.PackageUserInformation.InstallState -ne 'Installed' }
  Write-Output "[$(Get-Date)] Currently installing packages: $($stagedPackages.PackageFullName -join ', ')"
} While ($stagedPackages)

Write-Output "Waiting for all scheduled tasks to finish"
Do {
  Sleep 10
  $runningTasks = Get-ScheduledTask | Where-Object State -NE "Disabled" | Where-Object State -NE "Ready"
  Write-Output "[$(Get-Date)] Currently running tasks: $($runningTasks.TaskName -join ', ')"
} While ($runningTasks)

#####

Write-Output "Disabling all scheduled tasks with a scheduled time or idle trigger"
Get-ScheduledTask | Where-Object State -NE "Disabled" |
  Where-Object { $_.Triggers | Where-Object { $_.CimClass -Like "*idle*" } } |
  Disable-ScheduledTask -ErrorAction SilentlyContinue |
  Out-Null
Get-ScheduledTask | Where-Object State -NE "Disabled" |
  Get-ScheduledTaskInfo | Where-Object { $_.NextRunTime -ne $null } |
  ForEach-Object { Disable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue } |
  Out-Null


#####




#####

Write-Output "Removing delivery optimization files"
Delete-DeliveryOptimizationCache -Force 2>&1 | Out-Null

Write-Output "Clearing all remaining temp files and caches"
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue *>&1 | Out-Null
Remove-Item -Path "C:\Users\Administrator\AppData\Local\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue *>&1 | Out-Null
Remove-Item -Path "C:\Users\Administrator\AppData\Local\Microsoft\Windows\INetCache\*" -Recurse -Force -ErrorAction SilentlyContinue *>&1 | Out-Null

Write-Output "Removing unused windows components"
& Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase | Out-Null

Write-Output "Defragmenting and trimming"
Optimize-Volume -DriveLetter C -Defrag -ReTrim -SlabConsolidate | Out-Null

Write-Output "Compressing drive"
& compact.exe /compactos:always *>&1 | Out-Null

Write-Output "Successfully provisioned image."

#####

Stop-Computer -Force
