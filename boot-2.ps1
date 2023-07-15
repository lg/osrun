Start-Transcript -Append C:\provision.txt

Write-Output "Waiting for upgrades to complete and winget to become available"
While (!(Test-Path C:\Users\Administrator\AppData\Local\Microsoft\WindowsApps\winget.exe -ErrorAction SilentlyContinue)) { Sleep 1 }

Write-Output "Removing software using winget"
$software = @("Clipchamp", "Cortana", "XBox", "Feedback Hub", "Get Help", "Microsoft Tips", "Office", "OneDrive",
  "Microsoft News", "Microsoft Solitaire Collection", "Microsoft Sticky Notes", "Microsoft People", "Microsoft To Do",
  "Microsoft Photos", "MSN Weather", "Windows Camera", "Windows Voice Recorder", "Microsoft Store", "Xbox TCUI",
  "Xbox Game Bar Plugin", "Xbox Game Bar", "Xbox Identity Provider", "Xbox Game Speech Window", "Your Phone",
  "Windows Media Player", "Movies & TV", "Quick Assist", "Mail and Calendar", "Windows Maps", "Store Experience Host",
  "Windows Calculator", "Power Automate", "Snipping Tool", "Paint", "Windows Web Experience Pack")
$software | ForEach-Object { & winget.exe uninstall $_ --accept-source-agreements }

Write-Output "Upgrading the remaining winget packages..."
& winget upgrade --all | Out-Default

Write-Output "Downloading and extracting SpaceMonger..."
Invoke-WebRequest -Uri "https://archive.org/download/spcmn140_zip/spcmn140.zip" -OutFile "C:\sm.zip"
Expand-Archive -Path "C:\sm.zip" -DestinationPath "C:\" -Force
Remove-Item "C:\sm.zip"

Write-Output "Setting up OpenSSH for remote management (but won't start until reboot)"
Add-WindowsCapability -Online -Name OpenSSH.Server
Set-Service sshd -StartupType Automatic
Enable-NetFirewallRule OpenSSH*

Write-Output "All done, final reboot!"
Restart-Computer -Force

# TODO:
# - Autologin
# - Run DISM commands and other Disk Cleanup items
# - Remove any last lingering windows features
# - Log to serial
# - Add Services to right click
