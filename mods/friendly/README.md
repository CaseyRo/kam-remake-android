# KaM Friendly Mod ("Direction A - Warm storybook")

A visual mod for KaM Remake: warm linen, oak and moss menus and in-game interface, in place of the dark stone look.
It replaces GUI sprites only. Engine code and game rules are unchanged. Design source: the Paper file "KaM Friendly
Mod", page "10 Final - Friendly Mod"; the full spec is `kam-friendly-mod-spec.md`.

## What it changes

| Area | Sprites (archive_id) |
|---|---|
| Main menu: logo, two banners, menu tile, backdrop, frame | 5_4, 5_5, 5_6, 5_9, 5_17, 5_18 |
| Sidebar, game tile, message scroll, close button, slider, arrows, tab icons, back arrow | 4_402, 404, 407, 554, 409, 52, 132, 590, 591, 439-443 |
| Pause/end clock, all 16 animation frames | 4_556-571 |
| Build menu: 29 house icons, road/field/wine/erase, "?" (unknown/locked) | 4_301-329, 335-337, 340, 41 |
| Wares, construction stone/wood, ware groups, delivery, repair | 4_351-378, 654, 655, 657-659, 37, 40 |
| Message tokens (text, house, group, chat, log, allies) | 4_491-496 |

**Fonts:** all 8 game font slots are replaced (`data/gfx/fonts/*.fntx`): Fraunces for metal/outline, Nunito for
the body slots, JetBrains Mono for the debug font, Noto for Cyrillic/Greek/CJK. Every original glyph set is kept.
`fonts@1.5x/` and `fonts@2x/` are pre-built for a future engine hook that picks fonts per UI scale.

## Install

The engine loads any `Modding graphics/<archive>_<id>.png` from its data folder (ExeDir) over the built-in sprite
(`KM_ResSprites.pas`, `OverloadRXDataFromFolder`). `4_` is GUI.rxx, `5_` is GUIMain.rxx; zero padding is optional.
To uninstall, delete those PNGs.

**Windows and desktop:** copy `Modding graphics/` into the game folder, next to `data/`.

**iPad and Mac app:** ExeDir is the app's Documents folder. Put `Modding graphics/` (and the mod's
`data/gfx/fonts/*.fntx` over the game's `data/gfx/fonts/`) into a copy of your KaM Remake game folder, then pick that
folder in the app's data import: since build 5 it copies `Modding graphics` along with the game folders.
`ios/push_data.sh` does the same for a connected iPad when `KAM_DATA` points at that folder. To push only the
sprites to an iPad that already has the game data:

```
cd ~/dev/kam_ipad && . ios/local.env && xcrun devicectl device copy to --device "<iPad>" --domain-type appDataContainer --domain-identifier "$KAM_BUNDLE_ID" --source "mods/friendly/Modding graphics" --destination "Documents/Modding graphics"
```

**Mac smoke test (mactest):** use a cloned data folder, not the real one:

```
cp -c -R ios/build/darwin/data /tmp/moddata && cp mods/friendly/"Modding graphics"/* /tmp/moddata/"Modding graphics"/
cd ios/build/darwin && ./mactest /tmp/moddata "only:campaign tpr" 100000   # results: /tmp/moddata/Logs/selftest.txt
```

## Rebuilding

Run the scripts with `tools/.venv/bin/python` (Pillow). To set up the venv: `uv venv tools/.venv && uv pip install --python tools/.venv pillow`.

- `tools/rxx_export.py`: reads GUI.rxx and GUIMain.rxx and writes the original sprites, pivots and `manifest.json`
  (sizes and new-art notes) to `_originals/` (reference only, not shipped). With arguments
  `ARCHIVE PREFIX OUTDIR ID...` it exports any other ids.
- Art is painted in Paper on the pages "20 Sprites - menu / chrome / build / wares", one artboard per sprite at the
  original pixel size with a transparent background, and exported at 1x.
- `tools/p3_to_srgb.py`: Paper exports in Display P3; run it on every new export, or colours shift in game.
- `tools/wares_install.py`: moves the newest wares exports from ~/Downloads into `Modding graphics/` and checks sizes.
- `tools/build_icons_html.py` and `tools/build_icons_sheet.py`: HTML plates for the build icons, and the contact sheet.
- `tools/clock_frames.py`: after 4_0556.png changes, redraws frames 557-571 with the hand turned 22.5 degrees each.
- Keep every PNG at the original's width and height (`_originals/manifest.json`), except the build icons 301-329
  and 335-337, 340, which are uniform 30x30 plates. GUI pictures are drawn centred by their pixel size
  (`TKMRenderUI.WritePicture`) and ignore the pivot, so a size change needs no `.txt`. None of these sprites has a
  team-colour mask, so no `a.png` files are needed. A pivot override would be `4_<id>.txt` (X, then Y).
- Fonts: `tools/.venv/bin/python tools/gen_fonts.py [--scale 1|1.5|2] [--only metal,grey] [--sheets]` rebuilds them
  from `tools/downloads/` (sizes, colours and spacing are in the SLOTS table). `tools/fntx.py FILE --roundtrip` checks
  a file. Fonts have no override folder: installing overwrites `data/gfx/fonts/*.fntx`, so back up the originals.

## Licences

The sprite art is original work made for this mod. The fonts (Fraunces, Nunito, JetBrains Mono, Noto) are
all SIL OFL 1.1; their licence texts are in `licenses/` and ship with the mod.

## Checked (Mac, mactest, 14 Nov 2026)

- All 148 campaign missions pass the self-test with the mod loaded (`only:campaign`), and the logs show no errors.
- The main menu, sidebar, tab icons, message tokens, clock and dialog buttons render in the right places.

## Known gaps

- **Font layout risks:** accented capitals now reach above the line top (clipped list rows may cut them), list rows
  (20 px) are tight for game/grey, and mini grew 8 -> 10 px and antiqua 11 -> 13 px (message box, progress bars).
  Only the main menu and mission start were checked in the engine.
- **Build menu, ware icons and the message scroll were not seen in game.** The self-test cannot open menus. They
  are checked only for size and against contact sheets.
- **GUI 41 is a walnut "?" plate** (14x18), because the game also uses it for "unknown": school WIP, market,
  stats, ratios and the map-editor tab. Locked houses show the same "?". The Paper mock-up F5 still draws padlocks there.
- **5_18 is also the background of map-editor forms and the single-player results panel**, so its hills appear there too.
- 37 (delivery) has related state sprites (probably 38 and 39) that still show the old art. The speed button
  ("x1") next to the minimap is not repainted either.
- Code items from spec section 6, not done here: per-scale assets for 1.5x and 2x UI, RGBA8
  fonts, rounded buttons (Write3DButton), warm bevels, selection colours, and the checkbox tick and chat colours.
  Until per-scale assets exist, the 1x art is stretched at 1.5x and 2x UI scale.
