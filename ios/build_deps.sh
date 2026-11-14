#!/bin/bash
# Builds the native libraries the iPad app embeds, into ios/build/ios/deps (needs Xcode, cmake, ninja):
#   libGL.a          gl4es: the engine's desktop OpenGL on top of OpenGL ES 2, linked statically into the engine
#   libopenal.dylib  OpenAL Soft (Apple's OpenAL lacks thread-local contexts the music player relies on)
#   libbass.dylib    BASS API subset from android/native/bass_android.c, with ogg/vorbis linked in
#   libogg.a libvorbis.a libvorbisfile.a  also linked into the engine for sound effects
set -euo pipefail
# xcode-select may still point at the command line tools
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
IOS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$IOS_DIR/.." && pwd)"
TC="${KAM_TOOLCHAIN:-$REPO/toolchain}"
OUT="$IOS_DIR/build/ios/deps"
PREFIX="$IOS_DIR/build/ios/prefix"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
MIN=15.0
mkdir -p "$OUT" "$PREFIX"
LOG="$IOS_DIR/build-deps.log"
: > "$LOG"

clone() { [ -d "$TC/$2" ] || git clone -q --depth 1 --branch "$3" "$1" "$TC/$2"; }
clone https://github.com/kcat/openal-soft.git openal-soft 1.24.3
clone https://github.com/xiph/ogg.git libogg v1.3.5
clone https://github.com/xiph/vorbis.git libvorbis v1.3.7
if [ ! -d "$TC/gl4es" ]; then
  git clone -q https://github.com/ptitSeb/gl4es.git "$TC/gl4es"
  git -C "$TC/gl4es" checkout -q a025615bc79ac43ec911dced8fe5b8eb45a0b72d
fi
# Same gl4es fixes as the Android port (active texture unit after stippled lists)
git -C "$TC/gl4es" apply --check "$REPO/android/toolchain/patches/gl4es-android-host-context.patch" 2>/dev/null \
  && git -C "$TC/gl4es" apply "$REPO/android/toolchain/patches/gl4es-android-host-context.patch"
# Mach-O has no symbol aliases
git -C "$TC/gl4es" apply --check "$IOS_DIR/patches/gl4es-apple.patch" 2>/dev/null \
  && git -C "$TC/gl4es" apply "$IOS_DIR/patches/gl4es-apple.patch"

COMMON=(-Wno-dev -G Ninja -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=$MIN
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_FIND_ROOT_PATH="$PREFIX" -DCMAKE_POLICY_VERSION_MINIMUM=3.5
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO -DCMAKE_MACOSX_BUNDLE=OFF)
b() { local src=$1; shift; [ ! -f "$IOS_DIR/build/ios/done-$src" ] || return 0; rm -rf "$IOS_DIR/build/ios/cmake-$src"
  cmake -S "$TC/$src" -B "$IOS_DIR/build/ios/cmake-$src" "${COMMON[@]}" "$@" > /dev/null
  ninja -C "$IOS_DIR/build/ios/cmake-$src" "${NINJA_TARGET:-install}" >> "$LOG" 2>&1 || { grep -E "error|FAILED" -A4 "$LOG" | tail -40; exit 1; }
  touch "$IOS_DIR/build/ios/done-$src"; }

b libogg -DBUILD_SHARED_LIBS=OFF -DINSTALL_DOCS=OFF -DBUILD_TESTING=OFF
b libvorbis -DBUILD_SHARED_LIBS=OFF -DOGG_INCLUDE_DIR="$PREFIX/include" -DOGG_LIBRARY="$PREFIX/lib/libogg.a"
b openal-soft -DLIBTYPE=SHARED -DALSOFT_UTILS=OFF -DALSOFT_EXAMPLES=OFF -DALSOFT_TESTS=OFF -DALSOFT_INSTALL_CONFIG=OFF \
  -DALSOFT_INSTALL_HRTF_DATA=OFF -DALSOFT_INSTALL_AMBDEC_PRESETS=OFF -DALSOFT_EMBED_HRTF_DATA=OFF
NINJA_TARGET=GL b gl4es -DNOX11=ON -DNOEGL=ON -DNO_LOADER=ON -DNO_INIT_CONSTRUCTOR=ON -DSTATICLIB=ON

cp -f "$PREFIX"/lib/libogg.a "$PREFIX"/lib/libvorbis.a "$PREFIX"/lib/libvorbisfile.a "$OUT/"
cp -fL "$PREFIX"/lib/libopenal.dylib "$OUT/libopenal.dylib"
cp -fL "$(find "$TC/gl4es/lib" "$IOS_DIR/build/ios/cmake-gl4es" -name 'libGL*.a' | head -1)" "$OUT/libGL.a"
install_name_tool -id @rpath/libopenal.dylib "$OUT/libopenal.dylib"

xcrun --sdk iphoneos clang -target arm64-apple-ios$MIN -isysroot "$SDK" -O2 -dynamiclib -fvisibility=hidden -Wall -Wno-unused-function \
  -I"$TC/minimp3" -I"$PREFIX/include" -o "$OUT/libbass.dylib" "$REPO/android/native/bass_android.c" \
  -L"$OUT" -lopenal -lvorbisfile -lvorbis -logg -install_name @rpath/libbass.dylib
ls -la "$OUT"
