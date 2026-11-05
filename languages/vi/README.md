# Multiple-Claude

[English](../../README.md) | [简体中文](../zh-CN/README.md) | **Tiếng Việt** | [한국어](../ko/README.md)

> Bản dịch từ bản tiếng Anh. Nếu có khác biệt, [bản tiếng Anh](../../README.md) là bản chuẩn.

Chạy nhiều app Claude Desktop cùng lúc, mỗi app đăng nhập một tài khoản riêng, trên **macOS** và **Windows**.

> Công cụ cộng đồng không chính thức. Không liên kết với Anthropic và không được Anthropic xác nhận. Xem [Miễn trừ trách nhiệm](#miễn-trừ-trách-nhiệm).

## Tính năng

- **Claude 2, 3, … chạy cạnh app gốc**, mỗi app có đăng nhập, cài đặt và dữ liệu riêng.
- **Mỗi instance một màu riêng** trên Dock / thanh tác vụ / Start Menu (Claude 2 đến 10 có màu định sẵn).
- **Dùng chung session Claude Code**: session Code mở ở một app (hoặc ở CLI trong terminal) sẽ hiện ở tất cả các app.
- **Link `claude://` quay về đúng app**: đăng nhập MCP (GitHub, Figma, …) và magic link quay về instance bạn đang dùng, không phải app nào được mở sau cùng.
- **Theo kịp bản cập nhật của Claude**: các instance tự build lại khi Claude cập nhật.

## Yêu cầu

| | macOS | Windows |
| --- | --- | --- |
| Hệ thống | Mac dùng chip Apple silicon | Windows 10 / 11, x64 |
| Claude | `Claude.app` trong `/Applications` | Claude Desktop từ Microsoft Store (MSIX) |
| Đồng bộ session (tuỳ chọn) | Command Line Tools: `xcode-select --install` | Python 3: `winget install Python.Python.3.12` |
| Dung lượng mỗi instance | gần như không tốn (APFS clone) | khoảng 730 MB (bản sao đầy đủ của app) |

## Bắt đầu nhanh

### macOS

```bash
git clone https://github.com/dris1153/multiple-claude.git
cd multiple-claude
bash install.sh          # builds Claude 2 and Claude 3
bash install.sh 4 5      # more instances
```

Mở **Claude 2** từ `/Applications` hoặc Launchpad rồi đăng nhập.

### Windows

```powershell
git clone https://github.com/dris1153/multiple-claude.git
cd multiple-claude
.\install.cmd            # or double-click install.cmd; builds Claude 2 and Claude 3
.\install.cmd 4 5        # more instances
```

Có một bước thủ công, chỉ làm một lần: trình cài đặt sẽ mở **Settings > Apps > Default apps** (Cài đặt > Ứng dụng > Ứng dụng mặc định). Cuộn tới **Choose default apps by protocol** (Chọn ứng dụng mặc định theo giao thức), tìm **CLAUDE** và chọn **Claude Link Router**. Windows chỉ cho chính bạn đưa ra lựa chọn này, script không làm thay được.

Mở **Claude 2** từ Start Menu rồi đăng nhập.

## Sử dụng

- **Thêm instance**: chạy lại trình cài đặt với các số bạn muốn (2 đến 99; 2 đến 10 có màu riêng).
- **Chạy lại nhiều lần vẫn an toàn**. Trên Windows, không có gì được build lại trừ khi Claude đổi phiên bản. Trên macOS, các app bạn chỉ định sẽ được build lại mỗi lần (APFS clone và ký lại rất nhanh; nếu không có chứng chỉ Apple Development, macOS có thể hỏi lại quyền truy cập keychain). Instance đang chạy sẽ bị bỏ qua, nên hãy thoát nó trước (macOS: Cmd+Q; Windows: chuột phải vào icon ở khay hệ thống > Quit) rồi chạy lại.
- **Khi Claude cập nhật**: trên macOS, instance tự build lại ở lần mở tiếp theo; trên Windows, một tác vụ nền build lại các instance không chạy (lúc đăng nhập và mỗi 30 phút).
- **Windows**: đóng cửa sổ thì Claude vẫn chạy ở khay hệ thống. Muốn tắt hẳn, hãy thoát từ icon ở khay.

Vị trí các thành phần:

| | macOS | Windows |
| --- | --- | --- |
| App instance | `/Applications/Claude <N>.app` | `%USERPROFILE%\.claude-instances\app-claude<N>` + shortcut trong Start Menu |
| Dữ liệu và đăng nhập của instance | `~/.claude-instances/claude<N>` | `%USERPROFILE%\.claude-instances\claude<N>` |
| Link router | `~/Applications/Claude Link Router.app` | `%USERPROFILE%\.claude-instances\claude-link-router.exe` |
| Log | `~/Library/Logs/claude-url-router.log`, `claude-session-sync.log` | `%LOCALAPPDATA%\claude-link-router.log`, `%USERPROFILE%\.claude-instances\refresh.log` |

## Gỡ cài đặt

Dữ liệu đăng nhập và dữ liệu instance được giữ lại, trừ khi bạn xoá hẳn (`--purge` / `-Purge`). App Claude gốc không bao giờ bị động tới.

```bash
bash uninstall.sh            # macOS; add --purge to also delete instance data (not yet tested on a real Mac)
```

```powershell
powershell -ExecutionPolicy Bypass -File uninstall.ps1      # Windows; add -Purge to also delete instance data
```

Trên Windows, nếu Claude Link Router đang là app mặc định cho link CLAUDE, hãy chọn lại **Claude** trong cùng trang Settings đó.

## Hạn chế

- **Việc chuyển link dựa trên phỏng đoán** theo thứ tự cửa sổ: cửa sổ Claude bạn dùng gần nhất sẽ nhận link. Nếu bạn bắt đầu đăng nhập ở Claude 2 rồi bấm sang Claude 3 trước khi xong, Claude 3 sẽ nhận callback. Trên Windows, instance đang ẩn ở khay hệ thống không được tính.
- **Instance trên Windows là bản sao không đóng gói (unpackaged)** của app Store, vì Windows luôn hiện icon của package cho app Store. Các tính năng gắn với package Store (ví dụ Cowork) chưa được thử trên instance; app gốc vẫn giữ các tính năng đó.
- **Windows**: Claude ở chế độ bên thứ ba (`Claude-3p`) không nằm trong phạm vi đồng bộ session.
- **Windows**: mục "Claude Code" trong menu chuột phải của Explorer thuộc về Claude nào được mở sau cùng, và instance mở theo cách đó sẽ khởi động mà không có profile riêng. Nên mở thư mục từ bên trong app.
- **macOS**: trình gỡ cài đặt chưa từng được chạy trên Mac thật. Hãy đọc nó trước khi dùng.

## Cách hoạt động

Xem [docs/how-it-works.md](docs/how-it-works.md) để biết thiết kế trên từng hệ điều hành, lý do cần từng thành phần và cách xử lý sự cố.

## Cấu trúc dự án

```
install.sh / uninstall.sh          điểm vào cho macOS
install.cmd / install.ps1          điểm vào cho Windows
uninstall.ps1
assets/        spark.png, palette.json (màu các instance), macos/ icon Mac build sẵn
shared/        restore-cc-sessions.py (đồng bộ session, dùng cho cả hai hệ điều hành)
macos/         trình build bản clone, link router, hook đồng bộ session
windows/       cấu hình, trình build bản sao app, công cụ icon, link router (C#), script tác vụ làm mới
docs/          how-it-works.md
languages/     bản dịch README và docs (zh-CN, vi, ko)
```

## Phát triển

```bash
python3 shared/restore-cc-sessions.py --selftest     # Windows: python shared\restore-cc-sessions.py --selftest
```

CI (`.github/workflows/ci.yml`) chạy self-test trên macOS và Windows, kiểm tra mọi shell script bằng `bash -n` và ShellCheck, parse mọi script PowerShell, biên dịch link router và build icon.

## Ghi công

- Bộ công cụ macOS ban đầu do **lamnguyen** viết.
- Bản port Windows và đóng gói: những người đóng góp cho Multiple-Claude.

## Miễn trừ trách nhiệm

Multiple-Claude không liên kết với Anthropic, không được Anthropic xác nhận hay hỗ trợ. "Claude" và logo Claude là nhãn hiệu của Anthropic; hình spark chỉ được dùng để phân biệt các instance. Công cụ này sao chép và ký lại (macOS) hoặc sao chép và đổi icon (Windows) app Claude ngay trên máy của bạn và không bao giờ phân phối lại app. Bạn tự chịu rủi ro khi sử dụng; một bản cập nhật Claude có thể làm công cụ ngừng hoạt động.

## Giấy phép

[MIT](../../LICENSE)
