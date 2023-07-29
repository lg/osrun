# boot-0: This script is run as the SYSTEM user on the first boot post-installer. System will reboot automatically on completion.
$ErrorActionPreference = "Inquire"

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
  Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue | Out-Null
  Stop-Service -Name $service -Force -ErrorAction SilentlyContinue | Out-Null
}

Write-Output "Disabling Windows Defender tasks"
Get-ScheduledTask -TaskPath '\Microsoft\Windows\Windows Defender*' | Disable-ScheduledTask | Out-Null

Write-Output "Disabling OOBE overlay for first Administrator login"
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'EnableFirstLogonAnimation' -Value 0 -Type DWord -Force

Write-Output "Disabling scheduled tasks and disk cleanup"
Disable-ScheduledTask -TaskName 'ScheduledDefrag' -TaskPath '\Microsoft\Windows\Defrag' | Out-Null
Disable-ScheduledTask -TaskName 'ProactiveScan' -TaskPath '\Microsoft\Windows\Chkdsk' | Out-Null
Disable-ScheduledTask -TaskName 'Scheduled' -TaskPath '\Microsoft\Windows\Diagnosis' | Out-Null
Disable-ScheduledTask -TaskName 'SilentCleanup' -TaskPath '\Microsoft\Windows\DiskCleanup' | Out-Null
Disable-ScheduledTask -TaskName 'WinSAT' -TaskPath '\Microsoft\Windows\Maintenance' | Out-Null
Disable-ScheduledTask -TaskName 'StartComponentCleanup' -TaskPath '\Microsoft\Windows\Servicing' | Out-Null

Write-Output "Disabling other scheduled tasks used for security"
Get-ScheduledTask -TaskPath '\Microsoft\Windows\Data Integrity Scan*' | Disable-ScheduledTask | Out-Null
Get-ScheduledTask -TaskPath '\Microsoft\Windows\Diagnosis*' | Disable-ScheduledTask | Out-Null
Get-ScheduledTask -TaskPath '\Microsoft\Windows\SoftwareProtectionPlatform*' | Disable-ScheduledTask | Out-Null
Get-ScheduledTask -TaskPath '\Microsoft\Windows\UpdateOrchestrator*' | Disable-ScheduledTask | Out-Null
Get-ScheduledTask -TaskPath '\Microsoft\Windows\WaaSMedic*' | Disable-ScheduledTask | Out-Null
Get-ScheduledTask -TaskPath '\Microsoft\Windows\Windows Defender*' | Disable-ScheduledTask | Out-Null
Get-ScheduledTask -TaskPath '\Microsoft\Windows\WindowsUpdate*' | Disable-ScheduledTask | Out-Null

###

Write-Output "Disabling other scheduled tasks"
Disable-ScheduledTask -TaskName 'MicrosoftEdgeUpdateTaskMachineUA' -TaskPath '\' | Out-Null
Get-ScheduledTask -TaskPath '\Microsoft\Windows\Customer Experience Improvement Program*' | Disable-ScheduledTask | Out-Null
Get-ScheduledTask -TaskPath '\Microsoft\Windows\Flighting*' | Disable-ScheduledTask | Out-Null
Get-ScheduledTask -TaskPath '\Microsoft\Windows\Windows Error Reporting*' | Disable-ScheduledTask | Out-Null
Get-ScheduledTask -TaskPath '\Microsoft\Windows\InstallService*' | Disable-ScheduledTask | Out-Null
Get-ScheduledTask -TaskName "*OneDrive*" | Disable-ScheduledTask | Out-Null

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
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0

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
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateFileSizePercent" -Value 0
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabled" -Value 0

Write-Output "Making sure long paths are enabled so we can access all files"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1

Write-Output "Disabling NTP time sync"
Start-Process -FilePath "w32tm.exe" -ArgumentList "/config", "/syncfromflags:NO" -Wait

Write-Output "Disabling Widgets"
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Value 0

Write-Output "Hiding Windows Security notifications"
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" -Name "DisableNotifications" -Value 1

Write-Output "Hiding Suggested Content from Start Menu"
$registryKeys = @("DisableSoftLanding", "SubscribedContent-338393Enabled", "SubscribedContent-338389Enabled",
  "SubscribedContent-353694Enabled", "SubscribedContent-353696Enabled", "DisableWindowsConsumerFeatures")
New-Item -Path "HKLM:\HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Force | Out-Null
foreach ($key in $registryKeys) {
  New-ItemProperty -Path "HKLM:\HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name $key -Value 1 -PropertyType DWORD -Force | Out-Null
}
$registryKeys = @("ContentDeliveryAllowed", "FeatureManagementEnabled", "OemPreInstalledAppsEnabled",
  "PreInstalledAppsEnabled", "SilentInstalledAppsEnabled", "SoftLandingEnabled", "SystemPaneSuggestionsEnabled")
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Force | Out-Null
foreach ($key in $registryKeys) {
  Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name $key -Value 0
}

Write-Output "Removing Chat/Teams icon from taskbar"
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat" -Name "ChatIcon" -Value 3

Write-Output "Disabling Content Delivery Manager"
New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SilentInstalledAppsEnabled" -Value 0

Write-Output "Downloading and extracting SpaceMonger"
Invoke-WebRequest -Uri "https://archive.org/download/spcmn140_zip/spcmn140.zip" -OutFile "C:\sm.zip"
Expand-Archive -Path "C:\sm.zip" -DestinationPath "C:\" -Force
Remove-Item "C:\sm.zip"

Write-Output "Downloading and extracting RegistryChangesView"
Invoke-WebRequest -Uri "https://www.nirsoft.net/utils/registrychangesview-x64.zip" -OutFile "C:\rcv.zip"
Expand-Archive -Path "C:\rcv.zip" -DestinationPath "C:\" -Force
Remove-Item "C:\rcv.zip"

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

Write-Output "Setting up autologin for Administrator user in the future"
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty $RegPath "AutoAdminLogon" -Value "1" -Type String
Set-ItemProperty $RegPath "DefaultUserName" -Value "Administrator" -Type String
Set-ItemProperty $RegPath "DefaultPassword" -Value "" -Type String
Set-ItemProperty $RegPath "IsConnectedAutoLogon" -Value 0 -Type DWord
New-Item "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device" -Force | Out-Null
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device" "DevicePasswordLessBuildVersion" -Value 0 | Out-Null

Write-Output "Rebooting and will continue into D:\boot-1.ps1 with Administrator user as per autounattend.xml"
