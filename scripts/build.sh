#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild -quiet -project ScreenQR.xcodeproj -scheme ScreenQR \
  -destination "platform=macOS,arch=$(uname -m)" -configuration Release -derivedDataPath "$PWD/build/DerivedData" build
app="$PWD/build/DerivedData/Build/Products/Release/Screen QR.app"
codesign --verify --deep --strict "$app"
plutil -lint "$app/Contents/Info.plist" "$app/Contents/PlugIns/ScreenQRControls.appex/Contents/Info.plist"
"$app/Contents/MacOS/Screen QR" --self-test
