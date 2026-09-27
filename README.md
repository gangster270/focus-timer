# 주간 업무 플래너

한 파일(`index.html`)로 된 주간 할 일 플래너 + 포커스 타이머. 웹·아이폰·맥 앱·윈도우 앱이 모두 같은 `index.html` 을 씁니다.

- **웹**: https://gangster270.github.io/focus-timer/ — `main` 브랜치에 머지되면 자동 배포
- **맥 앱**: 아래 방법으로 `.app` 빌드
- **윈도우 앱**: Electron 데스크톱 앱 (아래 "윈도우 앱" 참고)
- **기기 간 데이터 동기화**: 화면 하단 ☁️ 동기화 (GitHub Gist, `gist` 권한 토큰 필요)
- **아이폰**: Safari → 공유 → "홈 화면에 추가" 하면 앱처럼 실행 (폰에서는 위젯 모드로 자동 시작)
- **캘린더 연동**: 완료되지 않은 모든 할일·루틴이 캘린더 구독 파일(`routines.ics`)로 동기화 Gist에 같이 올라감 → ☁️ 동기화 창의 "📲 캘린더 앱에서 바로 구독"으로 아이폰·맥 캘린더에 구독하면, 시간 있는 항목은 그 시간에 기본 알림 + 캘린더 위젯에 오늘 할일 표시. 완료하면 캘린더에서도 사라짐. 맥 앱은 루틴 자체 알림도 띄움

## 주요 기능

- **주간·월간 보드**, 여러 날에 걸친 할일은 위쪽 기간 막대로 표시
- **하루 우선순위(내 순서)**: 드래그나 ⋯ 메뉴로 순서를 정하면 1, 2, 3… 번호 표시
- **시간(시작~종료)** 과 하루 **시간표**(구글 캘린더식), 할일 아무 데나 누르면 바로 수정
- **📥 밀린 할일**: 지난 날에 남은 일·기한 지난 일을 모아 보고 이번 주 요일로 가져오기 (기한도 같이 옮기기)
- **🔁 반복 업무**: 요일·날짜 반복, 시간·캘린더 알림, 기한(생긴 날 기준 N일 뒤), 수정·드래그로 순서 변경
- **📝 메모**: 여러 줄, `# 제목` · `- 불릿` · `1. 번호` 서식
- **🪟 위젯**: 한눈에 보는 세로 목록 (추가·순서 조정 가능). 윈도우 앱에서는 **화면 왼쪽에 세로로 고정**
- **⏱ 타이머 · 🌳 정원 · 🗺 퀘스트**: 할일 완료 = 씨앗, 집중 완료 = 물

## 윈도우 앱 (Electron)

Node.js 가 설치된 PC에서:

```bash
npm install      # 처음 한 번 (Electron 설치)
npm start        # 실행 — 또는 실행.bat 더블클릭
npm run dist     # release/ 에 설치 파일(FocusTimer Setup)과 포터블 exe 생성
```

윈도우 앱에서만 되는 것: 📌 항상 위 고정, ◱ 미니 타이머, 작업표시줄 깜빡임, 한국 공휴일 자동 조회(공공데이터포털 키),
위젯을 화면 왼쪽에 세로로 고정(폭은 창 가장자리를 끌면 기억).

맥에서도 같은 방식으로 `npm install && npm start` 로 실행하거나 `npm run dist:mac` 으로 빌드할 수 있어요
(자세한 건 `맥북-설치안내.md`). 다만 맥은 아래 **맥 앱(WKWebView)** 빌드를 권장합니다.

## 맥 앱 빌드하기

Xcode(또는 Command Line Tools)가 설치된 맥에서:

```zsh
# 처음 한 번: Command Line Tools 설치 (Xcode 가 있으면 생략)
xcode-select --install

# 저장소 받기
git clone https://github.com/gangster270/focus-timer.git
cd focus-timer/mac

# 빌드 → dist/주간 업무 플래너.app + dist/WeeklyPlanner.dmg
./build.sh

# 실행
open "dist/주간 업무 플래너.app"
```

평소 업데이트는 이 한 줄이면 됩니다 — GitHub `main` 의 최신 `index.html` 로 빌드해서 `/Applications` 에 설치하고, 빌드 사본은 지워 앱이 두 개로 보이지 않게 합니다:

```zsh
cd ~/focus-timer/mac && ./build.sh --latest --install
```

옵션: `--latest` 는 저장소를 다시 받지 않고 최신 파일을 내려받아 빌드, `--install` 은 `/Applications` 에 설치.
`dist/WeeklyPlanner.dmg` 는 다른 맥에 옮길 때만 필요해요. 직접 빌드한 앱이라 Gatekeeper 경고 없이 바로 실행돼요.

### 맥 앱에서 되는 것

| 기능 | 설명 |
|---|---|
| 데이터 파일 저장 | `~/Library/Application Support/WeeklyPlanner/data.json` 에 자동 저장 |
| ☁️ 동기화 | 웹과 같은 토큰을 넣으면 같은 Gist 에 연결 (윈도우·휴대폰과 데이터 공유) |
| 📌 항상 위에 고정 | 타이머 화면의 핀 버튼 → 다른 창 위에 떠 있음 |
| ◱ 미니 타이머 | 작은 창으로 줄이고 항상 위에 |
| 데이터 내보내기 / 불러오기 | 맥 저장·열기 패널 사용 |
| 공휴일 자동 갱신 | 공공데이터포털 인증키를 넣으면 앱에서 직접 조회 |

## 구조

```
index.html        앱 화면·로직 전체 (웹·아이폰·맥 앱·윈도우 앱이 같은 파일을 씀)
main.js           윈도우 앱(Electron) 메인 프로세스 — 창, 항상 위, 미니 모드, 위젯 고정, 공휴일 조회
preload.js        Electron ↔ 화면 연결 (window.electronAPI)
package.json      Electron 실행·빌드 설정 (npm start / npm run dist)
build/            윈도우·맥(Electron) 앱 아이콘
실행.bat / 실행.command   더블클릭 실행 (윈도우 / 맥)
mac/main.swift    macOS 셸 (WKWebView + 파일 저장·다운로드·항상 위 등)
mac/icongen.swift 앱 아이콘 생성
mac/Info.plist    앱 정보
mac/build.sh      빌드 스크립트
icon-*.png, manifest.json   아이폰 홈 화면 앱
timer-only.html   타이머만 있던 예전 버전 (백업, 앱이 쓰지 않음)
성장시스템.html     별도 성장 기록 페이지 (앱이 쓰지 않음)
```

`index.html` 을 고치면 웹은 머지 즉시, 맥 앱은 `./build.sh` 를, 윈도우 앱은 `npm run dist` 를 다시 돌리면 반영됩니다.
