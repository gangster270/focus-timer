#!/bin/zsh
# 주간 업무 플래너 맥 앱 빌드: .app 번들 + .dmg 생성
#
#   ./build.sh            저장소의 index.html 로 빌드
#   ./build.sh --latest   GitHub main 의 최신 index.html 을 받아서 빌드
#
# 필요한 것: Xcode 또는 Command Line Tools (xcode-select --install)
set -e
cd "$(dirname "$0")"

OUT=dist
APP="$OUT/주간 업무 플래너.app"
HTML=../index.html

if [[ "$1" == "--latest" ]]; then
  echo "── 0. GitHub 에서 최신 index.html 내려받기"
  HTML="$OUT/index.html"
  mkdir -p "$OUT"
  curl -fsSL "https://raw.githubusercontent.com/gangster270/focus-timer/main/index.html" -o "$HTML"
fi
[[ -f "$HTML" ]] || { echo "index.html 을 찾을 수 없어요: $HTML"; exit 1; }

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "── 1. 앱 컴파일 (유니버설: Apple Silicon + Intel)"
BINTMP=$(mktemp -d)
swiftc -O -target arm64-apple-macos13.0 main.swift -o "$BINTMP/wp_arm64"
swiftc -O -target x86_64-apple-macos13.0 main.swift -o "$BINTMP/wp_x86_64"
lipo -create -output "$APP/Contents/MacOS/WeeklyPlanner" "$BINTMP/wp_arm64" "$BINTMP/wp_x86_64"
rm -rf "$BINTMP"

echo "── 2. 아이콘 생성"
ICONTMP=$(mktemp -d)
swiftc -O icongen.swift -o "$ICONTMP/icongen"
"$ICONTMP/icongen" "$ICONTMP/icon_1024.png"
ICONSET="$ICONTMP/AppIcon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 64 128 256 512; do
  sips -z $s $s "$ICONTMP/icon_1024.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2))
  sips -z $d $d "$ICONTMP/icon_1024.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONTMP"

echo "── 3. 번들 구성"
cp Info.plist "$APP/Contents/Info.plist"
cp "$HTML" "$APP/Contents/Resources/index.html"

echo "── 4. 서명 (ad-hoc)"
codesign --force --deep -s - "$APP"

echo "── 5. DMG 생성"
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$OUT/WeeklyPlanner.dmg"
hdiutil create -volname "주간 업무 플래너" -srcfolder "$STAGE" -ov -format UDZO "$OUT/WeeklyPlanner.dmg" >/dev/null
rm -rf "$STAGE"

echo
echo "완료!"
echo "  앱:  $APP"
echo "  DMG: $OUT/WeeklyPlanner.dmg"
echo "바로 실행하려면:  open \"$APP\""
