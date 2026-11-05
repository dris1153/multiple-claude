#!/usr/bin/env python3
"""Keeps the Claude Code Desktop sidebar complete and shared across every account
and across the original app and the instances running with --user-data-dir in
~/.claude-instances/<name>.

The app stores sidebar metadata in <userData>/claude-code-sessions/<accountId>/<orgId>/
and reads that folder ONLY at startup (or on account/org switch); it does not watch
it. Sessions another app creates/updates afterwards show up only after a restart.

1. sync(): every real org folder of every app ends up with the same local_*.json +
   deleted_* set. Winner: highest lastActivityAt, ties broken by newer mtime. Plain
   mtime is not enough: an open app keeps an old copy in memory and rewrites it on
   every touch (focus...), which would clobber runs/errors the other app just wrote.
   A deleted_<id> tombstone wins unless the session was recreated after deletion.
   Copies drop QUIT_KEYS: the "resume on relaunch" flags belong only to the app that
   just quit; left in place, both apps would resume the same session.
   Leaves alone archived-sessions.idx (app-maintained), scheduled-tasks.json and
   backlog/ (per org; copying a schedule to another app = it runs twice).
   Never symlinks org folders: the app opens them with O_NOFOLLOW -> ENOTDIR.
2. restore(): adds entries for transcripts run from the terminal CLI (the CLI writes
   no metadata). Desktop transcripts are skipped: the app writes their metadata.

Writes metadata only, never transcripts. Idempotent. `--selftest` to check.
Called by: SessionStart hook (share-cc-sessions.sh), macOS instance launchers
(~/.claude/share-sessions.sh), the com.lamnguyen.claude-session-sync LaunchAgent
on macOS and the claude-session-sync Scheduled Task on Windows.
"""
import json, os, glob, datetime, re, sys, tempfile, time, uuid

if sys.platform == "win32":
    import msvcrt
    # Claude 4+: real path outside the MSIX sandbox. Claude-3p (third-party mode) is deliberately excluded.
    ORIGINAL = glob.glob(os.path.join(os.environ.get("LOCALAPPDATA", ""), "Claude-Data", "claude_*",
                                      "claude-code-sessions"))
else:
    import fcntl
    ORIGINAL = [os.path.expanduser("~/Library/Application Support/Claude/claude-code-sessions")]

ROOTS = [*ORIGINAL, *glob.glob(os.path.expanduser("~/.claude-instances/*/claude-code-sessions"))]
PROJ = os.path.expanduser("~/.claude/projects")
LOCK = os.path.expanduser("~/.claude/.restore-cc-sessions.lock")
UUID = re.compile(r"[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}")
QUIT_KEYS = ("interruptedByQuitAt", "interruptedUnseenResume", "cycleClosedAtQuit",
             "remoteControlLiveAtUpdateQuit", "armedWorkAtQuit")


def ms(iso):
    if not iso:
        return None
    try:
        return int(datetime.datetime.fromisoformat(iso.replace("Z", "+00:00")).timestamp() * 1000)
    except Exception:
        return None


def clean_title(s, cwd):
    if s:
        s = re.sub(r"\s+", " ", s).strip()
        s = re.sub(r"^(Caveat:|<[^>]+>)\s*", "", s).strip()
        if len(s) > 60:
            s = s[:60].rsplit(" ", 1)[0] + "…"
        if s:
            return s
    return os.path.basename(cwd or "session") or "session"


def org_dirs(roots):
    """<root>/<accountId>/<orgId>; skips _shared, backlog... (names that are not UUIDs)."""
    return sorted(d for r in roots for d in glob.glob(os.path.join(r, "*", "*"))
                  if os.path.isdir(d) and all(UUID.fullmatch(p) for p in d.split(os.sep)[-2:]))


def load(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return None


def write(dst, text, mtime_ns):
    """Atomic write like the app (tmp + rename), keeping the source mtime."""
    tmp = os.path.join(os.path.dirname(dst), "." + os.path.basename(dst) + ".sync")
    with open(tmp, "w", encoding="utf-8", newline="") as fh:
        fh.write(text)
    os.chmod(tmp, 0o600)
    os.utime(tmp, ns=(mtime_ns, mtime_ns))
    try:
        os.replace(tmp, dst)
    except PermissionError:  # Windows: the app holds dst open; next run retries
        remove(tmp)


def remove(path):
    try:
        os.remove(path)
    except (FileNotFoundError, PermissionError):  # PermissionError: Windows, file held open
        pass


def lock_exclusive(fh):
    if sys.platform == "win32":
        msvcrt.locking(fh.fileno(), msvcrt.LK_LOCK, 1)
    else:
        fcntl.flock(fh, fcntl.LOCK_EX)


def sync(dirs):
    """Returns the ids already owned (cliSessionId of live sessions + tombstone ids)."""
    files = {}  # file name -> [(path, stat)]
    for d in dirs:
        for f in os.listdir(d):
            if f.startswith("deleted_") or (f.startswith("local_") and f.endswith(".json")):
                p = os.path.join(d, f)
                try:
                    files.setdefault(f, []).append((p, os.stat(p)))
                except (FileNotFoundError, PermissionError):  # app just deleted/renamed it (Windows: PermissionError)
                    pass

    def tomb_ms(p, st):  # the app writes Date.now() into the tombstone
        try:
            with open(p) as fh:
                return int(fh.read().strip())
        except (OSError, ValueError):
            return int(st.st_mtime * 1000)

    tombs = {f[len("deleted_"):]: max(tomb_ms(p, st) for p, st in v)
             for f, v in files.items() if f.startswith("deleted_")}
    claimed = set(tombs)

    for f, copies in files.items():
        if not f.startswith("local_"):
            continue
        sid = f[len("local_"):-len(".json")]
        identical = len({(st.st_mtime_ns, st.st_size) for _, st in copies}) == 1
        vers = [(load(p), st) for p, st in (copies[:1] if identical else copies)]
        vers = [(rec, st) for rec, st in vers if isinstance(rec, dict)]
        if not vers:
            continue
        rec, st = max(vers, key=lambda v: (v[0].get("lastActivityAt") or 0, v[1].st_mtime_ns))

        if sid in tombs:
            if (rec.get("createdAt") or 0) <= tombs[sid]:  # deleted in the app but a copy is left over
                for p, _ in copies:
                    remove(p)
                continue
            for p, _ in files["deleted_" + sid]:  # recreated after deletion (re-imported)
                remove(p)
            del tombs[sid]
        claimed.add(rec.get("cliSessionId"))

        have = {os.path.dirname(p): s.st_mtime_ns for p, s in copies}
        text = None
        for d in dirs:
            if have.get(d) == st.st_mtime_ns:
                continue
            if text is None:
                text = json.dumps({k: v for k, v in rec.items() if k not in QUIT_KEYS},
                                  ensure_ascii=False, separators=(",", ":"))
            write(os.path.join(d, f), text, st.st_mtime_ns)

    for sid, when in tombs.items():
        have = {os.path.dirname(p) for p, _ in files["deleted_" + sid]}
        for d in dirs:
            if d not in have:
                write(os.path.join(d, "deleted_" + sid), str(when), when * 1_000_000)
    return claimed


def restore(dirs, proj, skip):
    made, now_ns = 0, time.time_ns()
    for path in glob.glob(os.path.join(proj, "*", "*.jsonl")):
        uid = os.path.basename(path)[:-6]
        if uid in skip:
            continue
        cwd = model = first_user = t0 = t1 = entrypoint = None
        turns = 0
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        e = json.loads(line)
                    except Exception:
                        continue
                    if e.get("isSidechain"):
                        continue
                    entrypoint = entrypoint or e.get("entrypoint")
                    cwd = e.get("cwd") or cwd
                    t = e.get("timestamp")
                    if t:
                        t0 = t0 or t
                        t1 = t
                    if e.get("type") == "assistant":
                        model = (e.get("message") or {}).get("model") or model
                    if e.get("type") == "user" and not e.get("isMeta"):
                        c = (e.get("message") or {}).get("content")
                        if isinstance(c, list):
                            if any(isinstance(x, dict) and x.get("type") == "tool_result" for x in c):
                                continue
                            c = " ".join(x.get("text", "") for x in c if isinstance(x, dict))
                        if isinstance(c, str) and c.strip():
                            turns += 1
                            if first_user is None and not c.lstrip().startswith("<"):
                                first_user = c
        except Exception:
            continue
        if turns == 0 or entrypoint == "claude-desktop":
            continue

        sid = "local_" + uid
        last = ms(t1)
        rec = {
            "sessionId": sid,
            "cliSessionId": uid,
            "cwd": cwd or os.path.expanduser("~"),
            "originCwd": cwd or os.path.expanduser("~"),
            "lastFocusedAt": last,
            "createdAt": ms(t0),
            "lastActivityAt": last,
            "model": model or "claude-opus-5",
            "effort": "max",
            "isArchived": False,
            "title": clean_title(first_user, cwd),
            "titleSource": "auto",
            "permissionMode": "auto",
            "remoteMcpServersConfig": [],
            "alwaysAllowedReasons": [],
            "sessionPermissionUpdates": [],
            "classifierSummaryEnabled": True,
            "reportFindingsCard": True,
            "spawnSeed": {},
            "completedTurns": turns,
        }
        text = json.dumps(rec, ensure_ascii=False, separators=(",", ":"))
        for d in dirs:  # same mtime everywhere, so the next sync does not copy it again
            write(os.path.join(d, sid + ".json"), text, now_ns)
        made += 1
    return made


def main(roots=ROOTS, proj=PROJ, lock=LOCK):
    dirs = org_dirs(roots)
    if not dirs:
        return
    os.makedirs(os.path.dirname(lock), exist_ok=True)
    with open(lock, "w") as fh:  # hook, launcher and background job can run at the same time
        try:
            lock_exclusive(fh)
        except OSError:  # Windows LK_LOCK gives up after ~10s; the next run catches up
            return
        made = restore(dirs, proj, sync(dirs))
    if made:
        print(f"restore-cc-sessions: restored {made} sidebar entries")


def selftest():
    t = tempfile.mkdtemp()
    U = lambda: str(uuid.uuid4())
    app1, app2, proj = os.path.join(t, "a"), os.path.join(t, "b"), os.path.join(t, "p")
    a1, a2, b1 = (os.path.join(app1, U(), U()), os.path.join(app1, U(), U()), os.path.join(app2, U(), U()))
    dirs = (a1, a2, b1)
    for d in dirs:
        os.makedirs(os.path.join(d, "backlog"))
    junk = os.path.join(app1, "_shared", "backlog")
    os.makedirs(junk)

    def w(p, obj, mtime):
        with open(p, "w") as fh:
            fh.write(obj if isinstance(obj, str) else json.dumps(obj))
        os.utime(p, (mtime, mtime))

    # a: app1 ran on (lastActivityAt 50) but app2 kept an old copy in memory and wrote it later (newer mtime)
    w(os.path.join(a1, "local_a.json"), {"cliSessionId": "ca", "title": "new", "lastActivityAt": 50}, 100)
    w(os.path.join(b1, "local_a.json"), {"cliSessionId": "ca", "title": "old", "lastActivityAt": 10}, 200)
    # b: only app2 has it, interrupted when app2 quit
    w(os.path.join(b1, "local_b.json"), {"cliSessionId": "cb", "lastActivityAt": 5, "interruptedByQuitAt": 7}, 100)
    # dead: deleted in app1 (tombstone 2000 ms) but app2 still has the old copy
    w(os.path.join(a2, "deleted_dead"), "2000", 2)
    w(os.path.join(b1, "local_dead.json"), {"cliSessionId": "cd", "createdAt": 1000}, 300)
    # reborn: deleted then re-imported (createdAt after the deletion)
    w(os.path.join(b1, "deleted_reborn"), "2000", 2)
    w(os.path.join(a1, "local_reborn.json"), {"cliSessionId": "cr", "createdAt": 3000}, 5)
    for f in ("archived-sessions.idx", "scheduled-tasks.json"):
        w(os.path.join(a1, f), "private", 400)
    w(os.path.join(a1, "backlog", "tasks.json"), "private", 400)
    pd = os.path.join(proj, "-x")
    os.makedirs(pd)
    line = lambda ep: json.dumps({"type": "user", "entrypoint": ep, "cwd": "/x",
                                  "timestamp": "2026-01-01T00:00:00Z", "message": {"content": "hi"}})
    w(os.path.join(pd, "desk.jsonl"), line("claude-desktop") + "\n", 1)
    w(os.path.join(pd, "term.jsonl"), line("cli") + "\n", 1)
    w(os.path.join(pd, "ca.jsonl"), line("cli") + "\n", 1)  # already owned (local_a)

    lock = os.path.join(t, "lock")
    main((app1, app2), proj, lock)
    snap = {p: os.stat(p).st_mtime_ns for d in dirs for p in glob.glob(os.path.join(d, "*"))}
    main((app1, app2), proj, lock)  # a second run must change nothing
    assert snap == {p: os.stat(p).st_mtime_ns for d in dirs for p in glob.glob(os.path.join(d, "*"))}

    rd = lambda d, f: json.load(open(os.path.join(d, f)))
    for d in dirs:
        assert rd(d, "local_a.json")["title"] == "new"
        assert not os.path.exists(os.path.join(d, "local_dead.json"))
        assert os.path.exists(os.path.join(d, "deleted_dead"))
        assert rd(d, "local_reborn.json")["cliSessionId"] == "cr"
        assert not os.path.exists(os.path.join(d, "deleted_reborn"))
        assert rd(d, "local_term.json")["cliSessionId"] == "term"
        assert not os.path.exists(os.path.join(d, "local_desk.json"))
        assert not os.path.exists(os.path.join(d, "local_ca.json"))
        assert not glob.glob(os.path.join(d, ".*"))
    assert rd(b1, "local_b.json")["interruptedByQuitAt"] == 7  # the quitting app's own copy keeps the flag
    assert "interruptedByQuitAt" not in rd(a1, "local_b.json")  # copies do not
    for d in (a2, b1):
        for f in ("archived-sessions.idx", "scheduled-tasks.json", "backlog/tasks.json"):
            assert not os.path.exists(os.path.join(d, f))
    assert os.listdir(junk) == []
    import shutil
    shutil.rmtree(t)
    print("selftest OK")


def run():
    try:
        main()
    except Exception:  # pythonw has no stderr, so a crash would leave no trace
        import traceback
        with open(os.path.expanduser("~/.claude/restore-cc-sessions.log"), "a", encoding="utf-8") as fh:
            fh.write(time.strftime("%Y-%m-%d %H:%M:%S ") + traceback.format_exc())
        raise


if __name__ == "__main__":
    selftest() if "--selftest" in sys.argv else run()
