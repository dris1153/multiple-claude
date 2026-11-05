# Shared names and paths for install.ps1, uninstall.ps1 and the runtime scripts (dot-sourced).
# Changing a value orphans what an earlier install created, so keep them stable.
$Root = Join-Path $env:USERPROFILE '.claude-instances'
$IconDir = Join-Path $Root 'icons'
$Bin = Join-Path $env:USERPROFILE '.claude\bin'
$StartMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$SyncTask = 'claude-session-sync'
$RefreshTask = 'claude-instances-refresh'
$RouterName = 'Claude Link Router'
$RouterExe = Join-Path $Root 'claude-link-router.exe'
$RouterProgId = 'ClaudeLinkRouter.url'
$RouterCapKey = 'HKCU:\Software\ClaudeLinkRouter'
$UserChoiceKey = 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\claude\UserChoice'
# Copied to $Root so the refresh task keeps working when the repo folder is moved or deleted.
$RuntimeScripts = 'config.ps1', 'build-instance.ps1', 'set-exe-icon.ps1', 'refresh-instances.ps1'
