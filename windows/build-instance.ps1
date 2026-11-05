# Builds ~\.claude-instances\app-claudeN: an unpackaged copy of the installed Claude app whose exe carries
# claudeN.ico. Outside MSIX the taskbar uses the exe icon, so each instance gets its own colour.
# Rebuilds only when the Claude package version changed; skips instances that are running.
param([Parameter(Mandatory)][ValidateRange(2, 99)][int]$Number)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'config.ps1')

$pkg = Get-AppxPackage -Name Claude | Select-Object -First 1
if (-not $pkg) { throw 'Claude Desktop (MSIX) not found.' }
$dst = Join-Path $Root "app-claude$Number"
$stamp = Join-Path $dst '.package-version'
$ico = Join-Path $IconDir "claude$Number.ico"

if ((Test-Path $stamp) -and ((Get-Content $stamp -Raw).Trim() -eq [string]$pkg.Version)) {
    Write-Output "Up to date: Claude $Number ($($pkg.Version))"; return
}
$running = Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith("$dst\", 'OrdinalIgnoreCase') }
if ($running) { Write-Warning "Claude $Number is running; quit it from the tray icon and run again."; return }

Remove-Item $stamp -ErrorAction SilentlyContinue   # a half-finished build must not look up to date
robocopy (Join-Path $pkg.InstallLocation 'app') $dst /MIR /NFL /NDL /NJH /NJS /NP /R:2 /W:1 | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE)" }
if (Test-Path $ico) {
    & (Join-Path $PSScriptRoot 'set-exe-icon.ps1') -Exe (Join-Path $dst 'claude.exe') -Ico $ico
} else {
    Write-Warning "No icon for Claude $Number; it keeps the original icon."
}
Set-Content $stamp ([string]$pkg.Version)
Write-Output "Built: Claude $Number ($($pkg.Version))"
