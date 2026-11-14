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
| Mac | `ios/run_mac.sh` | bundles the data into the app; `KAM_MOD=../mods/friendly ios/run_mac.sh` also bundles that mod (kept in sync on every start; a plain build removes it) |
| TestFlight | `ios/testflight.sh <build number>` | archives and uploads; see below if the upload fails |

PascalScript on ARM64: the `src/ext/pascalscript_submodule` checkout carries local changes (native aarch64 caller
and script method thunk). They are saved in `ios/patches/pascalscript-aarch64.patch`; on a fresh checkout apply it
inside the submodule with `git apply ../../../ios/patches/pascalscript-aarch64.patch`.

TestFlight upload: if `testflight.sh` archives fine but the upload stops with `exportArchive Failed to Use Accounts`
("App Store Connect access ... is required"), open the archive in Xcode (`open -a Xcode ios/build/KaM.xcarchive`)
and upload it from the Organizer (Distribute App > TestFlight & App Store). That worked for build 6 while the
command-line upload kept failing.

Videos: the game's `.avi` clips are played from `.mp4` files of the same name next to them (convert with ffmpeg).

App icon: put a 1024 x 1024 `icon-1024.png` into `ios/host/Assets.xcassets/AppIcon.appiconset/` (not tracked).

## Testing

- `KAM_SELFTEST=all ios/run_ipad.sh 540` starts every mission and map (see `android/pascal/KM_AndroidSelfTest.pas`).
- `KAM_TAPS="12:548,340;15:300,200"` taps those buffer pixels (native resolution, not UI units) at the given seconds after start.
- `KAM_LOG_INPUT=1` logs hardware key, mouse and wheel events.

## What differs from the Android port

- Game speed button next to the minimap, optional sidebar on the right (Options > Mods).
- Achievements (`src/game/KM_Achievements.pas`), reported to Game Center when the app is signed for it.
  The identifiers and icons are in `ios/gamecenter/`.
- Hardware keyboard and mouse; hold Space and move the pointer to pan the map. Right button: a secondary click
  (two-finger click on a trackpad), or Control/Option-click for a mouse or trackpad without one.
- The view keeps a landscape shape of at most 4:3; windows too small to play in show a hint instead.
  It stays inside the safe area on the left, top and right (Android: clear of a camera cutout).

## Touch and interface size (both ports, `android/pascal/KM_AndroidExports.pas`)

- In game the interface shrinks by up to 20% when that fits the whole sidebar (576 UI units, the desktop
  1024x576 minimum) on screen; otherwise (phones) the sidebar scrolls by drag or wheel and shows a scroll
  indicator on its right edge.
- A touch that lands next to a control (on a background or caption) goes to the nearest control within
  22 pt (iOS) / 24 dp (Android), so every control has a 44 pt / 48 dp touch area.
- Stacked rows cannot borrow space from a neighbour, so they get taller: Options check boxes, radio rows and
  the interface size list are 38 UI units apart (44 pt on an 11-inch iPad at 150%), in-game save/load list
  rows 32. The Options sections then no longer fit one screen: they scroll (drag, wheel or scroll bar) above a
  pinned Back button. Desktop builds keep 20.
- To see the phone-shaped sidebar scroll on a Mac, run the iPad app (`ios/run_mac.sh`), set Options >
  Interface size to 150% and drag the window wide and low, e.g. 1400x640 pt: the in-game UI is then 427 units
  tall, too far below 576 to shrink, and the sidebar scrolls with its indicator.
