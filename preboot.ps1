Write-Output "Disabling Windows Defender"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Sense" -Name "Start" -Value 4 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WdBoot" -Name "Start" -Value 4 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WdFilter" -Name "Start" -Value 4 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WdNisDrv" -Name "Start" -Value 4 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WdNisSvc" -Name "Start" -Value 4 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend" -Name "Start" -Value 4 -Type DWord -Force
Disable-ScheduledTask -TaskName 'Windows Defender Cleanup' -TaskPath '\Microsoft\Windows\Windows Defender'
Disable-ScheduledTask -TaskName 'Windows Defender Scheduled Scan' -TaskPath '\Microsoft\Windows\Windows Defender'
Disable-ScheduledTask -TaskName 'Windows Defender Verification' -TaskPath '\Microsoft\Windows\Windows Defender'
Disable-ScheduledTask -TaskName 'Windows Defender Cache Maintenance' -TaskPath '\Microsoft\Windows\Windows Defender'

Write-Output "Disabling Windows Update"
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Value 1 -Type DWord -Force
Set-Service wuauserv -Startup disabled

Write-Output "Completed."
