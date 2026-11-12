#!/bin/bash
# Archives the app and uploads it to App Store Connect for TestFlight. Usage: testflight.sh <build number>
# Needs the Apple account signed in to Xcode and the app record for KAM_BUNDLE_ID in App Store Connect.
# The upload carries no game data; testers pick their own folder in the app ("Choose game folder...").
set -euo pipefail
cd "$(dirname "$0")"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
. ./local.env
export KAM_BUILD_NUMBER="${1:?build number, higher than the last upload}"
rm -rf build/gamedata && mkdir -p build/gamedata
xcodegen > /dev/null
rm -rf build/KaM.xcarchive build/export
xcodebuild -project KaM.xcodeproj -scheme KaM -configuration Release -destination "generic/platform=iOS" \
  -archivePath build/KaM.xcarchive -derivedDataPath build/xcode-release -allowProvisioningUpdates archive 2>&1 \
  | grep -E "error:|ARCHIVE" | tee build/archive.txt
grep -q "ARCHIVE SUCCEEDED" build/archive.txt || { echo "archive failed"; exit 1; }
cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$KAM_TEAM</string>
  <key>signingStyle</key><string>automatic</string>
  <key>testFlightInternalTestingOnly</key><true/>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath build/KaM.xcarchive -exportOptionsPlist build/ExportOptions.plist \
  -exportPath build/export -allowProvisioningUpdates 2>&1 | grep -v "^$" | tail -15
