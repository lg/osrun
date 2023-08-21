# boot-0: This script is run as the SYSTEM user on the first boot post-installer. System will reboot automatically on completion.
$ErrorActionPreference = "Inquire"
$ProgressPreference = "SilentlyContinue"

function Set-RegItem {
  param ([Parameter(Mandatory=$true)] [string]$PathWithName, [Parameter(Mandatory=$true)] $Value)
  $Path = $PathWithName.Substring(0, $PathWithName.LastIndexOf("\"))
  $Name = $PathWithName.Substring($PathWithName.LastIndexOf("\") + 1)

  if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
  Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force | Out-Null
}

Write-Output "Disabling system access to Windows Defender, Windows Update and Edge Updater"
$serviceName = @(
  "Sense", "WdBoot", "WdFilter", "WdNisDrv", "WdNisSvc", "WinDefend",   # Windows Defender
  "SecurityHealthService",
  "WaasMedicSvc", "wuauserv", "UsoSvc",                                 # Windows Update
  "edgeupdate", "edgeupdatem", "MicrosoftEdgeElevationService"          # Edge Updater
  "sppsvc",                                                             # Software Protection Platform
  "SgrmBroker"                                                          # System Guard Runtime Monitor Broker
)
foreach ($service in $serviceName) {
  $key = "HKLM:\SYSTEM\CurrentControlSet\Services\$service"
  if (!(Test-Path $key)) {
    Write-Output "Waiting for service $service to get created"
    while (!(Test-Path $key)) { Start-Sleep -Seconds 1 }
  }
  $acl = Get-Acl $key ; $acl.SetAccessRuleProtection($true, $true) ; Set-Acl $key $acl
  $acl.Access | ForEach-Object { try { $acl.RemoveAccessRule($_) } catch {} } | Out-Null
  Set-Acl $key $acl
  Set-Service -Name $service -StartupType Disabled -ErrorAction Ignore | Out-Null
  Stop-Service -Name $service -Force -ErrorAction Ignore | Out-Null
}

Write-Output "Disabling scheduled tasks used for Windows Defender, Windows Update and Edge Updater"
Get-ScheduledTask -TaskPath '\Microsoft\Windows\Data Integrity Scan*' | Disable-ScheduledTask | Out-Null
Get-ScheduledTask -TaskPath '\Microsoft\Windows\Diagnosis*' | Disable-ScheduledTask | Out-Null
Get-ScheduledTask -TaskPath '\Microsoft\Windows\SoftwareProtectionPlatform*' | Disable-ScheduledTask | Out-Null
Get-ScheduledTask -TaskPath '\Microsoft\Windows\UpdateOrchestrator*' | Disable-ScheduledTask | Out-Null
Get-ScheduledTask -TaskPath '\Microsoft\Windows\WaaSMedic*' | Disable-ScheduledTask | Out-Null
Get-ScheduledTask -TaskPath '\Microsoft\Windows\Windows Defender*' | Disable-ScheduledTask | Out-Null
Get-ScheduledTask -TaskPath '\Microsoft\Windows\WindowsUpdate*' | Disable-ScheduledTask | Out-Null
Get-ScheduledTask -TaskPath '\' -TaskName 'MicrosoftEdgeUpdate*' | Disable-ScheduledTask | Out-Null

Write-Output "Uninstalling Edge and disabling its automatic reinstall"
Set-RegItem -PathWithName "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\DoNotUpdateToEdgeWithChromium" -Value 1
Get-Process "*Edge*" | Stop-Process -Force
Start-Process -FilePath "C:\Program Files (x86)\Microsoft\Edge\Application\*\Installer\setup.exe" -ArgumentList "--uninstall", "--system-level", "--verbose-logging", "--force-uninstall" -Wait
Remove-Item "C:\Program Files (x86)\Microsoft\Edge*" -Recurse -Force

Write-Output "Disabling Smart Screen"
Set-RegItem -PathWithName "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System\EnableSmartScreen" -Value 0
Set-RegItem -PathWithName "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\SmartScreenEnabled" -Value "Off"

Write-Output "Fully disabling sensitive files from any access"
$executables = @(
  "c:\windows\system32\smartscreen.exe",
  "c:\windows\system32\sppsvc.exe",
  "c:\windows\system32\ctfmon.exe",
  "c:\windows\system32\Sgrm\SgrmBroker.exe",
  "c:\Program Files\Windows Defender\MpCmdRun.exe"
)
foreach ($executable in $executables) {
  $acl = Get-Acl $executable ; $acl.SetAccessRuleProtection($true, $true) ; Set-Acl $executable $acl
  $acl.Access | ForEach-Object { try { $acl.RemoveAccessRule($_) } catch {} } | Out-Null
  Set-Acl $executable $acl
}

Write-Output "Disabling all scheduled tasks with a scheduled time or idle trigger"
Get-ScheduledTask | Where-Object State -NE "Disabled" |
  Where-Object { $_.Triggers | Where-Object { $_.CimClass -Like "*idle*" } } | Disable-ScheduledTask | Out-Null
Get-ScheduledTask | Where-Object State -NE "Disabled" |
  Get-ScheduledTaskInfo | Where-Object { $_.NextRunTime -ne $null } |
  ForEach-Object { Disable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath | Out-Null }

Write-Output "Disable scheduled tasks known to be stragglers"
Disable-ScheduledTask -TaskPath '\Microsoft\Windows\Multimedia' -TaskName 'SystemSoundsService' | Out-Null
Disable-ScheduledTask -TaskPath '\Microsoft\Windows\Wininet' -TaskName 'CacheTask' | Out-Null
Disable-ScheduledTask -TaskPath '\Microsoft\Windows\WlanSvc' -TaskName 'CDSSync' | Out-Null

Write-Output "Removing filesystem permissions for Windows Update"
& icacls.exe "c:\Windows\SoftwareDistribution" /inheritance:r /t /c *>&1 | Out-Null
& icacls.exe "c:\Windows\SoftwareDistribution" /remove:g SYSTEM /t /c *>&1 | Out-Null

Write-Output "Disabling scheduled tasks and disk cleanup"
Disable-ScheduledTask -TaskName 'ScheduledDefrag' -TaskPath '\Microsoft\Windows\Defrag' | Out-Null
Disable-ScheduledTask -TaskName 'ProactiveScan' -TaskPath '\Microsoft\Windows\Chkdsk' | Out-Null
Disable-ScheduledTask -TaskName 'Scheduled' -TaskPath '\Microsoft\Windows\Diagnosis' | Out-Null
Disable-ScheduledTask -TaskName 'SilentCleanup' -TaskPath '\Microsoft\Windows\DiskCleanup' | Out-Null
Disable-ScheduledTask -TaskName 'WinSAT' -TaskPath '\Microsoft\Windows\Maintenance' | Out-Null
Disable-ScheduledTask -TaskName 'StartComponentCleanup' -TaskPath '\Microsoft\Windows\Servicing' | Out-Null

Write-Output "Disabling other less useful scheduled tasks"
Get-ScheduledTask -TaskPath '\Microsoft\Windows\Customer Experience Improvement Program*' | Disable-ScheduledTask | Out-Null
Get-ScheduledTask -TaskPath '\Microsoft\Windows\Flighting*' | Disable-ScheduledTask | Out-Null
Get-ScheduledTask -TaskPath '\Microsoft\Windows\Windows Error Reporting*' | Disable-ScheduledTask | Out-Null
Get-ScheduledTask -TaskPath '\Microsoft\Windows\InstallService*' | Disable-ScheduledTask | Out-Null
Get-ScheduledTask -TaskName "*OneDrive*" | Disable-ScheduledTask | Out-Null

#####

Write-Output "Disabling System Restore"
Disable-ComputerRestore -Drive "C:"

Write-Output "Removing Recovery Environment"
Start-Process -FilePath "reagentc.exe" -ArgumentList "/disable" -Wait

Write-Output "Disabling OS Recovery"
Get-WmiObject Win32_OSRecoveryConfiguration -EnableAllPrivileges | Set-WmiInstance -Arguments @{ AutoReboot = $False } | Out-Null

Write-Output "Disabling Error Reporting"
Disable-WindowsErrorReporting | Out-Null

Write-Output "Disabling and deleting page file"
$computersys = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
$computersys.AutomaticManagedPagefile = $False
$computersys.Put() | Out-Null
$pagefile = Get-WmiObject win32_pagefilesetting
$pagefile.delete() | Out-Null

Write-Output "Disabling disk indexing"
$obj = Get-WmiObject -Class Win32_Volume -Filter "DriveLetter='C:'"
$obj | Set-WmiInstance -Arguments @{ IndexingEnabled = $False } | Out-Null
Set-RegItem -PathWithName "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search\AllowCortana" -Value 0

Write-Output "Disabling Windows Search"
Set-Service WSearch -StartupType Disabled
Stop-Service -Name WSearch

Write-Output "Setting performance mode"
Start-Process -FilePath "powercfg.exe" -ArgumentList "-setactive", "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" -Wait

Write-Output "Disabling sleep and hibernation"
Start-Process -FilePath "powercfg.exe" -ArgumentList "-change", "-monitor-timeout-ac", "0" -Wait
Start-Process -FilePath "powercfg.exe" -ArgumentList "-change", "-standby-timeout-ac", "0" -Wait
Start-Process -FilePath "powercfg.exe" -ArgumentList "-change", "-disk-timeout-ac", "0" -Wait
Start-Process -FilePath "powercfg.exe" -ArgumentList "-change", "-hibernate-timeout-ac", "0" -Wait
Start-Process -FilePath "powercfg.exe" -ArgumentList "/h", "off" -Wait
Set-RegItem -PathWithName "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power\HiberbootEnabled" -Value 0
Set-RegItem -PathWithName "HKLM:\SYSTEM\CurrentControlSet\Control\Power\HibernateFileSizePercent" -Value 0
Set-RegItem -PathWithName "HKLM:\SYSTEM\CurrentControlSet\Control\Power\HibernateEnabled" -Value 0

Write-Output "Making sure long paths are enabled so we can access all files"
Set-RegItem -PathWithName "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem\LongPathsEnabled" -Value 1

Write-Output "Disabling NTP time sync"
Start-Process -FilePath "w32tm.exe" -ArgumentList "/config", "/syncfromflags:NO" -Wait

Write-Output "Disabling Widgets"
Set-RegItem -PathWithName "HKLM:\SOFTWARE\Policies\Microsoft\Dsh\AllowNewsAndInterests" -Value 0

Write-Output "Hiding Windows Security notifications"
Set-RegItem -PathWithName "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications\DisableNotifications" -Value 1

Write-Output "Hiding Suggested Content from Start Menu"
$registryKeys = @("DisableSoftLanding", "SubscribedContent-338393Enabled", "SubscribedContent-338389Enabled",
  "SubscribedContent-353694Enabled", "SubscribedContent-353696Enabled", "DisableWindowsConsumerFeatures")
foreach ($key in $registryKeys) {
  Set-RegItem -PathWithName "HKLM:\HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CloudContent\$key" -Value 1
}
$registryKeys = @("ContentDeliveryAllowed", "FeatureManagementEnabled", "OemPreInstalledAppsEnabled",
  "PreInstalledAppsEnabled", "SilentInstalledAppsEnabled", "SoftLandingEnabled", "SystemPaneSuggestionsEnabled")
foreach ($key in $registryKeys) {
  Set-RegItem -PathWithName "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\$key" -Value 0
}

Write-Output "Removing Chat/Teams icon from taskbar"
Set-RegItem -PathWithName "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat\ChatIcon" -Value 3

Write-Output "Disabling Content Delivery Manager"
Set-RegItem -PathWithName "HKLM:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SilentInstalledAppsEnabled" -Value 0

Write-Output "Downloading and extracting SpaceMonger"
Invoke-WebRequest -Uri "https://archive.org/download/spcmn140_zip/spcmn140.zip" -OutFile "C:\sm.zip"
Expand-Archive -Path "C:\sm.zip" -DestinationPath "C:\" -Force
Remove-Item "C:\sm.zip"

Write-Output "Downloading and extracting RegistryChangesView"
Invoke-WebRequest -Uri "https://www.nirsoft.net/utils/registrychangesview-x64.zip" -OutFile "C:\rcv.zip"
Expand-Archive -Path "C:\rcv.zip" -DestinationPath "C:\" -Force
Remove-Item "C:\rcv.zip"

Write-Output "Downloading and extracting Process Monitor"
Invoke-WebRequest -Uri "https://download.sysinternals.com/files/ProcessMonitor.zip" -OutFile "C:\processmonitor.zip"
Expand-Archive -Path "C:\processmonitor.zip" -DestinationPath "C:\" -Force
Remove-Item "C:\processmonitor.zip"

Write-Output "Downloading virtio drivers (agent will be installed later)"
Invoke-WebRequest -Uri "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win-guest-tools.exe" -OutFile "C:\virtio-win-guest-tools.exe"
& "C:\virtio-win-guest-tools.exe" /install /norestart /quiet | Out-Null

Write-Output "Downloading virtio drivers and SPICE guest tools"
Invoke-WebRequest -Uri "https://www.spice-space.org/download/windows/vdagent/vdagent-win-0.10.0/spice-vdagent-x64-0.10.0.msi" -OutFile "C:\spice.msi"
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "C:\spice.msi", "/quiet", "/norestart" -Wait
Remove-Item "C:\spice.msi"

Write-Output "Downloading and installing Chrome (enterprise MSI)"
Set-RegItem -PathWithName "HKLM:\SOFTWARE\Policies\Google\Update\UpdateDefault" -Value 0
Invoke-WebRequest -Uri "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi" -OutFile "C:\chrome.msi"
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "C:\chrome.msi", "/quiet", "/norestart" -Wait
Remove-Item "C:\chrome.msi"

Write-Output "Disabling OOBE overlay for first Administrator login"
Set-RegItem -PathWithName "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\EnableFirstLogonAnimation" -Value 0

###

Write-Output "Removing Windows Capabilities"
$CapabilitiesToRemove = @("App.StepsRecorder", "Hello.Face.*", "Language.Handwriting", "Language.OCR", "Language.Speech",
  "Language.TextToSpeech", "Media.WindowsMediaPlayer", "Microsoft.Wallpapers.Extended", "Microsoft.Windows.Ethernet.Client*",
  "Microsoft.Windows.Wifi*", "Microsoft.Windows.WordPad", "OneCoreUAP.OneSync", "Print.Management.Console", "MathRecognizer")
Get-WindowsCapability -Online |
  Where-Object State -EQ "Installed" |
  Where-Object Name -Match ($CapabilitiesToRemove -join "|") |
  Remove-WindowsCapability -Online |
  Out-Null

Write-Output "Removing Windows Optional Features"
$WindowsOptionalFeatures = @("SearchEngine-Client-Package", "Printing-Foundation-Features",
  "Printing-Foundation-InternetPrinting-Client", "WorkFolders-Client")
Get-WindowsOptionalFeature -Online |
  Where-Object State -EQ "Enabled" |
  Where-Object FeatureName -Match ($WindowsOptionalFeatures -join "|") |
  Disable-WindowsOptionalFeature -Online -Remove -NoRestart *>&1 |
  Select-String -NotMatch -Pattern "Restart is suppressed" |
  Out-Null

##### DEFAULT USER SETTINGS BELOW

Write-Output "Removing OneDrive installer"
Remove-Item "C:\Windows\System32\OneDriveSetup.exe" -Force
New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS | Out-Null
Reg Load "HKU\DefaultHive" "C:\Users\Default\NTUser.dat" | Out-Null
if (Get-ItemProperty "HKU:\DefaultHive\Software\Microsoft\Windows\CurrentVersion\Run" | Select-Object -ExpandProperty "OneDriveSetup") {
  Remove-ItemProperty -Path "HKU:\DefaultHive\Software\Microsoft\Windows\CurrentVersion\Run" -Name "OneDriveSetup" -Force
}

Write-Output "Disabling Smart Screen for user"
Set-RegItem -PathWithName "HKU:\DefaultHive\Software\Microsoft\Edge\SmartScreenEnabled\(Default)" -Value 0
Set-RegItem -PathWithName "HKU:\DefaultHive\Software\Microsoft\Windows\CurrentVersion\AppHost\EnableWebContentEvaluation" -Value 0
Set-RegItem -PathWithName "HKU:\DefaultHive\Software\Microsoft\Windows\CurrentVersion\AppHost\PreventOverride" -Value 0

Write-Output "Disabling Content Delivery Manager"
$ContentDeliveryKeys = @("ContentDeliveryAllowed", "FeatureManagementEnabled", "OemPreInstalledAppsEnabled",
"PreInstalledAppsEnabled", "PreInstalledAppsEverEnabled", "SilentInstalledAppsEnabled", "SoftLandingEnabled",
"SubscribedContentEnabled", "SystemPaneSuggestionsEnabled", "SubscribedContent-310093Enabled",
"SubscribedContent-338388Enabled", "SubscribedContent-338389Enabled", "SubscribedContent-338393Enabled",
"SubscribedContent-353694Enabled", "SubscribedContent-353696Enabled", "SubscribedContentEnabled")
foreach ($key in $ContentDeliveryKeys) {
  Set-RegItem -PathWithName "HKU:\DefaultHive\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\$key" -Value 0
}
Set-RegItem -PathWithName "HKLM:\Software\Policies\Microsoft\PushToInstall\DisablePushToInstall" -Value 1
Set-RegItem -PathWithName "HKLM:\Software\Policies\Microsoft\MRT\DontOfferThroughWUAU" -Value 1
Remove-Item "HKU:\DefaultHive\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Subscriptions" -Force -ErrorAction SilentlyContinue
Remove-Item "HKU:\DefaultHive\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SuggestedApps" -Force -ErrorAction SilentlyContinue

Write-Output "Enabling Explorer performance settings"
Set-RegItem -PathWithName "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl\Win32PrioritySeparation" -Value 38
Set-RegItem -PathWithName "HKU:\DefaultHive\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\VisualFXSetting" -Value 2

Write-Output "Removing web search"
Set-RegItem -PathWithName "HKU:\DefaultHive\Software\Policies\Microsoft\Windows\Explorer\DisableSearchBoxSuggestions" -Value 1

Write-Output "Removing remaining ads"
Set-RegItem -PathWithName "HKU:\DefaultHive\SOFTWARE\Policies\Microsoft\Windows\CloudContent\DisableWindowsConsumerFeatures" -Value 1

Write-Output "Giving Explorer sensible folder view defaults"
Set-RegItem -PathWithName "HKU:\DefaultHive\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\HideFileExt" -Value 0
Set-RegItem -PathWithName "HKU:\DefaultHive\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\HideDrivesWithNoMedia" -Value 0
Set-RegItem -PathWithName "HKU:\DefaultHive\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\Hidden" -Value 1
Set-RegItem -PathWithName "HKU:\DefaultHive\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\AutoCheckSelect" -Value 0
Set-RegItem -PathWithName "HKU:\DefaultHive\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ShowSuperHidden" -Value 1

Write-Output "Making Explorer not combine taskbar buttons"
Set-RegItem -PathWithName "HKU:\DefaultHive\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarGlomLevel" -Value 2

Write-Output "Adding Run and Admin Tools to Start button"
Set-RegItem -PathWithName "HKU:\DefaultHive\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\Start_ShowRun" -Value 1
Set-RegItem -PathWithName "HKU:\DefaultHive\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\StartMenuAdminTools" -Value 1

#####

Write-Output "Using Run key to log future boots"
Set-RegItem -PathWithName "HKU:\DefaultHive\Software\Microsoft\Windows\CurrentVersion\Run\bootlog" -Value "cmd /c `"powershell -NoLogo -ExecutionPolicy Bypass -Command 'get-date' 2>&1 > \\10.0.2.4\qemu\lastboot.txt & exit`""

Write-Output "Rebooting and will continue into \\10.0.2.4\qemu\win11-init\boot-1.ps1 with Administrator user as per autounattend.xml"
Reg Unload "HKU\DefaultHive" | Out-Null