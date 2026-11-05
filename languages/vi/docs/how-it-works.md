# Cách hoạt động

[English](../../../docs/how-it-works.md) | [简体中文](../../zh-CN/docs/how-it-works.md) | **Tiếng Việt** | [한국어](../../ko/docs/how-it-works.md)

> Bản dịch từ bản tiếng Anh. Nếu có khác biệt, [bản tiếng Anh](../../../docs/how-it-works.md) là bản chuẩn.

Claude Desktop là một app Electron. Electron lưu toàn bộ trạng thái (đăng nhập, cài đặt, cache) trong một *thư mục user data*, và flag `--user-data-dir` trỏ thư mục đó sang chỗ khác. Mỗi instance của Multiple-Claude đều là cùng một app Claude, chỉ khác ở chỗ được khởi động với thư mục dữ liệu riêng. Phần còn lại của bộ công cụ giúp mỗi instance trông như một app riêng và giữ cho các tính năng dùng chung vẫn hoạt động.

## macOS

| Thành phần | Cơ chế | Vị trí cài đặt |
|---|---|---|
| App instance | `macos/build-claude2.sh` clone `/Applications/Claude.app` (APFS clone, không tốn thêm dung lượng), đặt bundle ID `local.claude-desktop-<N>`, tên hiển thị và icon, thay file thực thi bằng một launcher, gỡ các entitlement chỉ dành cho Anthropic rồi ký lại (dùng chứng chỉ Apple Development nếu có, nếu không thì ký ad hoc). | `/Applications/Claude <N>.app` |
| Launcher | Không cho mở hai lần trên cùng một thư mục dữ liệu, build lại bản clone khi `Claude.app` đổi phiên bản, chạy đồng bộ session, rồi `exec` Claude với `--user-data-dir`. | bên trong mỗi app |
| Chặn updater | Một file đặt ở vị trí `~/Library/Caches/local.claude-desktop-<N>.ShipIt` chặn updater riêng của bản clone (bản tải về của nó sẽ không qua được bước kiểm tra chữ ký). Thay vào đó, bản clone đi theo app gốc thông qua launcher. | `~/Library/Caches` |
| Link router | Applet AppleScript giữ scheme `claude://` và chuyển mỗi URL cho app Claude đang nằm trên cùng (`lsappinfo visibleProcessList`). Một LaunchAgent theo dõi database của LaunchServices sẽ giành lại scheme mỗi khi một app Claude chiếm nó lúc khởi động. | `~/Applications/Claude Link Router.app`, `~/Library/LaunchAgents/com.lamnguyen.claude-url-router.plist` |
| Đồng bộ session | `shared/restore-cc-sessions.py`, được chạy bởi từng launcher và bởi một LaunchAgent mỗi 60 giây. | `~/.claude/bin`, `~/Library/LaunchAgents/com.lamnguyen.claude-session-sync.plist` |
| Khoá manifest Chrome | Bản clone không đọc được dữ liệu Chrome, tưởng extension Claude in Chrome không còn và xoá manifest native-messaging của nó. Launcher thêm ACL "deny delete" cho file đó. | Chrome `NativeMessagingHosts` |

Nhãn của các LaunchAgent vẫn giữ tên gốc `com.lamnguyen.*` để các bản cài đặt có sẵn tiếp tục chạy.

### Tạo lại icon macOS

`assets/macos/claude<N>.car` được biên dịch từ một tài liệu `.icon` của Icon Composer. Muốn đổi màu, hãy sửa `assets/palette.json` rồi build lại icon đó bằng Xcode. Tạo `claude<N>.icon/Assets/spark.png` (bản sao của `assets/spark.png`) và `claude<N>.icon/icon.json`. Trong `icon.json`, ghi hai màu của palette dưới dạng số thực `srgb:` (hex / 255) và dùng `sparkScale` làm scale:

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

File `claude<N>.icns` kiểu cũ tương ứng là phương án dự phòng cho các bản macOS cũ.

## Windows

| Thành phần | Cơ chế | Vị trí cài đặt |
|---|---|---|
| App instance | `windows/build-instance.ps1` sao chép thư mục app Store (`WindowsApps\Claude_*\app`) và sửa tài nguyên icon trong `claude.exe` của bản sao (`set-exe-icon.ps1`, kernel32 `UpdateResource`). File đánh dấu `.package-version` ghi lại phiên bản nguồn. | `%USERPROFILE%\.claude-instances\app-claude<N>` |
| Shortcut | `Claude <N>.lnk` trong Start Menu chạy bản sao với `--user-data-dir`. | Start Menu |
| Icon | `windows/make-icons.ps1` vẽ từng file `.ico` từ `assets/palette.json` và `assets/spark.png` (System.Drawing, 16 đến 256 px). | `%USERPROFILE%\.claude-instances\icons` |
| Theo kịp cập nhật | Scheduled Task `claude-instances-refresh` (lúc đăng nhập và mỗi 30 phút, chạy ẩn qua `conhost --headless`) build lại các bản sao cũ hơn Claude đã cài, bỏ qua bản đang chạy. | Task Scheduler (Bộ lập lịch tác vụ) |
| Link router | `windows/claude-link-router.cs`, được biên dịch lúc cài đặt bằng `csc.exe` của .NET Framework. Nó duyệt các cửa sổ cấp cao nhất theo z-order, tìm cửa sổ Claude đầu tiên, đọc command line của tiến trình đó (một truy vấn WMI, timeout 3 giây) rồi khởi động exe của instance đó kèm URL. Khoá single-instance của Electron sẽ chuyển URL cho instance đang chạy. | `%USERPROFILE%\.claude-instances\claude-link-router.exe` |
| Đồng bộ session | `shared/restore-cc-sessions.py` chạy qua `pythonw`, Scheduled Task `claude-session-sync` chạy mỗi phút. | `%USERPROFILE%\.claude\bin` |

### Vì sao dùng bản sao thay vì app Store

Đã thử trên Windows 10 với Claude 4.x:

- Mở app Store với `--user-data-dir` vẫn chạy và cho đăng nhập riêng. Nhưng nút trên thanh tác vụ của app Store (MSIX) luôn hiện icon của package; icon của shortcut và `WM_SETICON` đều bị bỏ qua. Bản sao không đóng gói dùng icon của exe, nên mỗi instance có được màu riêng.
- Bản sao mất định danh package Store. Đăng nhập (kể cả Google) đã được thử trên bản sao; chat và Claude Code được cho là chạy được nhưng mới thử ít; các tính năng gắn với package như Cowork chưa được thử.

### Vì sao router cần một bước thủ công trong Settings

Package Store tự đăng ký `claude://`, và đăng ký đó được ưu tiên hơn `HKCU\Software\Classes\claude`. Vì vậy router đăng ký như một app thông thường (`RegisteredApplications` + `Capabilities\UrlAssociations`). Sau đó người dùng chọn nó trong *Default apps > Choose default apps by protocol* (Ứng dụng mặc định > Chọn ứng dụng mặc định theo giao thức). Windows bảo vệ lựa chọn đó bằng hash, nên script không đặt được.

## Đồng bộ session (cả hai hệ điều hành)

Claude Desktop lưu metadata sidebar của Claude Code trong `<data folder>/claude-code-sessions/<account>/<org>/` và chỉ đọc lúc khởi động. `restore-cc-sessions.py` làm hai việc:

1. **sync**: làm cho mọi thư mục org của mọi instance có cùng một tập `local_*.json` / `deleted_*`. Bản có `lastActivityAt` mới nhất thắng. Tombstone (dấu đã xoá) thắng, trừ khi session được tạo lại sau đó; cờ "resume on relaunch" (tiếp tục khi mở lại) không được sao chép.
2. **restore**: thêm mục sidebar cho các transcript được tạo từ CLI trong terminal (`~/.claude/projects`), vì chúng không ghi metadata.

Nó chỉ ghi metadata, không bao giờ ghi transcript, và chạy lặp lại vẫn cho cùng kết quả (idempotent). Session tạo ở instance khác chỉ hiện ra sau khi bạn khởi động lại app đang xem. Chạy `python3 shared/restore-cc-sessions.py --selftest` (Windows: `python ...`) để kiểm tra.

Trên Windows, mỗi lần Claude khởi động còn đăng ký lại exe của chính nó cho `claude://` (bị bỏ qua: đăng ký của Store được ưu tiên), mục "Claude Code" trong menu chuột phải thư mục của Explorer, và toast activation (`HKCU\Software\Classes\CLSID\...\LocalServer32`). Claude nào khởi động sau cùng sẽ sở hữu các mục đó. `uninstall.ps1` xoá các mục trỏ vào `.claude-instances`; app gốc sẽ tự ghi lại mục của nó ở lần khởi động tiếp theo.

## Xử lý sự cố

| Triệu chứng | Kiểm tra |
|---|---|
| Đăng nhập hoặc callback MCP mở nhầm app | Log của router (`claude-url-router.log` trên macOS, `%LOCALAPPDATA%\claude-link-router.log` trên Windows). Log chỉ ghi URL (bỏ query và fragment) cùng app đích. Trên Windows, kiểm tra CLAUDE đã được đặt thành Claude Link Router trong Default apps. |
| Không thấy session từ app khác | Khởi động lại app. Windows: `Get-ScheduledTaskInfo claude-session-sync` (LastTaskResult bằng 0), log lỗi `%USERPROFILE%\.claude\restore-cc-sessions.log`. macOS: `~/Library/Logs/claude-session-sync.log`. |
| Instance vẫn ở phiên bản Claude cũ (Windows) | Thoát instance, rồi chạy `install.cmd <N>` hoặc chờ `claude-instances-refresh`; xem `refresh.log`. |
| "Another Claude window is already using the data" (macOS) | Một instance dùng cùng thư mục dữ liệu vẫn đang chạy; hãy thoát nó. |
| Windows báo không tải được script | Dùng `install.cmd`, hoặc `powershell -ExecutionPolicy Bypass -File ...`. |
