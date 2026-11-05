# How it works

Claude Desktop is an Electron app. Electron keeps all state (sign-in, settings, caches) in one *user data folder*, and the `--user-data-dir` flag points it elsewhere. Every Multiple-Claude instance is the same Claude app started with its own data folder. The rest of the kit makes each instance feel like a separate app and keeps shared features working.

## macOS

| Piece | Mechanism | Installed at |
|---|---|---|
| Instance app | `macos/build-claude2.sh` clones `/Applications/Claude.app` (APFS clone, no extra space), sets bundle ID `local.claude-desktop-<N>`, display name and icon, swaps the executable for a launcher, removes Anthropic-only entitlements and re-signs (Apple Development certificate if present, else ad hoc). | `/Applications/Claude <N>.app` |
| Launcher | Refuses to open twice on one data folder, rebuilds the clone when `Claude.app` changed version, runs session sync, then `exec`s Claude with `--user-data-dir`. | inside each app |
| Updater block | A file in place of `~/Library/Caches/local.claude-desktop-<N>.ShipIt` stops the clone's own updater (its download would fail signature checks). Clones follow the original app through the launcher instead. | `~/Library/Caches` |
| Link router | AppleScript applet that owns `claude://` and hands each URL to the topmost Claude app (`lsappinfo visibleProcessList`). A LaunchAgent watching the LaunchServices database takes the scheme back whenever a Claude app grabs it at launch. | `~/Applications/Claude Link Router.app`, `~/Library/LaunchAgents/com.lamnguyen.claude-url-router.plist` |
| Session sync | `shared/restore-cc-sessions.py`, run by each launcher and a LaunchAgent every 60 s. | `~/.claude/bin`, `~/Library/LaunchAgents/com.lamnguyen.claude-session-sync.plist` |
| Chrome manifest lock | Clones cannot read Chrome data, think the Claude in Chrome extension is missing and delete its native-messaging manifest. The launcher adds a "deny delete" ACL to that file. | Chrome `NativeMessagingHosts` |

The LaunchAgent labels keep the original `com.lamnguyen.*` names so existing installs keep working.

### Regenerating macOS icons

`assets/macos/claude<N>.car` is compiled from an Icon Composer `.icon` document. To change a colour, edit `assets/palette.json`, then rebuild that icon with Xcode. Create `claude<N>.icon/Assets/spark.png` (copy of `assets/spark.png`) and `claude<N>.icon/icon.json`. In `icon.json`, use the two palette colours as `srgb:` floats (hex / 255) and `sparkScale` as the scale:

```json
{
  "fill": { "linear-gradient": ["srgb:0.34118,0.55686,0.85098,1.00000", "srgb:0.27059,0.51765,0.85882,1.00000"] },
  "groups": [{ "layers": [{ "image-name": "spark.png", "name": "spark", "glass": false,
                            "position": { "scale": 0.95, "translation-in-points": [0, 0] } }],
               "translucency": { "enabled": false, "value": 0.5 } }],
  "supported-platforms": { "squares": ["macOS"] }
}
```

```bash
xcrun actool --compile out --platform macosx --minimum-deployment-target 11.0 --app-icon claude<N> \
  --output-partial-info-plist /dev/null claude<N>.icon   # then copy out/Assets.car to assets/macos/claude<N>.car
```

The matching legacy `claude<N>.icns` is a fallback for older macOS versions.

## Windows

| Piece | Mechanism | Installed at |
|---|---|---|
| Instance app | `windows/build-instance.ps1` copies the Store app folder (`WindowsApps\Claude_*\app`) and patches the icon resources of the copy's `claude.exe` (`set-exe-icon.ps1`, kernel32 `UpdateResource`). A `.package-version` stamp records the source version. | `%USERPROFILE%\.claude-instances\app-claude<N>` |
| Shortcut | Start Menu `Claude <N>.lnk` runs the copy with `--user-data-dir`. | Start Menu |
| Icons | `windows/make-icons.ps1` draws each `.ico` from `assets/palette.json` and `assets/spark.png` (System.Drawing, 16 to 256 px). | `%USERPROFILE%\.claude-instances\icons` |
| Update follow-up | Scheduled Task `claude-instances-refresh` (at sign-in and every 30 min, hidden via `conhost --headless`) rebuilds copies older than the installed Claude, skipping running ones. | Task Scheduler |
| Link router | `windows/claude-link-router.cs`, compiled at install time with the .NET Framework `csc.exe`. It walks top-level windows in z-order, finds the first Claude window, reads its process command line (one WMI query, 3 s timeout) and starts that instance's exe with the URL. Electron's single-instance lock hands the URL to the running instance. | `%USERPROFILE%\.claude-instances\claude-link-router.exe` |
| Session sync | `shared/restore-cc-sessions.py` via `pythonw`, Scheduled Task `claude-session-sync` every minute. | `%USERPROFILE%\.claude\bin` |

### Why copies instead of the Store app

Tested on Windows 10 with Claude 4.x:

- Starting the Store app with `--user-data-dir` works and gives a separate sign-in. But a Store (MSIX) app's taskbar button always shows the package icon; shortcut icons and `WM_SETICON` are ignored. An unpackaged copy uses its exe icon, so each instance gets its colour.
- Copies lose the Store package identity. Sign-in (including Google) was tested on a copy; chat and Claude Code are expected to work but have had little testing; package-bound features such as Cowork are untested.

### Why the router needs a manual Settings step

The Store package registers `claude://` itself, and that registration wins over `HKCU\Software\Classes\claude`. So the router registers as a regular app (`RegisteredApplications` + `Capabilities\UrlAssociations`). The user then picks it under *Default apps > Choose default apps by protocol*. Windows protects that choice with a hash, so a script cannot set it.

## Session sync (both OS)

Claude Desktop keeps Claude Code sidebar metadata in `<data folder>/claude-code-sessions/<account>/<org>/` and reads it only at startup. `restore-cc-sessions.py`:

1. **sync**: gives every org folder of every instance the same `local_*.json` / `deleted_*` set. The newest `lastActivityAt` wins. Tombstones win unless the session was recreated later, and "resume on relaunch" flags are not copied.
2. **restore**: adds sidebar entries for transcripts started from the terminal CLI (`~/.claude/projects`), which write no metadata.

It writes metadata only, never transcripts, and is idempotent. A session created in another instance appears after you restart the app you are looking at. Run `python3 shared/restore-cc-sessions.py --selftest` (Windows: `python ...`) to check it.

On Windows each Claude launch also re-registers its own exe for `claude://` (ignored: the Store registration wins), the Explorer "Claude Code" folder verb and toast activation (`HKCU\Software\Classes\CLSID\...\LocalServer32`). Whichever Claude launched last owns those. `uninstall.ps1` removes the entries that point into `.claude-instances`; the original app writes its own again on next launch.

## Troubleshooting

| Symptom | Check |
|---|---|
| A sign-in or MCP callback opens the wrong app | Router log (`claude-url-router.log` on macOS, `%LOCALAPPDATA%\claude-link-router.log` on Windows). The log only records the URL without query or fragment, and the target. On Windows, make sure CLAUDE is set to Claude Link Router in Default apps. |
| Sessions from another app are missing | Restart the app. Windows: `Get-ScheduledTaskInfo claude-session-sync` (LastTaskResult 0), crash log `%USERPROFILE%\.claude\restore-cc-sessions.log`. macOS: `~/Library/Logs/claude-session-sync.log`. |
| Instance still on an old Claude version (Windows) | Quit it, then run `install.cmd <N>` or wait for `claude-instances-refresh`; see `refresh.log`. |
| "Another Claude window is already using the data" (macOS) | An instance with the same data folder is still running; quit it. |
| Windows says a script cannot be loaded | Use `install.cmd`, or `powershell -ExecutionPolicy Bypass -File ...`. |
