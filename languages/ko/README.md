# Multiple-Claude

[English](../../README.md) | [简体中文](../zh-CN/README.md) | [Tiếng Việt](../vi/README.md) | **한국어**

> 이 문서는 영어 원문을 번역한 것입니다. 내용이 다를 경우 [영어 원문](../../README.md)이 우선합니다.

**macOS**와 **Windows**에서 여러 Claude Desktop 앱을 나란히 실행하고, 앱마다 각자의 계정으로 로그인합니다.

> 비공식 커뮤니티 도구입니다. Anthropic과 제휴 관계가 없으며 Anthropic의 승인을 받지 않았습니다. [면책 조항](#면책-조항)을 참고하세요.

## 기능

- **원래 앱 옆에서 Claude 2, 3, … 실행**: 인스턴스마다 로그인, 설정, 데이터가 따로 있습니다.
- **인스턴스별 고유 색상**: Dock / 작업 표시줄 / 시작 메뉴에 표시됩니다(Claude 2~10은 미리 정해진 색상 사용).
- **Claude Code 세션 공유**: 한 앱(또는 터미널 CLI)에서 시작한 Code 세션이 모든 앱에 나타납니다.
- **`claude://` 링크가 올바른 앱으로 돌아감**: MCP 로그인(GitHub, Figma 등)과 매직 링크가 마지막으로 실행된 앱이 아니라 사용 중이던 인스턴스로 돌아옵니다.
- **Claude 업데이트 자동 반영**: Claude가 업데이트되면 인스턴스가 스스로 다시 빌드됩니다.

## 요구 사항

| | macOS | Windows |
| --- | --- | --- |
| 시스템 | Apple 실리콘 Mac | Windows 10 / 11, x64 |
| Claude | `/Applications`에 있는 `Claude.app` | Microsoft Store 버전 Claude Desktop(MSIX) |
| 세션 동기화(선택) | Command Line Tools: `xcode-select --install` | Python 3: `winget install Python.Python.3.12` |
| 인스턴스당 디스크 | 거의 없음(APFS 클론) | 약 730 MB(앱 전체 복사본) |

## 빠른 시작

### macOS

```bash
git clone https://github.com/dris1153/multiple-claude.git
cd multiple-claude
bash install.sh          # builds Claude 2 and Claude 3
bash install.sh 4 5      # more instances
```

`/Applications` 또는 Launchpad에서 **Claude 2**를 열고 로그인합니다.

### Windows

```powershell
git clone https://github.com/dris1153/multiple-claude.git
cd multiple-claude
.\install.cmd            # or double-click install.cmd; builds Claude 2 and Claude 3
.\install.cmd 4 5        # more instances
```

처음 한 번만 수동으로 해야 하는 단계가 있습니다. 설치 프로그램이 **Settings > Apps > Default apps**(설정 > 앱 > 기본 앱)를 엽니다. **Choose default apps by protocol**(프로토콜별 기본 앱 선택)까지 스크롤한 뒤 **CLAUDE**를 찾아 **Claude Link Router**를 선택하세요. Windows는 이 선택을 스크립트가 아닌 사용자만 할 수 있게 합니다.

시작 메뉴에서 **Claude 2**를 열고 로그인합니다.

## 사용법

- **인스턴스 추가**: 원하는 번호를 붙여 설치 프로그램을 다시 실행합니다(2~99, 그중 2~10은 고유 색상 있음).
- **다시 실행해도 안전합니다**. Windows에서는 Claude 버전이 바뀌지 않는 한 아무것도 다시 빌드하지 않습니다. macOS에서는 지정한 앱을 매번 다시 빌드합니다(빠른 APFS 클론과 재서명. Apple Development 인증서가 없으면 macOS가 키체인 접근 권한을 다시 요청할 수 있음). 실행 중인 인스턴스는 건너뛰므로 먼저 종료한 뒤(macOS: Cmd+Q, Windows: 트레이 아이콘 우클릭 > Quit) 다시 실행하세요.
- **Claude 업데이트**: macOS에서는 다음에 인스턴스를 열 때 스스로 다시 빌드됩니다. Windows에서는 백그라운드 작업이 실행 중이 아닌 인스턴스를 다시 빌드합니다(로그인 시 및 30분마다).
- **Windows**: 창을 닫아도 Claude는 트레이에서 계속 실행됩니다. 완전히 끄려면 트레이 아이콘에서 종료하세요.

파일 위치:

| | macOS | Windows |
| --- | --- | --- |
| 인스턴스 앱 | `/Applications/Claude <N>.app` | `%USERPROFILE%\.claude-instances\app-claude<N>` + 시작 메뉴 바로 가기 |
| 인스턴스 데이터와 로그인 정보 | `~/.claude-instances/claude<N>` | `%USERPROFILE%\.claude-instances\claude<N>` |
| 링크 라우터 | `~/Applications/Claude Link Router.app` | `%USERPROFILE%\.claude-instances\claude-link-router.exe` |
| 로그 | `~/Library/Logs/claude-url-router.log`, `claude-session-sync.log` | `%LOCALAPPDATA%\claude-link-router.log`, `%USERPROFILE%\.claude-instances\refresh.log` |

## 제거

삭제 옵션(`--purge` / `-Purge`)을 주지 않으면 로그인 정보와 인스턴스 데이터는 그대로 남습니다. 원래 Claude 앱은 절대 건드리지 않습니다.

```bash
bash uninstall.sh            # macOS; add --purge to also delete instance data (not yet tested on a real Mac)
```

```powershell
powershell -ExecutionPolicy Bypass -File uninstall.ps1      # Windows; add -Purge to also delete instance data
```

Windows에서 Claude Link Router가 CLAUDE 링크의 기본 앱으로 설정되어 있었다면, 같은 설정 페이지에서 다시 **Claude**를 선택하세요.

## 제한 사항

- **링크 라우팅은 창 순서로 추측합니다**: 마지막으로 사용한 Claude 창이 링크를 받습니다. Claude 2에서 로그인을 시작한 뒤 완료하기 전에 Claude 3을 클릭하면 Claude 3이 콜백을 받습니다. Windows에서는 트레이에 숨겨진 인스턴스는 고려하지 않습니다.
- **Windows 인스턴스는 Store 앱의 비패키지 복사본입니다**. Windows는 Store 앱에 항상 패키지 아이콘을 표시하기 때문입니다. Store 패키지에 묶인 기능(예: Cowork)은 인스턴스에서 테스트되지 않았으며, 원래 앱에서는 그대로 사용할 수 있습니다.
- **Windows**: 서드파티 모드의 Claude(`Claude-3p`)는 세션 동기화에 포함되지 않습니다.
- **Windows**: 탐색기 우클릭 메뉴의 "Claude Code" 항목은 마지막으로 실행된 Claude의 것이며, 그 방법으로 연 인스턴스는 자기 프로필 없이 시작됩니다. 폴더는 앱 안에서 여는 것을 권장합니다.
- **macOS**: 제거 프로그램은 아직 실제 Mac에서 실행해 보지 않았습니다. 사용 전에 내용을 읽어 보세요.

## 동작 원리

OS별 설계, 각 구성 요소가 필요한 이유, 문제 해결 방법은 [docs/how-it-works.md](docs/how-it-works.md)를 참고하세요.

## 프로젝트 구조

```
install.sh / uninstall.sh          macOS 진입점
install.cmd / install.ps1          Windows 진입점
uninstall.ps1
assets/        spark.png, palette.json(인스턴스 색상), macos/ 미리 빌드된 Mac 아이콘
shared/        restore-cc-sessions.py(세션 동기화, 두 OS 공통)
macos/         클론 빌더, 링크 라우터, 세션 동기화 훅
windows/       설정, 앱 복사본 빌더, 아이콘 도구, 링크 라우터(C#), 갱신 작업 스크립트
docs/          how-it-works.md
languages/     README와 문서 번역본(zh-CN, vi, ko)
```

## 개발

```bash
python3 shared/restore-cc-sessions.py --selftest     # Windows: python shared\restore-cc-sessions.py --selftest
```

CI(`.github/workflows/ci.yml`)는 macOS와 Windows에서 셀프 테스트를 실행하고, 모든 셸 스크립트를 `bash -n`과 ShellCheck로 검사하고, 모든 PowerShell 스크립트를 파싱하고, 링크 라우터를 컴파일하고 아이콘을 빌드합니다.

## 크레딧

- 최초의 macOS 키트는 **lamnguyen**이 작성했습니다.
- Windows 포팅과 패키징: Multiple-Claude 기여자들.

## 면책 조항

Multiple-Claude는 Anthropic과 제휴 관계가 없으며 Anthropic의 승인이나 지원을 받지 않습니다. "Claude"와 Claude 로고는 Anthropic의 상표이며, spark 아트워크는 인스턴스를 구분하는 용도로만 사용합니다. 이 도구는 사용자 본인의 컴퓨터에서 Claude 앱을 복사하고 재서명하거나(macOS) 복사하고 아이콘을 바꿀 뿐이며(Windows), 앱을 재배포하지 않습니다. 사용에 따른 위험은 사용자 본인에게 있으며, Claude 업데이트로 인해 이 도구가 동작하지 않을 수 있습니다.

## 라이선스

[MIT](../../LICENSE)
