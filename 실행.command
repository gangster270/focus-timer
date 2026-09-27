#!/bin/sh
# macOS 용 실행 런처 (실행.bat의 맥 버전)
# 처음 한 번만: 터미널에서  chmod +x '실행.command'
cd "$(dirname "$0")" || exit 1
if [ ! -d node_modules ]; then
  echo "❌ node_modules 가 없어요. 먼저 터미널에서  npm install  을 한 번 실행하세요."
  read -r _ 
  exit 1
fi
./node_modules/.bin/electron . 
