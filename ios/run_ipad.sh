#!/bin/bash
# Builds the host app, installs it on the connected iPad and runs it with the console attached.
# Usage: [KAM_SELFTEST=campaigns] run_ipad.sh [seconds to keep the console attached, default 60]
set -uo pipefail
cd "$(dirname "$0")"
# Signing team and bundle ID live outside the repo
[ -f local.env ] || { echo "copy ios/local.env.example to ios/local.env and fill it in"; exit 1; }
. ./local.env
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
DEV="${KAM_DEVICE:-$(xcrun devicectl list devices | awk '/iPad/ && !/simulated/ {for(i=1;i<=NF;i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) {print $i; exit}}')}"
rm -rf build/gamedata # Mac-only bundled data (run_mac.sh); the iPad gets its data from push_data.sh
xcodegen > /dev/null
xcodebuild -project KaM.xcodeproj -scheme KaM -configuration Debug -destination "id=$DEV" -derivedDataPath build/xcode \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build 2>&1 | grep -E "error:|BUILD" || true
xcrun devicectl device install app --device "$DEV" build/xcode/Build/Products/Debug-iphoneos/KaM.app > /dev/null 2>&1 || { echo "install failed"; exit 1; }
[ -z "${KAM_SELFTEST:-}" ] || export DEVICECTL_CHILD_KAM_SELFTEST="$KAM_SELFTEST"
perl -e 'alarm shift; exec @ARGV' "${1:-60}" xcrun devicectl device process launch --console --terminate-existing --device "$DEV" "$KAM_BUNDLE_ID" > run-ipad.log 2>&1
echo "console: $(wc -l < run-ipad.log) lines in ios/run-ipad.log"
