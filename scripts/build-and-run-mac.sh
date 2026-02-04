#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  ACTIVE_DEV="$(xcode-select -p 2>/dev/null || true)"
  XCODE_DEV="/Applications/Xcode.app/Contents/Developer"
  if [[ -d "$XCODE_DEV" ]] && [[ -z "$ACTIVE_DEV" || "$ACTIVE_DEV" == "/Library/Developer/CommandLineTools" ]]; then
    export DEVELOPER_DIR="$XCODE_DEV"
    printf "🔧 Using Xcode toolchain: %s\n" "$DEVELOPER_DIR"
  fi
fi

cd "$(dirname "$0")/../apps/macos"

BUILD_PATH=".build-local"
PRODUCT="OpenClaw"
BIN="$BUILD_PATH/debug/$PRODUCT"

printf "\n▶️  Building $PRODUCT (debug, build path: $BUILD_PATH)\n"
swift build -c debug --product "$PRODUCT" --build-path "$BUILD_PATH"

printf "\n⏹  Stopping existing $PRODUCT...\n"
killall -q "$PRODUCT" 2>/dev/null || true

printf "\n🚀 Launching $BIN ...\n"
nohup "$BIN" >/tmp/openclaw.log 2>&1 &
PID=$!
printf "Started $PRODUCT (PID $PID). Logs: /tmp/openclaw.log\n"
