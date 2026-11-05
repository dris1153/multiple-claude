# 동작 원리

[English](../../../docs/how-it-works.md) | [简体中文](../../zh-CN/docs/how-it-works.md) | [Tiếng Việt](../../vi/docs/how-it-works.md) | **한국어**

> 이 문서는 영어 원문을 번역한 것입니다. 내용이 다를 경우 [영어 원문](../../../docs/how-it-works.md)이 우선합니다.

Claude Desktop은 Electron 앱입니다. Electron은 모든 상태(로그인, 설정, 캐시)를 하나의 *사용자 데이터 폴더*에 저장하며, `--user-data-dir` 플래그로 다른 위치를 지정할 수 있습니다. Multiple-Claude의 모든 인스턴스는 같은 Claude 앱을 각자의 데이터 폴더로 실행한 것입니다. 나머지 구성 요소는 각 인스턴스가 별도의 앱처럼 느껴지게 하고 공유 기능이 계속 동작하도록 합니다.

## macOS

| 구성 요소 | 동작 방식 | 설치 위치 |
|---|---|---|
| 인스턴스 앱 | `macos/build-claude2.sh`가 `/Applications/Claude.app`을 클론하고(APFS 클론, 추가 용량 없음), 번들 ID `local.claude-desktop-<N>`, 표시 이름, 아이콘을 설정하고, 실행 파일을 런처로 교체하고, Anthropic 전용 entitlement를 제거한 뒤 재서명합니다(Apple Development 인증서가 있으면 사용, 없으면 ad hoc). | `/Applications/Claude <N>.app` |
| 런처 | 같은 데이터 폴더로 두 번 열리는 것을 막고, `Claude.app` 버전이 바뀌면 클론을 다시 빌드하고, 세션 동기화를 실행한 다음 `--user-data-dir`로 Claude를 `exec`합니다. | 각 앱 내부 |
| 업데이터 차단 | `~/Library/Caches/local.claude-desktop-<N>.ShipIt` 자리에 파일을 두어 클론 자체의 업데이터를 막습니다(업데이터가 받은 파일은 서명 검사에 실패함). 대신 클론은 런처를 통해 원래 앱을 따라갑니다. | `~/Library/Caches` |
| 링크 라우터 | `claude://`를 담당하는 AppleScript 애플릿으로, 각 URL을 가장 위에 있는 Claude 앱에 넘깁니다(`lsappinfo visibleProcessList`). LaunchServices 데이터베이스를 감시하는 LaunchAgent가, Claude 앱이 실행되면서 스킴을 가져갈 때마다 되찾아 옵니다. | `~/Applications/Claude Link Router.app`, `~/Library/LaunchAgents/com.lamnguyen.claude-url-router.plist` |
| 세션 동기화 | `shared/restore-cc-sessions.py`. 각 런처와 60초마다 실행되는 LaunchAgent가 실행합니다. | `~/.claude/bin`, `~/Library/LaunchAgents/com.lamnguyen.claude-session-sync.plist` |
| Chrome 매니페스트 잠금 | 클론은 Chrome 데이터를 읽을 수 없어서 Claude in Chrome 확장이 없다고 판단하고 그 native-messaging 매니페스트를 삭제합니다. 런처가 이 파일에 "deny delete" ACL을 추가합니다. | Chrome `NativeMessagingHosts` |

LaunchAgent 레이블은 기존 설치가 계속 동작하도록 원래의 `com.lamnguyen.*` 이름을 유지합니다.

### macOS 아이콘 다시 만들기

`assets/macos/claude<N>.car`는 Icon Composer `.icon` 문서에서 컴파일됩니다. 색상을 바꾸려면 `assets/palette.json`을 수정한 뒤 Xcode로 해당 아이콘을 다시 빌드합니다. `claude<N>.icon/Assets/spark.png`(`assets/spark.png`의 복사본)와 `claude<N>.icon/icon.json`을 만듭니다. `icon.json`에서는 팔레트의 두 색상을 `srgb:` 실수(hex / 255)로 쓰고, scale에는 `sparkScale`을 씁니다:

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

이에 대응하는 레거시 `claude<N>.icns`는 구버전 macOS용 대체 파일입니다.

## Windows

| 구성 요소 | 동작 방식 | 설치 위치 |
|---|---|---|
| 인스턴스 앱 | `windows/build-instance.ps1`이 Store 앱 폴더(`WindowsApps\Claude_*\app`)를 복사하고, 복사본 `claude.exe`의 아이콘 리소스를 패치합니다(`set-exe-icon.ps1`, kernel32 `UpdateResource`). `.package-version` 스탬프에 원본 버전을 기록합니다. | `%USERPROFILE%\.claude-instances\app-claude<N>` |
| 바로 가기 | 시작 메뉴의 `Claude <N>.lnk`가 `--user-data-dir`로 복사본을 실행합니다. | 시작 메뉴 |
| 아이콘 | `windows/make-icons.ps1`이 `assets/palette.json`과 `assets/spark.png`로 각 `.ico`를 그립니다(System.Drawing, 16~256 px). | `%USERPROFILE%\.claude-instances\icons` |
| 업데이트 후속 처리 | 예약 작업 `claude-instances-refresh`(로그인 시 및 30분마다, `conhost --headless`로 숨김 실행)가 설치된 Claude보다 오래된 복사본을 다시 빌드하며, 실행 중인 것은 건너뜁니다. | Task Scheduler(작업 스케줄러) |
| 링크 라우터 | `windows/claude-link-router.cs`. 설치할 때 .NET Framework의 `csc.exe`로 컴파일됩니다. 최상위 창을 z-order 순으로 훑어 첫 번째 Claude 창을 찾고, 그 프로세스의 명령줄을 읽은 다음(WMI 쿼리 1회, 3초 타임아웃) URL과 함께 해당 인스턴스의 exe를 실행합니다. Electron의 단일 인스턴스 잠금이 URL을 실행 중인 인스턴스에 넘깁니다. | `%USERPROFILE%\.claude-instances\claude-link-router.exe` |
| 세션 동기화 | `pythonw`로 실행되는 `shared/restore-cc-sessions.py`. 예약 작업 `claude-session-sync`가 1분마다 실행합니다. | `%USERPROFILE%\.claude\bin` |

### Store 앱 대신 복사본을 쓰는 이유

Windows 10과 Claude 4.x에서 테스트했습니다:

- Store 앱을 `--user-data-dir`로 실행하면 동작하고 로그인도 따로 됩니다. 하지만 Store(MSIX) 앱의 작업 표시줄 버튼은 항상 패키지 아이콘을 보여 주며, 바로 가기 아이콘과 `WM_SETICON`은 무시됩니다. 비패키지 복사본은 exe 아이콘을 쓰므로 인스턴스마다 고유 색상을 가질 수 있습니다.
- 복사본은 Store 패키지 ID를 잃습니다. 로그인(Google 포함)은 복사본에서 테스트했고, 채팅과 Claude Code는 동작할 것으로 예상되지만 테스트가 적으며, Cowork처럼 패키지에 묶인 기능은 테스트하지 않았습니다.

### 라우터에 Settings 수동 단계가 필요한 이유

Store 패키지가 `claude://`를 직접 등록하며, 이 등록이 `HKCU\Software\Classes\claude`보다 우선합니다. 그래서 라우터는 일반 앱으로 등록합니다(`RegisteredApplications` + `Capabilities\UrlAssociations`). 그런 다음 사용자가 *Default apps > Choose default apps by protocol*(기본 앱 > 프로토콜별 기본 앱 선택)에서 라우터를 선택합니다. Windows는 이 선택을 해시로 보호하므로 스크립트로는 설정할 수 없습니다.

## 세션 동기화(두 OS 공통)

Claude Desktop은 Claude Code 사이드바 메타데이터를 `<data folder>/claude-code-sessions/<account>/<org>/`에 저장하고 시작할 때만 읽습니다. `restore-cc-sessions.py`가 하는 일은 다음과 같습니다:

1. **sync**: 모든 인스턴스의 모든 org 폴더가 같은 `local_*.json` / `deleted_*` 집합을 갖게 합니다. `lastActivityAt`이 가장 최신인 쪽이 이깁니다. 삭제 표시(tombstone)는 나중에 세션이 다시 생성되지 않는 한 우선하며, "resume on relaunch"(다시 실행 시 재개) 플래그는 복사하지 않습니다.
2. **restore**: 터미널 CLI에서 시작한 트랜스크립트(`~/.claude/projects`)에 사이드바 항목을 추가합니다. 이런 트랜스크립트는 메타데이터를 남기지 않습니다.

메타데이터만 쓰고 트랜스크립트는 절대 쓰지 않으며, 멱등적입니다. 다른 인스턴스에서 만든 세션은 지금 보고 있는 앱을 다시 시작해야 나타납니다. `python3 shared/restore-cc-sessions.py --selftest`(Windows: `python ...`)로 확인할 수 있습니다.

Windows에서는 Claude가 실행될 때마다 자기 exe를 `claude://`용으로 다시 등록하고(Store 등록이 우선하므로 무시됨), 탐색기 폴더 우클릭 메뉴의 "Claude Code" 항목과 토스트 활성화(`HKCU\Software\Classes\CLSID\...\LocalServer32`)도 다시 등록합니다. 마지막으로 실행된 Claude가 이 항목들을 차지합니다. `uninstall.ps1`은 `.claude-instances`를 가리키는 항목을 제거하며, 원래 앱은 다음 실행 때 자신의 항목을 다시 씁니다.

## 문제 해결

| 증상 | 확인할 것 |
|---|---|
| 로그인 또는 MCP 콜백이 엉뚱한 앱을 연다 | 라우터 로그(macOS는 `claude-url-router.log`, Windows는 `%LOCALAPPDATA%\claude-link-router.log`). 로그에는 query와 fragment를 뺀 URL과 대상만 기록됩니다. Windows에서는 Default apps에서 CLAUDE가 Claude Link Router로 설정되어 있는지 확인하세요. |
| 다른 앱의 세션이 보이지 않는다 | 앱을 다시 시작하세요. Windows: `Get-ScheduledTaskInfo claude-session-sync`(LastTaskResult 0), 크래시 로그 `%USERPROFILE%\.claude\restore-cc-sessions.log`. macOS: `~/Library/Logs/claude-session-sync.log`. |
| 인스턴스가 여전히 이전 Claude 버전이다(Windows) | 인스턴스를 종료한 뒤 `install.cmd <N>`을 실행하거나 `claude-instances-refresh`를 기다리세요. `refresh.log`를 확인하세요. |
| "Another Claude window is already using the data"(macOS) | 같은 데이터 폴더를 쓰는 인스턴스가 아직 실행 중입니다. 종료하세요. |
| Windows에서 스크립트를 로드할 수 없다고 나온다 | `install.cmd` 또는 `powershell -ExecutionPolicy Bypass -File ...`을 사용하세요. |
