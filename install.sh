#!/bin/bash
# Multiple-Claude for macOS: installs Claude 2, Claude 3 (optionally up to Claude 10) and builds
# /Applications/Claude <N>.app.
#   Needs: an Apple silicon Mac with the original Claude in /Applications. A running app cannot be rebuilt:
#   quit it (Cmd+Q) and run again; the other apps and the shared parts still install.
#   Run: bash install.sh        -> builds Claude 2 and Claude 3
#        bash install.sh 3      -> builds only Claude 3 (bash install.sh 2 -> only Claude 2)
#        bash install.sh 4 5 6  -> builds Claude 4, 5, 6 (own icons for Claude 2 to Claude 10)
# Also installs, shared by every app:
#   - Claude Link Router (~/Applications): owns claude:// links and hands them to the Claude app used last, so
#     MCP sign-ins (GitLab, Figma...), magic links... return to the app that started them. Without it links go
#     to whichever app launched last.
#   - Claude Code session sync across apps (restore-cc-sessions.py, terminal sessions included): runs when each
#     clone opens and every 60 seconds. Needs Command Line Tools (xcode-select --install).
# When Claude updates later, the apps rebuild themselves; no need to run this again.
set -euo pipefail
cd "$(dirname "$0")"
[ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ] || { echo "Apple silicon Macs only." >&2; exit 1; }
[ -d /Applications/Claude.app ] || { echo "/Applications/Claude.app not found; install Claude first, then run again." >&2; exit 1; }
xattr -cr .   # drop the quarantine flag from files received via AirDrop/download
H="$HOME/.claude-instances"
B="$HOME/.claude/bin"
mkdir -p "$H" "$B" "$HOME/Library/LaunchAgents"
cp assets/macos/claude*.car assets/macos/claude*.icns "$H/"
# install deletes the target before copying, so it never writes through a symlink. An older version of this
# file used cp and overwrote ~/.claude/bin/share-cc-sessions.sh with the old share-sessions.sh through the
# symlink ~/.claude/share-sessions.sh.
install -m 755 macos/build-claude2.sh macos/claude-url-router.sh "$H/"
install -m 755 macos/share-cc-sessions.sh shared/restore-cc-sessions.py "$B/"
ln -sfn bin/share-cc-sessions.sh "$HOME/.claude/share-sessions.sh"   # path the clone launchers call
"$H/claude-url-router.sh" --install

A="$HOME/Library/LaunchAgents/com.lamnguyen.claude-session-sync.plist"
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Skipping session sync: Command Line Tools are not installed. Install with: xcode-select --install, then run this again."
elif [ ! -f "$A" ]; then   # keep an existing one (it may carry custom WatchPaths)
  cat >"$A" <<EOP
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key><string>com.lamnguyen.claude-session-sync</string>
	<key>ProcessType</key><string>Background</string>
	<key>ProgramArguments</key><array><string>/usr/bin/python3</string><string>$B/restore-cc-sessions.py</string></array>
	<key>RunAtLoad</key><true/>
	<key>StartInterval</key><integer>60</integer>
	<key>StandardOutPath</key><string>$HOME/Library/Logs/claude-session-sync.log</string>
	<key>StandardErrorPath</key><string>$HOME/Library/Logs/claude-session-sync.log</string>
</dict>
</plist>
EOP
  launchctl bootstrap "gui/$(id -u)" "$A"
fi

[ $# -gt 0 ] || set -- 2 3
fail=0
for n; do "$H/build-claude2.sh" "/Applications/Claude $n.app" || fail=1; done
exit $fail
