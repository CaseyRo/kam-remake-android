#!/bin/bash
# Builds the Free Pascal 3.2.2 runtime and packages for aarch64-ios into toolchain/fpc-3.2.2 (once, a few minutes).
# Same sources as android/toolchain/setup_toolchain.sh; needs `brew install fpc`.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
TC="${KAM_TOOLCHAIN:-$REPO/toolchain}"
mkdir -p "$TC"
if [ ! -d "$TC/fpc-3.2.2" ]; then
  curl -fsSL "https://gitlab.com/freepascal.org/fpc/source/-/archive/release_3_2_2/source-release_3_2_2.tar.gz" | tar -xz -C "$TC"
  mv "$TC/source-release_3_2_2" "$TC/fpc-3.2.2"
fi
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
make -C "$TC/fpc-3.2.2" -j"$(sysctl -n hw.ncpu)" crossall OS_TARGET=ios CPU_TARGET=aarch64 \
  OPT="-Fl$SDKROOT/usr/lib" PP="$(command -v fpc)" > "$TC/fpc-build.log" 2>&1 || { tail -30 "$TC/fpc-build.log"; exit 1; }
ls -d "$TC/fpc-3.2.2/rtl/units/aarch64-ios" && echo "FPC iOS runtime ready"
