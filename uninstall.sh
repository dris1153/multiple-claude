#!/bin/bash
# Multiple-Claude for macOS: removes what install.sh added (Claude <N>.app clones, Claude Link Router, the two
# LaunchAgents, kit files). Sign-ins and instance data in ~/.claude-instances/claude<N> are kept unless --purge.
# Not yet tested on a real Mac: read it before running.
#   Run: bash uninstall.sh [--purge]
set -uo pipefail
PURGE=0; [ "${1:-}" = --purge ] && PURGE=1
H="$HOME/.claude-instances"
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

if pgrep -f '/Applications/Claude [^/]+\.app/Contents/MacOS/Claude( |$)' >/dev/null; then
  echo "A Claude clone is running; quit it (Cmd+Q) and run again." >&2
  exit 1
fi

# Agents first: the router agent takes claude:// back as soon as the handler changes.
for label in com.lamnguyen.claude-url-router com.lamnguyen.claude-session-sync; do
  A="$HOME/Library/LaunchAgents/$label.plist"
  launchctl bootout "gui/$(id -u)" "$A" 2>/dev/null || true
  rm -f "$A"
done

for app in /Applications/Claude\ *.app; do
  [ -d "$app" ] || continue
  id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist" 2>/dev/null)
  case "$id" in
    local.claude-desktop-*) "$LSREG" -u "$app" 2>/dev/null; rm -rf "$app"; echo "Removed $app" ;;
  esac
done

ROUTER="$HOME/Applications/Claude Link Router.app"
if [ -d "$ROUTER" ]; then "$LSREG" -u "$ROUTER" 2>/dev/null; rm -rf "$ROUTER"; fi
osascript -l JavaScript -e 'ObjC.import("CoreServices"); $.LSSetDefaultHandlerForURLScheme($("claude"), $("com.anthropic.claudefordesktop"))' >/dev/null 2>&1 || true

# Undo the clone launchers' delete lock on the Claude in Chrome manifest.
M="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.anthropic.claude_browser_extension.json"
if [ -f "$M" ]; then chmod -a "everyone deny delete" "$M" 2>/dev/null || true; fi

# Updater blockers left by build-claude2.sh (plain files in place of the ShipIt folders).
for b in "$HOME"/Library/Caches/local.claude-desktop-*.ShipIt; do
  if [ -f "$b" ]; then rm -f "$b"; fi
done

rm -f "$H"/build-claude2.sh "$H"/claude-url-router.sh "$H"/build-claude2.log "$H"/claude*.car "$H"/claude*.icns
rm -rf "$H"/claude*.icon   # copied by older versions of install.sh
if [ -L "$HOME/.claude/share-sessions.sh" ]; then rm -f "$HOME/.claude/share-sessions.sh"; fi
rm -f "$HOME/.claude/bin/share-cc-sessions.sh" "$HOME/.claude/bin/restore-cc-sessions.py" "$HOME/.claude/.restore-cc-sessions.lock"
rm -f "$HOME/.claude/restore-cc-sessions.log" "$HOME/Library/Logs/claude-url-router.log" "$HOME/Library/Logs/claude-session-sync.log"

if [ "$PURGE" = 1 ]; then
  read -r -p "Delete ALL instance data and sign-ins in $H? [y/N] " ok
  if [ "$ok" = y ] || [ "$ok" = Y ]; then
    rm -rf "$H"
    # State macOS keeps per clone bundle ID.
    rm -rf "$HOME"/Library/Caches/local.claude-desktop-* "$HOME"/Library/Preferences/local.claude-desktop-*.plist \
      "$HOME/Library/Saved Application State"/local.claude-desktop-*.savedState
    echo "Removed $H and clone app state"
  fi
fi
echo "Done. If you added a SessionStart hook that calls share-cc-sessions.sh, remove it from ~/.claude/settings.json."
