#!/bin/bash
# Builds the iPad app for this Apple-silicon Mac ("Designed for iPad") with the game data inside the bundle, and starts it.
# The engine is the same iOS build (build_engine.sh); no separate macOS port.
set -euo pipefail
cd "$(dirname "$0")"
# Signing team and bundle ID live outside the repo
[ -f local.env ] || { echo "copy ios/local.env.example to ios/local.env and fill it in"; exit 1; }
. ./local.env
export KAM_BUILD_NUMBER="${KAM_BUILD_NUMBER:-1}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
SRC="${KAM_DATA:-$(cd .. && pwd)/toolchain/kamres/app}"
# APFS clones: no extra disk space
rm -rf build/gamedata && mkdir -p build/gamedata
for d in data Campaigns Maps MapsMP Music Sounds Tutorials; do cp -c -R "$SRC/$d" build/gamedata/; done
# Optional mod: KAM_MOD=../mods/friendly ./run_mac.sh bundles its "Modding graphics" (sprites, theme.ini, fonts)
[ -z "${KAM_MOD:-}" ] || cp -c -R "$KAM_MOD/Modding graphics" build/gamedata/
xcodegen > /dev/null
xcodebuild -project KaM.xcodeproj -scheme KaM -configuration Debug -destination "platform=macOS,arch=arm64,variant=Designed for iPad" \
  -derivedDataPath build/xcode-mac -allowProvisioningUpdates -allowProvisioningDeviceRegistration build 2>&1 | grep -E "error:|BUILD" | tee build/xcodebuild-mac.txt
grep -q "BUILD SUCCEEDED" build/xcodebuild-mac.txt || { echo "build failed"; exit 1; }
# macOS only opens iPad apps in this wrapper layout
W="build/mac/KaM Remake.app"
rm -rf "$W" && mkdir -p "$W/Wrapper"
cp -c -R build/xcode-mac/Build/Products/Debug-iphoneos/KaM.app "$W/Wrapper/"
ln -s Wrapper/KaM.app "$W/WrappedBundle"
rm -rf build/gamedata && mkdir -p build/gamedata # back to the empty folder the iPad build expects
open "$W" "$@"
