# Multiple-Claude for Windows: runs Claude 2, 3, ... beside the original Claude Desktop, each with its own
# sign-in and taskbar colour, plus shared Claude Code sessions and claude:// link routing.
# Usage: install.cmd [2 3 ...]   or   powershell -ExecutionPolicy Bypass -File install.ps1 [2 3 ...]   (default: 2 3)
# Safe to re-run. A running instance is skipped: quit it from its tray icon and run again.
param([Parameter(ValueFromRemainingArguments)][ValidateRange(2, 99)][int[]]$Numbers = @(2, 3))
$ErrorActionPreference = 'Stop'
$Win = Join-Path $PSScriptRoot 'windows'
. (Join-Path $Win 'config.ps1')
$Csc = Join-Path $env:windir 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'

function Assert-Prerequisites {
    if (-not (Get-AppxPackage -Name Claude)) { throw 'Claude Desktop (Microsoft Store / MSIX) not found. Install Claude first.' }
    if (-not (Test-Path $Csc)) { throw '.NET Framework 4 compiler (csc.exe) not found.' }
}

function Find-Pythonw {
    $found = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python3*\pythonw.exe') -ErrorAction SilentlyContinue |
        Sort-Object { [int]($_.Directory.Name -replace '\D', '') } -Descending | Select-Object -First 1
    if ($found) { return $found.FullName }
    # Skip the Microsoft Store stub in WindowsApps: it opens the Store instead of running Python.
    $cmd = Get-Command pythonw.exe -All -ErrorAction SilentlyContinue | Where-Object { $_.Source -notlike '*\WindowsApps\*' } | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    return $null
}

function Register-HiddenTask([string]$Name, [string]$Execute, [string]$Argument, [int]$EveryMinutes, [int]$LimitMinutes) {
    $action = New-ScheduledTaskAction -Execute $Execute -Argument $Argument
    $triggers = @((New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME),
        (New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes) -RepetitionDuration (New-TimeSpan -Days 3650)))
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes $LimitMinutes)
    Register-ScheduledTask -TaskName $Name -Action $action -Trigger $triggers -Settings $settings -Force | Out-Null
}

function Install-Instances {
    New-Item -ItemType Directory -Force $Root | Out-Null
    foreach ($f in $RuntimeScripts) { Copy-Item (Join-Path $Win $f) $Root -Force }
    & (Join-Path $Win 'make-icons.ps1') -Numbers $Numbers -Out $IconDir | Out-Null
    $shell = New-Object -ComObject WScript.Shell
    foreach ($n in $Numbers) {
        & (Join-Path $Root 'build-instance.ps1') -Number $n
        $exe = Join-Path $Root "app-claude$n\claude.exe"
        if (-not (Test-Path $exe)) { Write-Warning "Claude $n has no app copy yet, shortcut skipped."; continue }
        $ico = Join-Path $IconDir "claude$n.ico"
        $lnk = $shell.CreateShortcut((Join-Path $StartMenu "Claude $n.lnk"))
        $lnk.TargetPath = $exe
        $lnk.Arguments = "--user-data-dir=`"$(Join-Path $Root "claude$n")`""
        $lnk.WorkingDirectory = $env:USERPROFILE
        $lnk.IconLocation = if (Test-Path $ico) { $ico } else { "$exe,0" }
        $lnk.Save()
        Write-Output "Ready: Claude $n (Start Menu)"
    }
}

function Install-SessionSync {
    $py = Find-Pythonw
    if (-not $py) { Write-Warning 'Python 3 not found: session sync skipped. Install it (winget install Python.Python.3.12) and run this again.'; return }
    New-Item -ItemType Directory -Force $Bin | Out-Null
    $script = Join-Path $Bin 'restore-cc-sessions.py'
    Copy-Item (Join-Path $PSScriptRoot 'shared\restore-cc-sessions.py') $script -Force
    Register-HiddenTask $SyncTask $py "`"$script`"" 1 2
    Write-Output "Ready: session sync (task $SyncTask, $py)"
}

function Install-RefreshTask {
    # Rebuilds app copies after a Claude update; conhost --headless avoids a console flash.
    $arg = "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $Root 'refresh-instances.ps1')`""
    Register-HiddenTask $RefreshTask 'conhost.exe' $arg 30 15
    Write-Output "Ready: rebuild after Claude updates (task $RefreshTask)"
}

function Install-LinkRouter {
    & $Csc /nologo /target:winexe /optimize /r:System.Management.dll "/out:$RouterExe" (Join-Path $Win 'claude-link-router.cs')
    if ($LASTEXITCODE -ne 0) { throw 'Link router build failed.' }
    $cls = "HKCU:\Software\Classes\$RouterProgId"
    New-Item "$cls\shell\open\command" -Force | Out-Null
    Set-ItemProperty $cls -Name '(default)' -Value "URL:$RouterName"
    New-ItemProperty $cls -Name 'URL Protocol' -Value '' -Force | Out-Null
    Set-ItemProperty "$cls\shell\open\command" -Name '(default)' -Value "`"$RouterExe`" `"%1`""
    New-Item "$RouterCapKey\Capabilities\UrlAssociations" -Force | Out-Null
    Set-ItemProperty "$RouterCapKey\Capabilities" -Name ApplicationName -Value $RouterName
    Set-ItemProperty "$RouterCapKey\Capabilities" -Name ApplicationDescription -Value 'Routes claude:// links to the Claude instance in use'
    Set-ItemProperty "$RouterCapKey\Capabilities\UrlAssociations" -Name claude -Value $RouterProgId
    New-Item 'HKCU:\Software\RegisteredApplications' -Force | Out-Null
    Set-ItemProperty 'HKCU:\Software\RegisteredApplications' -Name $RouterName -Value 'Software\ClaudeLinkRouter\Capabilities'
    if ((Get-ItemProperty $UserChoiceKey -ErrorAction SilentlyContinue).ProgId -eq $RouterProgId) {
        Write-Output "Ready: $RouterName (default for claude:// links)"
    } else {
        # Windows protects this choice with a hash, so it can only be made by the user.
        Write-Warning "One manual step: in the Settings window that opens, scroll to 'Choose default apps by protocol', find CLAUDE and pick '$RouterName'."
        Start-Process 'ms-settings:defaultapps'
    }
}

Assert-Prerequisites
Install-Instances
Install-SessionSync
Install-RefreshTask
Install-LinkRouter
Write-Output 'Tip: pin an instance from Start Menu > right-click "Claude N" > More > Pin to taskbar.'
