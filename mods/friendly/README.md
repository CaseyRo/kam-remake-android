# KaM Friendly Mod ("Direction A - Warm storybook")

A visual mod for KaM Remake: warm linen, oak and moss menus and in-game interface, in place of the dark stone look.
It replaces GUI sprites and fonts and sets the engine's UI colours (`theme.ini`). Game rules are unchanged, and
without the mod installed the game looks as before. Design source: the Paper file "KaM Friendly
Mod", page "10 Final - Friendly Mod"; the full spec is `kam-friendly-mod-spec.md`.

## What it changes

| Area | Sprites (archive_id) |
|---|---|
| Main menu: logo, two banners, menu button tile, backdrop, frame | 5_4, 5_5, 5_6, 5_9, 5_17, 5_18 |
| Results screen backdrop (a wooden hall with a dark hanging behind the chart), locked campaign mission | 5_7, 5_10 |
| Sidebar, game tile, message scroll, close button, slider, arrows, tab icons, back arrow | 4_402, 404, 407, 554, 409, 52, 132, 590, 591, 439-443 |
| Pause/end clock, all 16 animation frames; win and defeat emblems for the play-more prompt | 4_556-571, 572, 573 |
| Build menu: 29 house icons, road/field/wine/erase, "?" (unknown/locked) | 4_301-329, 335-337, 340, 41 |
| Wares, construction stone/wood, ware groups | 4_351-378, 654, 655, 657-659 |
| House actions: hand cart (accept, closed, take out), repair on and off | 4_37, 38, 664, 39, 40 |
| Message tokens (text, house, group, chat, log, allies) | 4_491-496 |

The sidebar planks (404, 407, 554) are plain boards with soft seams and no butt joints: the build, stats and
house grids are translucent and sit on 404, so anything busier shows through the buttons. They carry only a faint,
generated wood grain (see Texture below).

**Texture:** the map is dithered 1998 pixel art, so the flat surfaces carry a quiet, generated texture
(`tools/texture_pass.py`): wood grain and a few soft knots on the planks (404, 407, 554), the game button face (402)
and the results hall (5_7); paper fibres on the parchment (5_17, 5_18) and a linen weave on the message scroll
(409); uniform grain only on the menu button tile 5_9, because the engine samples it in screen space; worn edges on
the plates. The texture is zero-mean: each surface keeps its mean luminance within 1.1% and every 12 px block within
5.5%, so label contrast is unchanged (cream on 5_9 5.3:1, ink on 402 5.3:1).

**Win and defeat emblems** (4_572 laurel, 4_573 lowered banner) are drawn only when `theme.ini` points the play-more
prompt at them (`PlayMoreWin=572`, `PlayMoreLose=573`); without the keys the prompt shows the clock 556 as before.
572 and 573 are empty slots in GUI.rxx (r16397).

The menu button tile 5_9 is flat moss #526F31, one step darker than the palette's moss #5D7E38, so the cream button
captions measure 5.6:1 on it (4.5:1 or better even where a screen capture renders the green a little lighter).

**Theme:** `Modding graphics/theme.ini` sets the engine's UI colours (panels, disabled text, selection, checkbox)
and can switch off decoration the mod's layout does not want; each key is explained in the file. The engine reads it
at startup (`KM_ResTheme.pas`); without it, or for any key it leaves out, the engine keeps its own value.

**Fonts:** all 8 game font slots are replaced, in `Modding graphics/fonts/*.fntx`: Fraunces Black with a 2 px rim
for outline (titles), Fraunces SemiBold with a 1 px rim for metal (buttons, labels, checkboxes, so a page of options
reads calmly), Nunito for the body slots, JetBrains Mono for the debug font, Noto for Cyrillic/Greek/CJK. Every
original glyph set is kept. The engine (`KM_ResFonts.FontPath`) loads a slot from `Modding graphics/fonts/` when the
file is there, else `data/gfx/fonts/` as before, so the game's own fonts are never overwritten.

On the touch hosts (iPad, Mac app, Android) the engine picks a denser set for a large UI scale, so text is not a
magnified 1x bitmap: `fonts@1.5x/` from 1.4 buffer px per UI unit (an iPad at 70% interface size or more, the
default 150% too), `fonts@2x/` from 3.5. Both are filtered linearly, and a missing set falls back to the next one
below. The hi-res files keep 1x metrics, so layout is unchanged. Changing Options > Interface size reloads the fonts
on the next frame. Windows and desktop builds always load the 1x set. `fonts@2x/` is not in git (37 MB, no iPad reaches 3.5): build it with `--scale 2` if needed.

## Install

Install the mod by copying its whole `Modding graphics/` folder, subfolders included: it carries the sprite PNGs,
the fonts (`fonts/`, `fonts@1.5x/`) and the theme settings (`theme.ini`). Nothing in the game's `data/` folder is
replaced: for anything the folder does not have, the engine uses the game's own data.

The engine loads any `Modding graphics/<archive>_<id>.png` from its data folder (ExeDir) over the built-in sprite
(`KM_ResSprites.pas`, `OverloadRXDataFromFolder`). `4_` is GUI.rxx, `5_` is GUIMain.rxx; zero padding is optional.
To uninstall, delete the `Modding graphics/` folder.

**Windows and desktop:** copy `Modding graphics/` into the game folder, next to `data/`.

**iPad and Mac app:** ExeDir is the app's Documents folder. Put `Modding graphics/` into a copy of your KaM Remake
game folder, then pick that folder in the app's data import: since build 5 it copies `Modding graphics` along with the game folders.
`ios/push_data.sh` does the same for a connected iPad when `KAM_DATA` points at that folder. To push only the
mod (sprites and fonts) to an iPad that already has the game data:

```
cd ~/dev/kam_ipad && . ios/local.env && xcrun devicectl device copy to --device "<iPad>" --domain-type appDataContainer --domain-identifier "$KAM_BUNDLE_ID" --source "mods/friendly/Modding graphics" --destination "Documents/Modding graphics"
```

**Mac smoke test (mactest):** use a cloned data folder, not the real one:

```
cp -c -R ios/build/darwin/data /tmp/moddata && cp -R mods/friendly/"Modding graphics"/ /tmp/moddata/"Modding graphics"/
cd ios/build/darwin && ./mactest /tmp/moddata "only:campaign tpr" 100000   # results: /tmp/moddata/Logs/selftest.txt
```

The Mac test window has density 1, so its UI scale stays below 1.4 and it loads the 1x fonts. To see the iPad's
hi-res path there, force a set with `KAM_FONT_SET=1` (`@1.5x`; `2` for `@2x`, `0` for 1x) in front of `./mactest`.
`Logs/` then lists each font file loaded (`Font metal: .../fonts@1.5x/metal.fntx`).

## Rebuilding

Run the scripts with `tools/.venv/bin/python` (Pillow). To set up the venv: `uv venv tools/.venv && uv pip install --python tools/.venv pillow numpy`.

- `tools/rxx_export.py`: reads GUI.rxx and GUIMain.rxx and writes the original sprites, pivots and `manifest.json`
  (sizes and new-art notes) to `_originals/` (reference only, not shipped). With arguments
  `ARCHIVE PREFIX OUTDIR ID...` it exports any other ids.
- Art is painted in Paper on the pages "20 Sprites - menu / chrome / build / wares", one artboard per sprite at the
  original pixel size with a transparent background, and exported at 1x.
- `tools/p3_to_srgb.py`: Paper exports in Display P3; run it on every new export, or colours shift in game.
- `tools/wares_install.py`: moves the newest wares exports from ~/Downloads into `Modding graphics/` and checks sizes.
- `tools/build_icons_html.py` and `tools/build_icons_sheet.py`: HTML plates for the build icons, and the contact sheet.
- `tools/clock_frames.py`: after 4_0556.png changes, redraws frames 557-571 with the hand turned 22.5 degrees each.
- `tools/calm_planks.py`: after 404, 407 or 554 is re-exported, repaints their planks as plain boards with soft seams
  (keeps the vine strip, minimap frame, sign and ropes). Safe to run twice. Run `texture_pass.py` after it.
- `tools/texture_pass.py`: adds the texture to 402, 404, 407, 409, 554, 5_7, 5_9 and 5_18 (5_17 comes from `backdrop_tile.py`) in place, with fixed
  seeds, and prints each surface's luminance before and after (`--check` only reports). A textured PNG carries the
  text chunk `friendly-texture`, so the script skips it on a second run; run it after every new Paper export of those
  sprites (exports come back flat).
- `tools/backdrop_tile.py`: draws the menu backdrop 5_17 as a seamlessly tiling linen surface. The engine tiles
  this sprite to fill the screen, so a scene shows hard bands in large windows; the hills live in the card 5_18.
  It writes the `friendly-texture` chunk, so `texture_pass.py` leaves it alone.
- `tools/locked_banner.py`: draws 5_10 (locked mission) from the unlocked banner 5_11 in `_originals/`: same
  silhouette, linen and walnut at 58% opacity, a small padlock. `_originals/` is not in git: export 5_11 first with
  `tools/rxx_export.py <game>/data/Sprites/GUIMain.rxx 5 _originals 11`.
- Keep every PNG at the original's width and height (`_originals/manifest.json`), except the build icons 301-329
  and 335-337, 340, which are uniform 30x30 plates. GUI pictures are drawn centred by their pixel size
  (`TKMRenderUI.WritePicture`) and ignore the pivot, so a size change needs no `.txt`. None of these sprites has a
  team-colour mask, so no `a.png` files are needed. A pivot override would be `4_<id>.txt` (X, then Y).
- Fonts: `tools/.venv/bin/python tools/gen_fonts.py [--scale 1|1.5|2|all] [--only metal,grey] [--sheets]` rebuilds
  them from `tools/downloads/` into `Modding graphics/fonts/`, `fonts@1.5x/` and `fonts@2x/` (faces, sizes, colours
  and spacing are in the SLOTS table). `tools/fntx.py FILE --roundtrip` checks a file.

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
- **5_6 (wheat banner) is also drawn behind the Options language list** (`KM_GUICommonOptions`, the same stretched
  rect as the main menu: 705,220, 269x383). The language panel covers that rect completely, so no placement inside
  the sprite clears it; the theme key `OptionsBanner=0` in `theme.ini` tells the engine to leave it out there.
- **iPad display corners and the sidebar frame (407):** the minimap frame's walnut rim starts 2 px from the sidebar's
  top-left corner with a 14 px outer radius. Measured against iPad corner radii (18 pt; 21.5 pt on iPad mini), no
  pixel of the frame is clipped at the default 150% interface size or anywhere from 125% up; at 100% only the iPad
  mini cuts a sub-point sliver of the rim's anti-aliasing, and at 50-75% the rim's corner arc is visibly trimmed. Not
  checked on a device. Moving the frame inward would uncover the minimap's square corners, so the art stays as approved.
- **5_18 is also the background of map-editor forms and the single-player results panel**, so its hills appear there too.
  The village silhouette is hidden in 5_18 (it sat behind list rows and the 'Weapons produced' value); 5_17 keeps it.
- The speed button ("x1") next to the minimap is not repainted. The house worker button shows the unit's own
  pixel icon, and the house action buttons keep the engine's 3D button face (402).
- **The results backdrop 5_7 is dimmed 63% by the engine** (a black shape over it, `KM_GUIGameResultsSP`), so it reads
  as a dusky hall; the hanging behind the chart stays near black for the chart lines.
- Not seen in game this round: the texture, 5_7, 5_10, the house icons and the emblems were checked only on contact
  sheets (`~/Desktop/kam-design-texture-before-after.png`).
- Code items from spec section 6, not done here: per-scale sprites for 1.5x and 2x UI, RGBA8 for
  the outlined fonts (optional), rounded buttons (Write3DButton), warm bevels and chat colours. Panel, selection,
  disabled-text and checkbox colours are done through `theme.ini`.
  Until per-scale sprites exist, the 1x sprite art is stretched at 1.5x and 2x UI scale (fonts have their own sets).
