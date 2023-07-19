# boot-0: This script is run as the SYSTEM user on the first boot post-installer. System will reboot automatically on completion.

$ErrorActionPreference = "Inquire"
Start-Transcript -Append C:\provision.txt
Write-Output "Starting $PSCommandPath on PowerShell $($PSVersionTable.PSVersion.ToString())"

#####

Write-Output "Disabling system access to Windows Defender, Windows Update and Edge Updater"
$serviceName = @(
  "Sense", "WdBoot", "WdFilter", "WdNisDrv", "WdNisSvc", "WinDefend",   # Windows Defender
  "WaasMedicSvc", "wuauserv", "UsoSvc",                                 # Windows Update
  "edgeupdate", "edgeupdatem"                                           # Edge Updater
)
foreach ($service in $serviceName) {
  $key = "HKLM:\SYSTEM\CurrentControlSet\Services\$service"
  $acl = Get-Acl $key ; $acl.SetAccessRuleProtection($true, $true) ; Set-Acl $key $acl
  $acl = Get-Acl $key ; $acl.RemoveAccessRuleAll((New-Object System.Security.AccessControl.RegistryAccessRule("NT AUTHORITY\SYSTEM", "FullControl", "Allow"))) ; Set-Acl $key $acl
  Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
  Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
}

Write-Output "Disabling Windows Defender tasks"
Get-ScheduledTask -TaskPath '\Microsoft\Windows\Windows Defender*' | Disable-ScheduledTask

Write-Output "Disabling OOBE overlay for first Administrator login"
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'EnableFirstLogonAnimation' -Value 0 -Type DWord -Force

Write-Output "Disabling scheduled tasks and disk cleanup"
Disable-ScheduledTask -TaskName 'ScheduledDefrag' -TaskPath '\Microsoft\Windows\Defrag'
Disable-ScheduledTask -TaskName 'ProactiveScan' -TaskPath '\Microsoft\Windows\Chkdsk'
Disable-ScheduledTask -TaskName 'Scheduled' -TaskPath '\Microsoft\Windows\Diagnosis'
Disable-ScheduledTask -TaskName 'SilentCleanup' -TaskPath '\Microsoft\Windows\DiskCleanup'
Disable-ScheduledTask -TaskName 'WinSAT' -TaskPath '\Microsoft\Windows\Maintenance'
Disable-ScheduledTask -TaskName 'StartComponentCleanup' -TaskPath '\Microsoft\Windows\Servicing'

Write-Output "Disabling other scheduled tasks used for security"
Get-ScheduledTask -TaskPath '\Microsoft\Windows\Data Integrity Scan*' | Disable-ScheduledTask
Get-ScheduledTask -TaskPath '\Microsoft\Windows\Diagnosis*' | Disable-ScheduledTask
Get-ScheduledTask -TaskPath '\Microsoft\Windows\SoftwareProtectionPlatform*' | Disable-ScheduledTask
Get-ScheduledTask -TaskPath '\Microsoft\Windows\UpdateOrchestrator*' | Disable-ScheduledTask
Get-ScheduledTask -TaskPath '\Microsoft\Windows\WaaSMedic*' | Disable-ScheduledTask
Get-ScheduledTask -TaskPath '\Microsoft\Windows\Windows Defender*' | Disable-ScheduledTask
Get-ScheduledTask -TaskPath '\Microsoft\Windows\WindowsUpdate*' | Disable-ScheduledTask

Write-Output "Rebooting and will contiunue into A:\boot-1.ps1 with Administrator user"
Sleep 5
