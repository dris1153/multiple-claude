# Rebuilds every app-claudeN copy that is older than the installed Claude (skips running ones).
# Run by the claude-instances-refresh Scheduled Task; log: ~\.claude-instances\refresh.log
$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'config.ps1')
$log = Join-Path $Root 'refresh.log'
foreach ($d in Get-ChildItem $Root -Directory -Filter 'app-claude*') {
    if ($d.Name -notmatch '^app-claude(\d+)$') { continue }
    try {
        $out = & (Join-Path $PSScriptRoot 'build-instance.ps1') -Number ([int]$Matches[1]) 3>&1
        if ("$out" -notmatch 'Up to date') { Add-Content $log "$(Get-Date -Format 's') $($d.Name): $out" }
    } catch { Add-Content $log "$(Get-Date -Format 's') $($d.Name) FAILED: $($_.Exception.Message)" }
}
if ((Test-Path $log) -and (Get-Item $log).Length -gt 256KB) { Remove-Item $log }
