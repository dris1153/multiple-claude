# Multiple-Claude

[English](../../README.md) | **简体中文** | [Tiếng Việt](../vi/README.md) | [한국어](../ko/README.md)

> 本文译自英文版。如有出入，以[英文版](../../README.md)为准。

在 **macOS** 和 **Windows** 上同时运行多个 Claude Desktop 应用，每个应用登录各自的账号。

> 非官方社区工具，与 Anthropic 无关，也未获 Anthropic 认可。参见[免责声明](#免责声明)。

## 功能

- **在原版应用旁运行 Claude 2、3……**，每个实例拥有独立的登录、设置和数据。
- **每个实例有自己的颜色**，显示在 Dock / 任务栏 / 开始菜单中（Claude 2 到 10 有预设颜色）。
- **共享 Claude Code 会话**：在一个应用（或终端 CLI）中启动的 Code 会话会出现在所有应用中。
- **`claude://` 链接回到正确的应用**：MCP 登录（GitHub、Figma……）和 magic link 会回到你正在使用的实例，而不是最后启动的那个应用。
- **跟随 Claude 更新**：Claude 更新后，实例会自动重建。

## 系统要求

| | macOS | Windows |
| --- | --- | --- |
| 系统 | Apple 芯片 Mac | Windows 10 / 11，x64 |
| Claude | `/Applications` 中的 `Claude.app` | Microsoft Store 版 Claude Desktop（MSIX） |
| 会话同步（可选） | Command Line Tools：`xcode-select --install` | Python 3：`winget install Python.Python.3.12` |
| 每个实例占用磁盘 | 几乎为零（APFS 克隆） | 约 730 MB（完整应用副本） |

## 快速开始

### macOS

```bash
git clone https://github.com/dris1153/multiple-claude.git
cd multiple-claude
bash install.sh          # builds Claude 2 and Claude 3
bash install.sh 4 5      # more instances
```

在 `/Applications` 或启动台（Launchpad）中打开 **Claude 2** 并登录。

### Windows

```powershell
git clone https://github.com/dris1153/multiple-claude.git
cd multiple-claude
.\install.cmd            # or double-click install.cmd; builds Claude 2 and Claude 3
.\install.cmd 4 5        # more instances
```

只需手动操作一次：安装程序会打开 **Settings > Apps > Default apps**（设置 > 应用 > 默认应用）。滚动到 **Choose default apps by protocol**（按协议指定默认应用），找到 **CLAUDE**，选择 **Claude Link Router**。Windows 只允许你本人做这个选择，脚本无法代劳。

在开始菜单中打开 **Claude 2** 并登录。

## 使用

- **添加实例**：带上想要的编号再次运行安装程序（2 到 99；2 到 10 有专属颜色）。
- **可以放心重复运行**。在 Windows 上，除非 Claude 版本变化，否则不会重建任何内容。在 macOS 上，命令中指定的应用每次都会重建（快速 APFS 克隆并重新签名；没有 Apple Development 证书时，macOS 可能会再次请求钥匙串访问权限）。正在运行的实例会被跳过，请先退出它（macOS：Cmd+Q；Windows：右键点击托盘图标 > Quit）再重新运行。
- **Claude 更新**：在 macOS 上，实例会在下次打开时自动重建；在 Windows 上，后台任务会重建未在运行的实例（登录时以及每 30 分钟一次）。
- **Windows**：关闭窗口后 Claude 仍在托盘中运行。要停止它，请从托盘图标退出。

文件位置：

| | macOS | Windows |
| --- | --- | --- |
| 实例应用 | `/Applications/Claude <N>.app` | `%USERPROFILE%\.claude-instances\app-claude<N>` + 开始菜单快捷方式 |
| 实例数据和登录信息 | `~/.claude-instances/claude<N>` | `%USERPROFILE%\.claude-instances\claude<N>` |
| 链接路由器 | `~/Applications/Claude Link Router.app` | `%USERPROFILE%\.claude-instances\claude-link-router.exe` |
| 日志 | `~/Library/Logs/claude-url-router.log`、`claude-session-sync.log` | `%LOCALAPPDATA%\claude-link-router.log`、`%USERPROFILE%\.claude-instances\refresh.log` |

## 卸载

除非你选择清除（`--purge` / `-Purge`），否则登录信息和实例数据都会保留。原版 Claude 应用永远不会被改动。

```bash
bash uninstall.sh            # macOS; add --purge to also delete instance data (not yet tested on a real Mac)
```

```powershell
powershell -ExecutionPolicy Bypass -File uninstall.ps1      # Windows; add -Purge to also delete instance data
```

在 Windows 上，如果 Claude Link Router 曾是 CLAUDE 链接的默认应用，请在同一个设置页面中重新选择 **Claude**。

## 局限

- **链接路由靠窗口顺序猜测**：最后使用的 Claude 窗口会收到链接。如果你在 Claude 2 中开始登录，完成前又点击了 Claude 3，回调会交给 Claude 3。在 Windows 上，隐藏在托盘中的实例不在考虑范围内。
- **Windows 实例是 Store 应用的非打包副本**，因为 Windows 对 Store 应用总是显示包图标。依赖 Store 包的功能（例如 Cowork）在实例中未经测试；原版应用保留这些功能。
- **Windows**：第三方模式下的 Claude（`Claude-3p`）不在会话同步范围内。
- **Windows**：资源管理器右键菜单中的 "Claude Code" 项属于最后启动的那个 Claude，通过它打开的实例启动时不会使用自己的配置文件。建议从应用内部打开文件夹。
- **macOS**：卸载程序尚未在真实的 Mac 上运行过。使用前请先阅读其内容。

## 工作原理

各系统上的设计、每个组件存在的原因以及故障排查，请参见 [docs/how-it-works.md](docs/how-it-works.md)。

## 项目结构

```
install.sh / uninstall.sh          macOS 入口
install.cmd / install.ps1          Windows 入口
uninstall.ps1
assets/        spark.png、palette.json（实例颜色）、macos/ 预构建的 Mac 图标
shared/        restore-cc-sessions.py（会话同步，两个系统通用）
macos/         克隆构建器、链接路由器、会话同步钩子
windows/       配置、应用副本构建器、图标工具、链接路由器（C#）、刷新任务脚本
docs/          how-it-works.md
languages/     README 和文档的译本（zh-CN、vi、ko）
```

## 开发

```bash
python3 shared/restore-cc-sessions.py --selftest     # Windows: python shared\restore-cc-sessions.py --selftest
```

CI（`.github/workflows/ci.yml`）会在 macOS 和 Windows 上运行自检，用 `bash -n` 和 ShellCheck 检查所有 shell 脚本，解析所有 PowerShell 脚本，编译链接路由器并构建图标。

## 致谢

- 最初的 macOS 工具包由 **lamnguyen** 编写。
- Windows 移植和打包：Multiple-Claude 贡献者。

## 免责声明

Multiple-Claude 与 Anthropic 无关，未获 Anthropic 认可或支持。"Claude" 和 Claude 标志是 Anthropic 的商标；spark 图案仅用于区分各个实例。本工具只在你自己的电脑上复制并重新签名（macOS）或复制并更换图标（Windows）Claude 应用，从不重新分发它。使用风险自负；Claude 的某次更新可能导致本工具失效。

## 许可证

[MIT](../../LICENSE)
