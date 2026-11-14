#!/bin/bash
# Copies the game data (toolchain/kamres/app, see android/toolchain/extract_data.sh) into the app's Documents folder
# on a connected iPad. The app must be installed first. Usage: push_data.sh [device name or id]
set -euo pipefail
# xcode-select may still point at the command line tools
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO/ios/local.env" # KAM_BUNDLE_ID
SRC="${KAM_DATA:-$REPO/toolchain/kamres/app}"
DEV="${1:-$(xcrun devicectl list devices | awk '/iPad/ {print $3; exit}')}"
for d in data Campaigns Maps MapsMP Music Sounds Tutorials "Modding graphics"; do
  [ -d "$SRC/$d" ] || continue # "Modding graphics" (sprite overrides of a mod) is optional
  echo "== $d"
  xcrun devicectl device copy to --device "$DEV" --domain-type appDataContainer --domain-identifier "$KAM_BUNDLE_ID" \
    --source "$SRC/$d" --destination "Documents/$d"
done
