# Multiple-Claude

Run several Claude Desktop apps side by side, each signed in to its own account, on **macOS** and **Windows**.

> Unofficial community tool. Not affiliated with or endorsed by Anthropic. See [Disclaimer](#disclaimer).

## Features

- **Claude 2, 3, … next to the original app**, each with its own sign-in, settings and data.
- **Own colour per instance** in the Dock / taskbar / Start Menu (Claude 2 to 10 have preset colours).
- **Shared Claude Code sessions**: a Code session started in one app (or in the terminal CLI) shows up in all of them.
- **`claude://` links go back to the right app**: MCP sign-ins (GitHub, Figma, …) and magic links return to the instance you were using, not to whichever app launched last.
- **Follows Claude updates**: instances rebuild themselves when Claude updates.

## Requirements

|                         | macOS                                        | Windows                                        |
| ----------------------- | -------------------------------------------- | ---------------------------------------------- |
| System                  | Apple silicon Mac                            | Windows 10 / 11, x64                           |
| Claude                  | `Claude.app` in `/Applications`              | Claude Desktop from the Microsoft Store (MSIX) |
| Session sync (optional) | Command Line Tools: `xcode-select --install` | Python 3: `winget install Python.Python.3.12`  |
| Disk per instance       | almost none (APFS clone)                     | about 730 MB (full app copy)                   |

## Quick start

### macOS

```bash
git clone https://github.com/dris1153/Multiple-Claude.git
cd Multiple-Claude
bash install.sh          # builds Claude 2 and Claude 3
bash install.sh 4 5      # more instances
```

Open **Claude 2** from `/Applications` or Launchpad and sign in.

### Windows

```powershell
git clone https://github.com/dris1153/Multiple-Claude.git
cd Multiple-Claude
.\install.cmd            # or double-click install.cmd; builds Claude 2 and Claude 3
.\install.cmd 4 5        # more instances
```

One manual step, once: the installer opens **Settings > Apps > Default apps**. Scroll to **Choose default apps by protocol**, find **CLAUDE** and pick **Claude Link Router**. Windows only lets you, not a script, make that choice.

Open **Claude 2** from the Start Menu and sign in.

## Usage

- **Add instances**: run the installer again with the numbers you want (2 to 99; 2 to 10 have their own colours).
- **Re-running is safe**. On Windows nothing is rebuilt unless Claude changed version. On macOS the listed apps are rebuilt every time (a quick APFS clone and re-sign; without an Apple Development certificate macOS may ask for keychain access again). A running instance is skipped, so quit it first (macOS: Cmd+Q; Windows: right-click its tray icon > Quit) and run again.
- **Claude updates**: on macOS an instance rebuilds itself the next time you open it; on Windows a background task rebuilds instances that are not running (at sign-in and every 30 minutes).
- **Windows**: closing the window keeps Claude running in the tray. Quit from the tray icon to stop it.

Where things live:

|                           | macOS                                                             | Windows                                                                                |
| ------------------------- | ----------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| Instance apps             | `/Applications/Claude <N>.app`                                    | `%USERPROFILE%\.claude-instances\app-claude<N>` + Start Menu shortcut                  |
| Instance data and sign-in | `~/.claude-instances/claude<N>`                                   | `%USERPROFILE%\.claude-instances\claude<N>`                                            |
| Link router               | `~/Applications/Claude Link Router.app`                           | `%USERPROFILE%\.claude-instances\claude-link-router.exe`                               |
| Logs                      | `~/Library/Logs/claude-url-router.log`, `claude-session-sync.log` | `%LOCALAPPDATA%\claude-link-router.log`, `%USERPROFILE%\.claude-instances\refresh.log` |

## Uninstall

Sign-ins and instance data are kept unless you purge them. The original Claude app is never touched.

```bash
bash uninstall.sh            # macOS; add --purge to also delete instance data (not yet tested on a real Mac)
```

```powershell
powershell -ExecutionPolicy Bypass -File uninstall.ps1      # Windows; add -Purge to also delete instance data
```

On Windows, if Claude Link Router was the default for CLAUDE links, choose **Claude** again in the same Settings page.

## Limitations

- **Link routing guesses** from window order: the Claude window you used last gets the link. If you start a sign-in in Claude 2 and click Claude 3 before finishing it, Claude 3 gets the callback. On Windows an instance hidden in the tray is not considered.
- **Windows instances are unpackaged copies** of the Store app, because Windows always shows the package icon for Store apps. Features tied to the Store package (for example Cowork) are untested in instances; the original app keeps them.
- **Windows**: Claude in third-party mode (`Claude-3p`) is not included in session sync.
- **Windows**: Explorer's right-click "Claude Code" entry belongs to whichever Claude launched last, and an instance opened that way starts without its own profile. Prefer opening folders from inside the app.
- **macOS**: the uninstaller has not been run on a real Mac yet. Read it before using it.

## How it works

See [docs/how-it-works.md](docs/how-it-works.md) for the design on each OS, why each piece exists, and troubleshooting.

## Project layout

```
install.sh / uninstall.sh          macOS entry points
install.cmd / install.ps1          Windows entry points
uninstall.ps1
assets/        spark.png, palette.json (instance colours), macos/ prebuilt Mac icons
shared/        restore-cc-sessions.py (session sync, both OS)
macos/         clone builder, link router, session sync hook
windows/       config, app-copy builder, icon tools, link router (C#), refresh task script
docs/          how-it-works.md
```

## Development

```bash
python3 shared/restore-cc-sessions.py --selftest     # Windows: python shared\restore-cc-sessions.py --selftest
```

CI (`.github/workflows/ci.yml`) runs the self-test on macOS and Windows, checks every shell script with `bash -n` and ShellCheck, parses every PowerShell script, compiles the link router and builds the icons.

## Credits

- The original macOS kit was written by **lamnguyen**.
- Windows port and packaging: Multiple-Claude contributors.

## Disclaimer

Multiple-Claude is not affiliated with, endorsed by or supported by Anthropic. "Claude" and the Claude logo are trademarks of Anthropic; the spark artwork is used only to tell instances apart. The tool copies and re-signs (macOS) or copies and re-icons (Windows) the Claude app on your own machine and never redistributes it. Use it at your own risk; a Claude update may break it.

## License

[MIT](LICENSE)

---

## Tiếng Việt

Multiple-Claude chạy nhiều app Claude Desktop cùng lúc, mỗi app một tài khoản riêng, trên macOS và Windows. Mỗi instance có màu riêng, các app dùng chung session Claude Code, và link `claude://` (đăng nhập MCP, magic link) quay về đúng app bạn đang dùng.

- **macOS**: `bash install.sh` (thêm số để tạo thêm instance, ví dụ `bash install.sh 4 5`).
- **Windows**: bấm đúp `install.cmd`. Làm một lần: trong Settings > Default apps > Choose default apps by protocol, chọn **Claude Link Router** cho CLAUDE.
- **Gỡ**: `bash uninstall.sh` / `uninstall.ps1`. Dữ liệu đăng nhập được giữ lại, trừ khi bạn thêm `--purge` / `-Purge`.
