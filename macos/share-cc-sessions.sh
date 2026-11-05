#!/bin/sh
# Every account and every Claude app on this Mac (original + clones in ~/.claude-instances/<name>) shares one
# Claude Code Desktop session store. The app keeps sidebar metadata in
# claude-code-sessions/<accountId>/<orgId>/ and reads it only at startup.
# Called by: each clone's launcher (via the symlink ~/.claude/share-sessions.sh), the LaunchAgent
# com.lamnguyen.claude-session-sync, and a SessionStart hook if you add one.
#
# Do NOT symlink org folders to _shared: the app refuses to write through a symlink (ENOTDIR), new sessions
# live only in memory and are lost on quit/update. Do NOT cp -Rn through a shared store
# claude-code-sessions-shared (the old share-sessions.sh): deleted sessions come back, and per-org
# schedules/backlogs get copied into other orgs. restore-cc-sessions.py copies between the real org folders,
# then adds sidebar entries for sessions run from the terminal CLI. Idempotent.
xcode-select -p >/dev/null 2>&1 || exit 0   # no Command Line Tools: python3 is only a stub that pops an install dialog
python3 "$HOME/.claude/bin/restore-cc-sessions.py" 2>/dev/null || true
