#!/bin/bash
# Builds the KaM Remake engine (android/pascal/kamcore.lpr) for Apple arm64 as libkamcore.dylib.
# The iOS port reuses the Android port's sources: -dANDROID means "touch host port" here.
#   KAM_TARGET=ios (default)  needs the FPC iOS RTL in toolchain/fpc-3.2.2 and Xcode's iPhoneOS SDK
#   KAM_TARGET=darwin         macOS build with the Homebrew FPC units, for the desktop smoke test (ios/mactest.c)
# Native libraries (libbass, libopenal, gl4es libGL.a on iOS) are expected in ios/build/$KAM_TARGET/deps
set -euo pipefail
# xcode-select may still point at the command line tools
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
IOS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$IOS_DIR/.." && pwd)"
TC="${KAM_TOOLCHAIN:-$REPO/toolchain}"
TARGET="${KAM_TARGET:-ios}"
LAZ="$TC/lazarus/components/lazutils"
BUILD="$IOS_DIR/build/$TARGET"
OUT="$BUILD/lib"
PKGS="rtl-objpas rtl-generics rtl-extra fcl-image fcl-base fcl-json fcl-xml fcl-process paszlib hash regexpr fcl-net rtl-unicode pthreads fcl-registry"

if [ "$TARGET" = ios ]; then
  FPC="$TC/fpc-3.2.2/compiler/ppcrossa64"
  [ -x "$FPC" ] || FPC="$(dirname "$(readlink -f "$(command -v fpc)")")/../lib/fpc/3.2.2/ppca64"
  # -no_fixup_chains: FPC 3.2.2 emits unaligned pointers (threadvar tables), which chained fixups reject
  # Without Xcode's iPhoneOS SDK only a compile check is possible (-Cn: no link)
  SDK="$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null || true)"
  TFLAGS=(-Tios -WP15.0 -k-no_fixup_chains -dKAM_GL4ES -k-lGL -k-framework -kOpenGLES ${SDK:+-XR"$SDK"} $([ -n "$SDK" ] || echo -Cn) -Fu"$TC/fpc-3.2.2/rtl/units/aarch64-ios")
  for p in $PKGS; do TFLAGS+=(-Fu"$TC/fpc-3.2.2/packages/$p/units/aarch64-ios"); done
  UNIVINT="$TC/fpc-3.2.2/packages/univint/units/aarch64-ios"
  if [ -n "$SDK" ]; then
    # Case-insensitive file lookup replaces libc's open/stat/... for the engine (see casefs.c)
    mkdir -p "$BUILD/deps"
    xcrun --sdk iphoneos clang -target arm64-apple-ios15.0 -isysroot "$SDK" -O2 -Wall -c "$IOS_DIR/casefs.c" -o "$BUILD/deps/casefs.o"
    TFLAGS+=(-k"$BUILD/deps/casefs.o")
  fi
else
  FPC="$(ls /opt/homebrew/lib/fpc/*/ppca64 | tail -1)"
  TFLAGS=(-Tdarwin -k-L/opt/homebrew/lib -XR"$(xcrun --sdk macosx --show-sdk-path)" -Fu"$(dirname "$FPC")/units/aarch64-darwin/rtl")
  for p in $PKGS; do TFLAGS+=(-Fu"$(dirname "$FPC")/units/aarch64-darwin/$p"); done
  UNIVINT="$(dirname "$FPC")/units/aarch64-darwin/univint"
fi

# PascalScript needs the aarch64 patch of the Android port; applied once to the submodule checkout
PS="$REPO/src/ext/pascalscript_submodule"
PSP="$REPO/android/toolchain/patches/pascalscript-aarch64.patch"
if git -C "$PS" apply --check "$PSP" 2>/dev/null; then git -C "$PS" apply "$PSP"; fi

# Clean build: incremental FPC 3.2.2 builds hit "Internal error 200611031" with generics
rm -rf "$BUILD/lazutils" "$BUILD/units"
mkdir -p "$BUILD/lazutils" "$BUILD/units" "$OUT"

cat > "$BUILD/lazutils/lazutils_all.pas" <<'PAS'
unit lazutils_all;
interface
uses LazUTF8, LConvEncoding, LazFileUtils, FileUtil, Laz2_DOM, Laz2_XMLRead, Laz2_XMLWrite, UTF8Process;
implementation
end.
PAS
"$FPC" "${TFLAGS[@]}" -Cg -MObjFPC -Scghi -O2 -g -gl -vew \
  -Fu"$LAZ" -Fi"$LAZ" -FU"$BUILD/lazutils" -Fu"$UNIVINT" "$BUILD/lazutils/lazutils_all.pas"

FU=(-Fu"$REPO/android/pascal" -Fu"$REPO/android/pascal/shims" -Fi"$REPO/android/pascal/shims")
for d in $(cd "$REPO/src" && find . -type d \
    -not -path './forms*' -not -path './ext/Virtual-TreeView*' -not -path './ext/BGRABitmap*' \
    -not -path './ext/Overbyte*' -not -path './ext/LazarusOpenGL*' -not -path './ext/pascalscript_submodule*' \
    -not -path './unused*' | sort); do
  FU+=(-Fu"$REPO/src/$d" -Fi"$REPO/src/$d")
done
FU+=(-Fu"$REPO/src/ext/pascalscript_submodule/Source" -Fi"$REPO/src/ext/pascalscript_submodule/Source")
# univint (MacOSAll for LazFileUtils) goes last: its Controls unit must not shadow our shim
FU+=(-Fu"$BUILD/lazutils" -Fu"$UNIVINT")

"$FPC" "${TFLAGS[@]}" -Cg -MDelphi -Sh -Sa \
  -dANDROID -dANDROID_PORT -dDBG_SKIP_SECURE_AUTH -dNO_MULTIPLAYER_UI \
  -Fi"$REPO" "${FU[@]}" \
  -FU"$BUILD/units" -FE"$OUT" -o"$OUT/libkamcore.dylib" \
  -k-L"$BUILD/deps" -k-lbass -k-lvorbisfile -k-lvorbis -k-logg -k-install_name -k@rpath/libkamcore.dylib \
  -O2 -g -gl -vewn -vm5023,5024,5025,5026,5027,5028,5057,5058,5059,5060,5089,5090,5091,5092,5093,6058,3123,3124,4055,4056,4079,4080,4081,4082,5036,5037,4035,4105,4104 \
  ${KAM_FPC_FLAGS:-} "$@" "$REPO/android/pascal/kamcore.lpr"
# The Xcode project (and the Mac smoke test) pick up every library from one folder
[ ! -f "$OUT/libkamcore.dylib" ] || cp -f "$OUT/libkamcore.dylib" "$BUILD/deps/"
