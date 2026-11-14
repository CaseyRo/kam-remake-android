#!/bin/bash
# Wraps the three native libraries (build/ios/deps/lib*.dylib) as frameworks in build/ios/frameworks: the App Store
# does not accept bare dylibs in an app. Called by build_engine.sh; run it again after build_deps.sh.
set -euo pipefail
cd "$(dirname "$0")"
. ./local.env # KAM_BUNDLE_ID
OUT=build/ios/frameworks
rm -rf "$OUT"
for n in kamcore bass openal; do
  F="$OUT/$n.framework"
  mkdir -p "$F"
  cp "build/ios/deps/lib$n.dylib" "$F/$n"
  install_name_tool -id "@rpath/$n.framework/$n" \
    -change @rpath/libbass.dylib @rpath/bass.framework/bass \
    -change @rpath/libopenal.dylib @rpath/openal.framework/openal "$F/$n" 2>/dev/null
  cat > "$F/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>$n</string>
  <key>CFBundleIdentifier</key><string>$KAM_BUNDLE_ID.$n</string>
  <key>CFBundleName</key><string>$n</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleSupportedPlatforms</key><array><string>iPhoneOS</string></array>
  <key>MinimumOSVersion</key><string>15.0</string>
</dict></plist>
PLIST
done
