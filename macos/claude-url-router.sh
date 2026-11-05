#!/bin/sh
# macOS lets only one app own claude:// links, yet Claude.app, Claude 2, Claude 3 all declare the scheme and
# whichever launches last grabs it. MCP sign-in callbacks (claude://claude.ai/mcp-auth-callback/sdk), magic
# links... therefore land in the app owning the link, not in the app that started the sign-in.
# The applet ~/Applications/Claude Link Router.app owns claude:// and calls this script:
#   claude-url-router.sh URL  -> hands the URL to the topmost Claude app on screen (used most recently),
#                                or to the original Claude.app when no Claude app is visible.
#   claude-url-router.sh      -> (LaunchAgent com.lamnguyen.claude-url-router, whenever LaunchServices changes
#                                handlers) takes claude:// back for the applet if a Claude app that just launched grabbed it.
#   claude-url-router.sh --install -> builds the applet + LaunchAgent (safe to re-run).
ROUTER="$HOME/Applications/Claude Link Router.app"
LOG="$HOME/Library/Logs/claude-url-router.log"

if [ "$1" = --install ]; then
  set -e
  rm -rf "$ROUTER"
  mkdir -p "$(dirname "$ROUTER")" "$HOME/Library/LaunchAgents"   # a new account has neither folder yet
  osacompile -o "$ROUTER" -e 'on open location u' \
    -e 'do shell script quoted form of (POSIX path of (path to home folder) & ".claude-instances/claude-url-router.sh") & " " & quoted form of u' \
    -e 'end open location'
  PL="$ROUTER/Contents/Info.plist"
  plutil -replace CFBundleIdentifier -string local.claude-link-router "$PL"
  plutil -replace LSUIElement -bool true "$PL"   # no Dock icon every time a link passes through
  plutil -replace CFBundleURLTypes -json '[{"CFBundleURLName":"Claude","CFBundleURLSchemes":["claude"]}]' "$PL"
  codesign --force --sign - "$ROUTER"
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$ROUTER"
  A="$HOME/Library/LaunchAgents/com.lamnguyen.claude-url-router.plist"
  launchctl bootout "gui/$(id -u)" "$A" 2>/dev/null || true
  cat >"$A" <<EOP
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key><string>com.lamnguyen.claude-url-router</string>
	<key>ProcessType</key><string>Background</string>
	<key>ProgramArguments</key><array><string>$HOME/.claude-instances/claude-url-router.sh</string></array>
	<key>RunAtLoad</key><true/>
	<key>WatchPaths</key><array><string>$HOME/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist</string></array>
	<key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
EOP
  launchctl bootstrap "gui/$(id -u)" "$A"
  echo "Done: $ROUTER + $A"
  exit 0
fi

if [ -z "$1" ]; then
  cur=$(osascript -l JavaScript -e 'ObjC.import("AppKit"); $.NSWorkspace.sharedWorkspace.URLForApplicationToOpenURL($.NSURL.URLWithString("claude://x")).path.js' 2>/dev/null)
  [ "$cur" = "$ROUTER" ] && exit 0
  osascript -l JavaScript -e 'ObjC.import("CoreServices"); $.LSSetDefaultHandlerForURLScheme($("claude"), $("local.claude-link-router"))' >/dev/null
  echo "$(date '+%F %T') took claude:// back from ${cur:-?}" >>"$LOG"
  exit 0
fi

# visibleProcessList lists apps top to bottom in window order.
target=com.anthropic.claudefordesktop
for asn in $(lsappinfo visibleProcessList | grep -oE 'ASN:0x[0-9a-f]+-0x[0-9a-f]+'); do
  id=$(lsappinfo info -only bundleid "$asn" | sed -nE 's/.*="(.*)"/\1/p')
  case "$id" in com.anthropic.claudefordesktop|local.claude-desktop-*) target=$id; break ;; esac
done
# Guess by the app used last: start a sign-in in app A, switch to app B before approving, and the link goes to B.
echo "$(date '+%F %T') ${1%%[?#]*} -> $target" >>"$LOG"   # strip query/fragment: they carry OAuth code/state, magic-link tokens
exec open -b "$target" "$1"
