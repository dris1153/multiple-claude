# 工作原理

[English](../../../docs/how-it-works.md) | **简体中文** | [Tiếng Việt](../../vi/docs/how-it-works.md) | [한국어](../../ko/docs/how-it-works.md)

> 本文译自英文版。如有出入，以[英文版](../../../docs/how-it-works.md)为准。

Claude Desktop 是一个 Electron 应用。Electron 把所有状态（登录、设置、缓存）保存在一个*用户数据文件夹*中，`--user-data-dir` 参数可以把它指向别的位置。每个 Multiple-Claude 实例都是同一个 Claude 应用，只是用各自的数据文件夹启动。工具包的其余部分让每个实例看起来像独立的应用，并让共享功能继续正常工作。

## macOS

| 组件 | 机制 | 安装位置 |
|---|---|---|
| 实例应用 | `macos/build-claude2.sh` 克隆 `/Applications/Claude.app`（APFS 克隆，不占额外空间），设置 bundle ID `local.claude-desktop-<N>`、显示名称和图标，把可执行文件换成启动器，移除仅供 Anthropic 使用的 entitlements 并重新签名（有 Apple Development 证书时用证书，否则 ad hoc 签名）。 | `/Applications/Claude <N>.app` |
| 启动器 | 拒绝在同一个数据文件夹上重复打开；`Claude.app` 版本变化时重建克隆；运行会话同步；然后用 `--user-data-dir` `exec` 启动 Claude。 | 每个应用内部 |
| 更新阻断 | 在 `~/Library/Caches/local.claude-desktop-<N>.ShipIt` 的位置放一个文件，阻止克隆自带的更新程序（它下载的更新会通不过签名校验）。克隆改为通过启动器跟随原版应用。 | `~/Library/Caches` |
| 链接路由器 | 一个 AppleScript 小程序，接管 `claude://` 并把每个 URL 交给最前面的 Claude 应用（`lsappinfo visibleProcessList`）。一个监视 LaunchServices 数据库的 LaunchAgent 会在任何 Claude 应用启动时抢走该协议后把它夺回来。 | `~/Applications/Claude Link Router.app`、`~/Library/LaunchAgents/com.lamnguyen.claude-url-router.plist` |
| 会话同步 | `shared/restore-cc-sessions.py`，由每个启动器以及一个每 60 秒运行一次的 LaunchAgent 执行。 | `~/.claude/bin`、`~/Library/LaunchAgents/com.lamnguyen.claude-session-sync.plist` |
| Chrome manifest 锁 | 克隆无法读取 Chrome 数据，会误以为 Claude in Chrome 扩展不存在并删除它的 native-messaging manifest。启动器给该文件加上 "deny delete" ACL。 | Chrome `NativeMessagingHosts` |

LaunchAgent 标签沿用原来的 `com.lamnguyen.*` 名称，以便已有的安装继续工作。

### 重新生成 macOS 图标

`assets/macos/claude<N>.car` 由 Icon Composer 的 `.icon` 文档编译而来。要修改颜色，先编辑 `assets/palette.json`，再用 Xcode 重建该图标。创建 `claude<N>.icon/Assets/spark.png`（`assets/spark.png` 的副本）和 `claude<N>.icon/icon.json`。在 `icon.json` 中，把两个调色板颜色写成 `srgb:` 浮点数（hex / 255），并把 `sparkScale` 用作 scale：

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

对应的旧式 `claude<N>.icns` 是给旧版 macOS 的后备。

## Windows

| 组件 | 机制 | 安装位置 |
|---|---|---|
| 实例应用 | `windows/build-instance.ps1` 复制 Store 应用文件夹（`WindowsApps\Claude_*\app`），并修补副本中 `claude.exe` 的图标资源（`set-exe-icon.ps1`，kernel32 `UpdateResource`）。`.package-version` 标记文件记录来源版本。 | `%USERPROFILE%\.claude-instances\app-claude<N>` |
| 快捷方式 | 开始菜单中的 `Claude <N>.lnk` 用 `--user-data-dir` 运行副本。 | 开始菜单 |
| 图标 | `windows/make-icons.ps1` 根据 `assets/palette.json` 和 `assets/spark.png` 绘制每个 `.ico`（System.Drawing，16 到 256 px）。 | `%USERPROFILE%\.claude-instances\icons` |
| 更新跟进 | 计划任务 `claude-instances-refresh`（登录时以及每 30 分钟一次，通过 `conhost --headless` 隐藏运行）重建比已安装 Claude 旧的副本，跳过正在运行的副本。 | Task Scheduler（任务计划程序） |
| 链接路由器 | `windows/claude-link-router.cs`，安装时用 .NET Framework 的 `csc.exe` 编译。它按 z-order 遍历顶层窗口，找到第一个 Claude 窗口，读取其进程命令行（一次 WMI 查询，3 秒超时），再带上 URL 启动该实例的 exe。Electron 的单实例锁会把 URL 交给正在运行的实例。 | `%USERPROFILE%\.claude-instances\claude-link-router.exe` |
| 会话同步 | `shared/restore-cc-sessions.py` 通过 `pythonw` 运行，计划任务 `claude-session-sync` 每分钟一次。 | `%USERPROFILE%\.claude\bin` |

### 为什么用副本而不是 Store 应用

在 Windows 10 + Claude 4.x 上测试：

- 用 `--user-data-dir` 启动 Store 应用可行，并且能单独登录。但 Store（MSIX）应用的任务栏按钮总是显示包图标；快捷方式图标和 `WM_SETICON` 都会被忽略。非打包副本使用自己 exe 的图标，所以每个实例都能有自己的颜色。
- 副本失去了 Store 包身份。登录（包括 Google）已在副本上测试过；聊天和 Claude Code 预计可用，但测试不多；Cowork 等与包绑定的功能未经测试。

### 为什么路由器需要在设置中手动操作

Store 包自己注册了 `claude://`，而且这个注册优先于 `HKCU\Software\Classes\claude`。因此路由器以普通应用的身份注册（`RegisteredApplications` + `Capabilities\UrlAssociations`），然后由用户在 *Default apps > Choose default apps by protocol*（默认应用 > 按协议指定默认应用）中选择它。Windows 用哈希保护这个选择，所以脚本无法设置。

## 会话同步（两个系统通用）

Claude Desktop 把 Claude Code 侧边栏的元数据保存在 `<data folder>/claude-code-sessions/<account>/<org>/` 中，并且只在启动时读取。`restore-cc-sessions.py` 做两件事：

1. **sync**：让每个实例的每个 org 文件夹拥有相同的 `local_*.json` / `deleted_*` 集合。`lastActivityAt` 最新的一方胜出。删除标记（tombstone）优先，除非该会话之后被重新创建；"resume on relaunch"（重新启动时恢复）标志不会被复制。
2. **restore**：为从终端 CLI 启动的会话记录（`~/.claude/projects`）添加侧边栏条目，因为它们不写元数据。

它只写元数据，从不写会话记录本身，并且是幂等的。在另一个实例中创建的会话，需要重启你正在查看的应用后才会出现。运行 `python3 shared/restore-cc-sessions.py --selftest`（Windows：`python ...`）进行检查。

在 Windows 上，每次启动 Claude 还会为 `claude://` 重新注册它自己的 exe（会被忽略：Store 的注册优先）、资源管理器文件夹右键菜单中的 "Claude Code" 项以及 toast 激活（`HKCU\Software\Classes\CLSID\...\LocalServer32`）。最后启动的 Claude 拥有这些注册。`uninstall.ps1` 会删除指向 `.claude-instances` 的条目；原版应用下次启动时会重新写入自己的条目。

## 故障排查

| 症状 | 检查 |
|---|---|
| 登录或 MCP 回调打开了错误的应用 | 路由器日志（macOS 上是 `claude-url-router.log`，Windows 上是 `%LOCALAPPDATA%\claude-link-router.log`）。日志只记录去掉 query 和 fragment 的 URL 以及目标。在 Windows 上，确认 Default apps 中 CLAUDE 已设为 Claude Link Router。 |
| 看不到其他应用的会话 | 重启应用。Windows：`Get-ScheduledTaskInfo claude-session-sync`（LastTaskResult 为 0），崩溃日志 `%USERPROFILE%\.claude\restore-cc-sessions.log`。macOS：`~/Library/Logs/claude-session-sync.log`。 |
| 实例仍是旧版 Claude（Windows） | 退出该实例，然后运行 `install.cmd <N>`，或等待 `claude-instances-refresh`；查看 `refresh.log`。 |
| "Another Claude window is already using the data"（macOS） | 使用同一数据文件夹的实例仍在运行；退出它。 |
| Windows 提示无法加载脚本 | 使用 `install.cmd`，或 `powershell -ExecutionPolicy Bypass -File ...`。 |
