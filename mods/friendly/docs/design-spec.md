> Original design spec for the Friendly Mod (Direction A), written before the mod was built. Kept as the design
> record. Where it differs from what shipped (sprite sizes, font folder, the 30x30 build plates, GUI 41 as a
> question mark, theme.ini), the mod's README.md is current.

# KaM Friendly Mod: final design and mod spec

The final design is on a new page, **"10 Final - Friendly Mod"**, in the Paper file "KaM Friendly Mod": https://app.paper.design/file/01M7CHEW8NZC2ZJDDR0A400JKE/p-5-0

I checked every artboard with a screenshot. I edited nothing in the repo and changed no other page. I also added 34 design tokens to the file (colours, font families and weights, type sizes, radii, pitches). Tokens apply to the whole file, but only this page uses them.

## 1. Paper artboards to look at

| Artboard | What it shows |
|---|---|
| **F1 Style tile** | Palette; type in all 8 font slots at real 1x size; faces per codepage; corners (mod vs code); build-icon plate colours |
| **F1b Controls and states** | Menu button states (normal, hover, pressed, disabled) as the engine draws them, plus a dashed box for the optional code version; sidebar tabs and Back; build button states; checkbox, slider, dropdown; hint and bevel panels |
| **F2 Main menu 1024×720 (mod only)** | Main menu as the mod alone renders it: square buttons with the engine's chamfered edges and a flat moss tile |
| **F3 Campaign list 1024×720 (mod only)** | Campaign page laid out from the coordinates in KM_GUIMenuCampaigns |
| **F4 Loading 1024×720 (mod only)** | Loading screen from KM_GUIMenuLoading |
| **F5 In game 1x · build + message** | 224 px sidebar with the build page, all 28 houses plus road, field, wine and erase, the message scroll and the clock |
| **F6 In game 1x · house panel + scroll tokens** | Sawmill house panel with ware rows, and the round message tokens #492, #491, #495 |
| **F7 / F8 In game 1.5x (1536×1080)** | F5 and F6 at UI scale 1.5, sidebar 336 px wide, map beside it |
| **F9 Ships as a mod vs needs code** | Mod file tree, a numbered list of code items, and the crisp-vs-stretched comparison |

**How the judge's grafts were applied:**
1. **Menu tile:** the menu tile is now flat. The square button with engine chamfer is the main mockup; the rounded version sits in a dashed "needs code" box.
2. **Fonts:** metal and outline are designed for 1-bit alpha: Fraunces Black with a hard 2 px walnut outline. antiqua uses Nunito Bold.
3. **House icons:** all 28 houses are drawn as pictures of each house's product or tool, plus the padlock and the wares.
4. **Icon plates:** each icon has its own plate colour by category: linen civic, moss food, honey materials, woad military, walnut for locked.
5. **mini:** raised from 8 to 10 px, and each base-height change is listed as a layout risk.
6. **Scroll icons:** they are now round tokens with a baked drop shadow.
7. **1.5x:** shown as full-height artboards with the map beside the sidebar.
8. **Lists:** there is a mod-file list and a numbered code list.

## 2. Fonts (all SIL Open Font License 1.1)

| Face | Source | Used for |
|---|---|---|
| Fraunces (variable: weight, opsz, SOFT, WONK) | https://github.com/undercasetype/Fraunces · https://fonts.google.com/specimen/Fraunces | metal, outline, logo wordmark |
| Nunito (variable weight) | https://github.com/googlefonts/nunito · https://fonts.google.com/specimen/Nunito | antiqua, game, grey, mini, arial (chat) |
| JetBrains Mono | https://github.com/JetBrains/JetBrainsMono | consolas8 (debug) |
| Noto Serif (Black) | https://github.com/notofonts/latin-greek-cyrillic | Cyrillic and Greek fallback for metal and outline (Fraunces is Latin only) |
| Noto Sans (Bold) | https://github.com/notofonts/latin-greek-cyrillic | Fallback for any codepoint Nunito lacks |
| Noto Sans CJK SC / JP / KR | https://github.com/notofonts/noto-cjk | chn, jpn, kor |

Arial (`arial.fntx`) and Consolas (`consolas8.fntx`) are not redistributable. Replacing them is part of the mod.

## 3. Font slots: new face and pixel sizes

The engine reads only `data/gfx/fonts/<slot>.fntx` (KM_ResFonts.pas:551-569). Each file carries every script. The per-codepage `.fnt` files are ignored and can stay as they are.

"Glyph px" is the rasterised size. "+N" is the outline baked around each glyph.

| Slot | Face and how it is baked | 1x | 1.5x | 2x | Base height (today → new) | Texture mode (unchanged) |
|---|---|---|---|---|---|---|
| metal | Fraunces Black 900, opsz 9, SOFT 50. Cream #FFF6DF fill, hard 2 px walnut #5B3A21 outline, no anti-aliasing, letter-spacing about +0.04 em | 14 +2 | 21 +3 | 28 +4 | 13 → 14 | RGB5A1 (colour baked in) |
| outline | Same cut as metal | 16 +2 | 24 +3 | 32 +4 | 14 → 16 | RGB5A1 |
| antiqua | Nunito Bold 700, ink #3A2A1C | 13 | 20 | 26 | **11 → 13** | RGB5A1 |
| game | Nunito Bold 700, white (tinted by the code) | 13 | 20 | 26 | 13 → 13 | Alpha8 |
| grey | Nunito ExtraBold 800, linen deep #E6D2A6, 1 px walnut-deep #4A2E18 outline | 13 +1 | 20 +1 | 26 +2 | 13 → 13 | RGB5A1 |
| mini | Nunito ExtraBold 800, white | 10 | 15 | 20 | **8 → 10** | Alpha8 |
| arial | Nunito SemiBold 600, anti-aliased | 12 | 18 | 24 | 11 → 12 | RGBA8 |
| consolas8 | JetBrains Mono Regular | 10 | 15 | 20 | 8 → 10 | RGBA8 |

**Faces and sizes per codepage** (from `data/locales.txt`):

| Codepage | Locales | Faces and sizes |
|---|---|---|
| 1250 | cze hun pol rom slv svk | Table above. Fraunces and Nunito both cover Latin Extended-A. |
| 1252 | eng ger fre dut ita spa ptb swe nor fin est | Table above |
| 1254 | tur | Table above |
| 1257 | lit | Table above |
| 1251 Cyrillic | rus ukr bel bul srb | Nunito covers it for the Nunito slots. metal and outline use Noto Serif Black at the same px (14 / 16), with the same baked colour and outline. |
| Unicode CJK | chn jpn kor | Noto Sans CJK. Black for metal and outline, Bold for the rest. Minimum 14 px at 1x (21 at 1.5x) for every slot; base height stays the Latin one. mini stays Latin only (353 glyphs today). |
| Greek and the rest | no locale today | Noto Serif Black (display slots) and Noto Sans Bold (body slots) for any other codepoint the current files contain. |

**Spacing:** start from today's WordSpacing and CharSpacing, then reduce CharSpacing by 1 on the outlined slots (metal 1 → 0, outline -2 → -3), because the outline already adds width. Check the result against the button heights: menu 30, tabs 36, flat 33, list rows 20.

**How to build the files.** Utils/FontX Generator needs Windows GDI and cannot apply the outline or the fallback stack. A short Python script with freetype-py does the job; the format is the one verified in the survey:
- Write a zlib stream: `'FNTX'`, BaseHeight u16, WordSpacing i16, CharSpacing i16, LineSpacing u8, `Used[65536]` u8.
- Then one 24-byte TKMLetter per used glyph: w, h u16; yOffset i16; atlasId u16; u1 v1 u2 v2 single.
- Then AtlasCount u8, TexSizeX/Y u16, and the raw RGBA atlases.
- For the RGB5A1 slots, render in FT mono mode, dilate the mask for the outline, bake the colours, and threshold alpha at 50%.
- Keep the 256×512 atlases.
- Copy the `Used[]` set from each current file so coverage does not shrink.

## 4. GUI sprites to repaint

Sprites are overridden with no code. LoadSprites scans `ExeDir/Modding graphics/` recursively for `<RXType+1>_<id>.png` (KM_ResSprites.pas:968-1010, :2116). A matching id replaces the original; a new id appends.
- Optional sidecars: `<id>a.png` (team-colour mask), `<id>m.png` (mask used as-is), `<id>.txt` (pivot).
- Any path containing "skip" is ignored.
- Get the originals and their exact sizes with F11 > Export Data > Resources. Keep each sprite the same pixel size.

**GUIMain.rxx (prefix `5_`), menus:**

| Id | New art |
|---|---|
| 4 | Logo: Fraunces wordmark "Knights & Merchants" with an oak ampersand and flourish |
| 5 / 6 | Crests become hanging banners: moss with a tower, oak with a wheat sheaf |
| 9 | bsMenu tile. **Flat moss #5D7E38, no baked light or lip.** The tile is sampled in screen space at 2 screen px per texel, so any detail would not line up with each button |
| 17 | Linen parchment with painted rolling hills and a small town |
| 18 | Torn burnt frame becomes a rounded honey-oak frame, radius 18, walnut inner line |

**GUI.rxx (prefix `4_`):**

| Id | New art |
|---|---|
| 402 | bsGame tile: flat oak-light #C99A5E. Same screen-space rule as GUIMain 9 |
| 404 | Sidebar planks, 224×400 tile, honey oak with walnut seams |
| 407 | Sidebar top 224×200: linen minimap frame, radius 12, walnut ring, plus the vine edge |
| 554 | Sidebar middle, 224×168, matching 407 and 404 |
| 439, 440, 441, 442 | Tab icons: hammer, scales, ledger, quill. Ink 2 px round strokes, one warm fill each, about 24 px |
| 443 | Back arrow, same style |
| 301-329 | The 28 build icons, 32 px. Each paints its own 30 px plate with 6 px corners and the house's product or tool in ink |
| 335, 336, 337, 340 | Road, wine, field, erase. Same plate style |
| 41 | Locked house: walnut plate with a linen padlock |
| 351-378 | Wares (351 + ware index; trunk 351, stone 352, timber 353 are the build costs), same ink style |
| 654, 655 | Construction stone and wood, 40×40 |
| 657-659 | Ware group icons |
| 37, 40 | House panel delivery-mode and repair buttons. 37 is a cart; 40 is a hammer with a green plus |
| 491, 492, 493, 495 | Message tokens by kind (text, house, group, quill; 495 is also the log), 30×48: a round 26 px token with a 2 px walnut ring and a baked drop below. House, text and group are honey; the log/quill token is linen |
| 494 | Chat token, 30×48, speech bubble, same style |
| 496 | Allies token, 30×48, woad with a shield |
| 409 | Message scroll, 600×500 (190 px shown): linen card, radius 18 on the top corners, 2 px walnut edge, inner tan line, dashed stitch |
| 52 | Close, 32×32: round linen button with an ink "x" |
| 556 | Clock, 67×65: honey bezel, linen face, walnut hands |
| 132 | Slider thumb. **Stretched in width**, so paint a plank with no corner detail: 2 px walnut edge, flat oak middle |
| 590 / 591 | Dropdown and scroll arrows: cream triangle with ink outline |

Two cautions for the engineer:
- **GUI #41 has two uses.** It is the locked-house icon, and also the "question mark" fallback for unknown wares (KM_ResWares.GetGUIIcon). The padlock shows in both places.
- **GUI.rxx uses team colours.** Keep `<id>a.png` masks on any sprite that shows the player colour.

**Optional:** bake the PNGs into GUI.rxx and GUIMain.rxx with Utils/RXXPacker for a faster load.

## 5. How to ship the mod

```
<ExeDir>/
  data/gfx/fonts/{metal,outline,antiqua,game,grey,mini,arial,consolas8}.fntx   (overwrite)
  Modding graphics/  4_####.png, 5_####.png  (+ optional ####a.png masks)
```

- **Fonts:** there is no override folder for fonts, so back up the originals before overwriting. Licence texts (OFL.txt for each face) go into the mod package.
- **Windows and desktop:** ExeDir is the game folder.
- **iPad and Mac:** ExeDir is the app's Documents folder (ios/host/main.m:667-681). The fonts arrive through the in-app data import. **`Modding graphics` does not** (main.m:678 copies only data, Campaigns, Maps, MapsMP, Music, Sounds, Tutorials). Until that changes, push the folder with ios/push_data.sh or devicectl.

## 6. Needs code (none of it blocks the mod; listed on F9)

1. **Import list:** add `Modding graphics` to the iPad import list in ios/host/main.m:678.
2. **Per-scale assets:** per-scale fonts and sprites (for example `data/gfx/fonts@1.5x/`, `Modding graphics@1.5x/`), chosen by the UI-scale work. Without this, 1.5x and 2x stretch the 1x atlases, and F7 and F8 assume this hook. Ship the 1.5x and 2x .fntx files at the sizes in the table.
3. **RGBA8 (optional):** switch metal, outline, antiqua and grey to RGBA8 in FONT_INFO (KM_ResFonts.pas:170-179). This design does not need it.
4. **Rounded buttons (Write3DButton, KM_RenderUI.pas:205-310):** 8 px corners, a lip on each button instead of the chamfer, a honey focus ring and a madder Quit. This needs a 9-slice or a mask, because the tile is sampled in screen space.
5. **Warm bevels:** WriteBevel in walnut at 62% instead of black at 50% (lists, memos, hints), and the hint drawn as a walnut pill. Today the campaign list (F3) reads grey because of the black 50%.
6. **Selection colours:**
   - Selected build button: 2 px honey ring instead of the 1 px white outline (TKMButtonFlat.Paint, KM_ControlsBase.pas:808).
   - List selection: honey instead of 50% grey with a white outline (the ic*/cl* colours, KM_Defaults.pas:985+).
7. **Small items:**
   - The checkbox draws the font's "x" glyph (KM_ControlsSwitch.pas:212); a tick sprite would need code.
   - Chat unread-count colour.

**Layout risks to test with the new fonts:**
- antiqua 11→13: the message text box is 432×112 and briefings sit in memos.
- mini 8→10: progress bars and the replay bar.
- metal now has a +2 px outline: check menu buttons (30 px), the slider thumb width and the checkbox box size, which follows the font height.

---
I did not check the exact pixel sizes of GUIMain 4, 5, 6, 9, 17, 18 or of the GUI 132, 590, 591 and 351-378 sprites: export the originals first. I also did not verify that Fraunces covers every 1250, 1254 and 1257 character.

Accuracy risks in the mockups:
- The 1.5x artboards use Paper zoom, which stands in for atlases rendered at 1.5x.
- The outlined text is drawn with text-shadow, so the final 1-bit look depends on the generator script.
- The road/field/wine/erase plates still carry Direction B's colours; the erase plate is off-palette pink.