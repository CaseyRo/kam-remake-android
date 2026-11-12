# KaM Remake for iPad (and Apple-silicon Macs)

An iOS host for the KaM Remake engine, built on the Android port in this repository: the same Pascal engine
(`android/pascal/kamcore.lpr`, compiled with Free Pascal for `aarch64-ios`) behind a small UIKit app (`host/main.m`).
The engine draws through gl4es into an OpenGL ES view. On an Apple-silicon Mac the same build runs as a
"Designed for iPad" app.

**Game data is not included.** You need your own copy of *Knights and Merchants: The Peasants Rebellion* and the
KaM Remake installer; see `android/README.md` for how the data folders are extracted.

## Build

Needs Xcode, `brew install fpc xcodegen cmake ninja ffmpeg`, and the Lazarus sources in `toolchain/lazarus`
(as for the Android port).

| Step | Command | Notes |
|---|---|---|
| FPC runtime for iOS | `ios/setup_fpc.sh` | once |
| Native libraries | `ios/build_deps.sh` | once: gl4es, OpenAL Soft, ogg/vorbis, BASS shim |
| Signing | copy `ios/local.env.example` to `ios/local.env` | your team ID and bundle ID |
| Engine | `ios/build_engine.sh` | about 90 seconds |
| iPad | `ios/run_ipad.sh [seconds]` | builds, installs, runs with the console in `ios/run-ipad.log` |
| Game data to the iPad | `ios/push_data.sh` | once per install |
| Mac | `ios/run_mac.sh` | bundles the data into the app |

Videos: the game's `.avi` clips are played from `.mp4` files of the same name next to them (convert with ffmpeg).

App icon: put a 1024 x 1024 `icon-1024.png` into `ios/host/Assets.xcassets/AppIcon.appiconset/` (not tracked).

## Testing

- `KAM_SELFTEST=all ios/run_ipad.sh 540` starts every mission and map (see `android/pascal/KM_AndroidSelfTest.pas`).
- `KAM_TAPS="12:548,340;15:300,200"` taps game coordinates at the given seconds after start.
- `KAM_LOG_INPUT=1` logs hardware key, mouse and wheel events.

## What differs from the Android port

- Game speed button next to the minimap, optional sidebar on the right (Options > Mods).
- Achievements (`src/game/KM_Achievements.pas`), reported to Game Center when the app is signed for it.
  The identifiers and icons are in `ios/gamecenter/`.
- Hardware keyboard and mouse; hold Space and move the pointer to pan the map.
- The view keeps a landscape shape of at most 4:3; windows too small to play in show a hint instead.
