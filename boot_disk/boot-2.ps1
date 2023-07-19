# boot-2: This script is run after Windows Updates are applied.
$ErrorActionPreference = "Inquire"
Start-Transcript -Append C:\provision.txt
Write-Output "Starting $PSCommandPath on PowerShell $($PSVersionTable.PSVersion.ToString())"

#####

Write-Output "Installing OpenSSH (while Windows Update is still usable)"
Set-Service wuauserv -StartupType Automatic
Start-Service wuauserv
Add-WindowsCapability -Online -Name OpenSSH.Server
Enable-NetFirewallRule OpenSSH*

Write-Output "One last disable of Windows Update, including removing permissions to download more"
Set-Service wuauserv -StartupType Disabled
Stop-Service wuauserv -Force
Start-Process -FilePath "takeown.exe" -ArgumentList "/f c:\Windows\SoftwareDistribution /r /d y /skipsl" -Wait -NoNewWindow | Out-Null
Start-Process -FilePath "icacls.exe" -ArgumentList "c:\Windows\SoftwareDistribution /inheritance:r /t /c" -Wait -NoNewWindow | Out-Null
Start-Process -FilePath "icacls.exe" -ArgumentList "c:\Windows\SoftwareDistribution /remove:g SYSTEM /t /c" -Wait -NoNewWindow | Out-Null
Remove-Item -Path "C:\Windows\SoftwareDistribution\*" -Recurse -Force | Out-Null

#####

Write-Output "Removing Windows Capabilities"
$CapabilitiesToRemove = @("App.StepsRecorder", "Hello.Face.*", "Language.Handwriting", "Language.OCR", "Language.Speech",
  "Language.TextToSpeech", "Media.WindowsMediaPlayer", "Microsoft.Wallpapers.Extended", "Microsoft.Windows.Ethernet.Client*",
  "Microsoft.Windows.Wifi*", "Microsoft.Windows.WordPad", "OneCoreUAP.OneSync", "Print.Management.Console", "MathRecognizer")
Get-WindowsCapability -Online |
  Where-Object State -EQ "Installed" |
  Where-Object Name -Match ($CapabilitiesToRemove -join "|") |
  Remove-WindowsCapability -Online

Write-Output "Removing Windows Optional Features"
$WindowsOptionalFeatures = @("SearchEngine-Client-Package", "Printing-Foundation-Features", "Printing-Foundation-InternetPrinting-Client", "WorkFolders-Client")
Get-WindowsOptionalFeature -Online |
  Where-Object State -EQ "Enabled" |
  Where-Object FeatureName -Match ($WindowsOptionalFeatures -join "|") |
  Disable-WindowsOptionalFeature -Online -Remove -NoRestart

Write-Output "Removing delivery optimization files"
Delete-DeliveryOptimizationCache -Force

Write-Output "Uninstalling OneDrive"
Start-Process -FilePath "taskkill.exe" -ArgumentList "/f /im OneDrive.exe" -Wait -NoNewWindow
Start-Process -FilePath "C:\Windows\system32\OneDriveSetup.exe" -ArgumentList "/uninstall" -Wait -NoNewWindow

Write-Output "Setting up autologin for Administrator"
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty $RegPath "AutoAdminLogon" -Value "1" -Type String
Set-ItemProperty $RegPath "DefaultUserName" -Value "Administrator" -Type String
Set-ItemProperty $RegPath "DefaultPassword" -Value "password" -Type String
Set-ItemProperty $RegPath "IsConnectedAutoLogon" -Value 0 -Type DWord
New-Item "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device" -Force
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device" "DevicePasswordLessBuildVersion" -Value 0



# Write-Output "Locking out the OS from overriding we want AutoAdminLogon"
# $key = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
# $acl = Get-Acl $key ; $acl.SetAccessRuleProtection($true, $true) ; Set-Acl $key $acl
# $acl = Get-Acl $key ; $acl.RemoveAccessRuleAll((New-Object System.Security.AccessControl.RegistryAccessRule("NT AUTHORITY\SYSTEM", "FullControl", "Allow"))) ; Set-Acl $key $acl









# New-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Force
# Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Value 1
# Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Name TargetReleaseVersion -Value '00000001' -Type DWord -Force
# Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Name "ProductVersion" -Value 'Windows 10' -Type String -Force
# Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Name TargetReleaseVersionInfo -Value '22H2' -Type String -Force
# Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" -Name "AUOptions" -Value 1
# Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "127.0.0.1 fe2cr.update.microsoft.com"
# Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "127.0.0.1 windowsupdate.microsoft.com"
# Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "127.0.0.1 emdl.ws.microsoft.com"
# Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "127.0.0.1 update.microsoft.com"
# Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "127.0.0.1 windowsupdate.com"
# Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "127.0.0.1 download.windowsupdate.com"
# Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\DoSvc' -Name Start -Value 4

#####

Write-Output "Rebooting to let things finish up and then running A:\boot-3.ps1"
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "boot-3" -Value "powershell -ExecutionPolicy Bypass -File A:\boot-3.ps1"
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
