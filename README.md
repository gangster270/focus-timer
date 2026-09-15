# 주간 업무 플래너

한 파일(`index.html`)로 된 주간 할 일 플래너 + 포커스 타이머.

- **웹**: https://gangster270.github.io/focus-timer/ — `main` 브랜치에 머지되면 자동 배포
- **맥 앱**: 아래 방법으로 `.app` 빌드
- **기기 간 데이터 동기화**: 화면 하단 ☁️ 동기화 (GitHub Gist, `gist` 권한 토큰 필요)
- **아이폰**: Safari → 공유 → "홈 화면에 추가" 하면 앱처럼 실행 (폰에서는 위젯 모드로 자동 시작)
- **루틴 알림**: 🔁 반복 업무에 시간을 넣으면 캘린더 구독 파일(`routines.ics`)이 동기화 Gist에 같이 올라감 → ☁️ 동기화 창의 주소를 아이폰·맥 캘린더에 구독하면 그 시간에 기본 알림 + 캘린더 위젯. 맥 앱은 자체 알림도 띄움

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

`./build.sh --latest` 로 실행하면 저장소를 다시 받지 않고 GitHub `main` 의 최신 `index.html` 을 내려받아 빌드합니다.

빌드된 앱을 `/Applications` 로 옮기거나, `dist/WeeklyPlanner.dmg` 를 열어 Applications 에 드래그하면 됩니다.
직접 빌드한 앱이라 Gatekeeper 경고 없이 바로 실행돼요.

### 앱에서 되는 것

| 기능 | 설명 |
|---|---|
| 데이터 파일 저장 | `~/Library/Application Support/WeeklyPlanner/data.json` 에 자동 저장 |
| ☁️ 동기화 | 웹과 같은 토큰을 넣으면 같은 Gist 에 연결 (윈도우·휴대폰과 데이터 공유) |
| 📌 항상 위에 고정 | 타이머 화면의 핀 버튼 → 다른 창 위에 떠 있음 |
| ◱ 미니 타이머 | 작은 창으로 줄이고 항상 위에 |
| 데이터 내보내기 / 불러오기 | 맥 저장·열기 패널 사용 |
| 공휴일 자동 갱신 | 공공데이터포털 인증키를 넣으면 앱에서 직접 조회 |

### 구조

```
index.html        앱 화면·로직 전체 (웹과 앱이 같은 파일을 씀)
mac/main.swift    macOS 셸 (WKWebView + 파일 저장·다운로드·항상 위 등)
mac/icongen.swift 앱 아이콘 생성
mac/Info.plist    앱 정보
mac/build.sh      빌드 스크립트
```

`index.html` 을 고치면 웹은 머지 즉시, 앱은 `./build.sh` 를 다시 돌리면 반영됩니다.
