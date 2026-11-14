unit KM_ResTheme;
{$I KaM_Remake.inc}
interface
uses
  KM_CommonTypes;

type
  // UI colours the engine draws by code instead of from sprites.
  // A mod can override them with 'Modding graphics/theme.ini'; with no file every value is the engine's own.
  TKMUITheme = record
    BevelColor: TKMColor3f;   // Fill of the engine's black panels (WriteBevel in black: lists, memos, hints, option groups)
    BevelEdge: TKMColor3f;    // Their dark top-left edge
    BevelAlphaPow: Single;    // Panel density: alpha' = 1 - (1 - alpha)^Pow keeps 0 and 1; 1 = unchanged
    TextDisabled: Cardinal;   // Tint for disabled captions; 0 = each control's own grey
    Hover: Cardinal;          // Wash over a flat button under the cursor
    DownOutline: Cardinal;    // Ring around a pressed / selected flat button
    DownOutlineWidth: Byte;
    TickMark: Boolean;        // Checkbox tick and radio dot drawn by code instead of the font's 'x'
    TickColor: Cardinal;      // Colour of that tick / dot when enabled
    OptionsBanner: Boolean;   // Main-menu Options page draws the GUIMain 6 banner behind the language list
  end;

const
  UI_THEME_DEFAULT: TKMUITheme = (
    BevelColor: (R: 0; G: 0; B: 0);
    BevelEdge: (R: 0; G: 0; B: 0);
    BevelAlphaPow: 1;
    TextDisabled: 0;
    Hover: $40FFFFFF;
    DownOutline: $FFFFFFFF;
    DownOutlineWidth: 1;
    TickMark: False;
    TickColor: $FFFFFFFF;
    OptionsBanner: True
  );

var
  gUITheme: TKMUITheme;

  procedure LoadUITheme(const aFileName: string);
  function ThemedBevelAlpha(aAlpha: Single): Single;
  function ThemedDisabledText(aDefault: Cardinal): Cardinal;
  function ParseThemeColor(const aText: string; out aColor: Cardinal): Boolean;


implementation
uses
  Classes, SysUtils, Math,
  KM_Defaults, KM_Log;


function ThemedBevelAlpha(aAlpha: Single): Single;
begin
  if (gUITheme.BevelAlphaPow = 1) or (aAlpha <= 0) or (aAlpha >= 1) then
    Result := aAlpha
  else
    Result := 1 - Power(1 - aAlpha, gUITheme.BevelAlphaPow);
end;


function ThemedDisabledText(aDefault: Cardinal): Cardinal;
begin
  if gUITheme.TextDisabled <> 0 then
    Result := gUITheme.TextDisabled
  else
    Result := aDefault;
end;


// '#RRGGBB' or '#RRGGBBAA' to the engine's $AABBGGRR
function ParseThemeColor(const aText: string; out aColor: Cardinal): Boolean;
var
  I, b: Integer;
  bytes: array [0..3] of Integer;
begin
  Result := False;
  aColor := 0;
  if not ((Length(aText) in [7, 9]) and (aText[1] = '#')) then Exit;

  bytes[3] := 255;
  for I := 0 to (Length(aText) - 1) div 2 - 1 do
  begin
    b := StrToIntDef('$' + Copy(aText, 2 + I * 2, 2), -1);
    if b < 0 then Exit;
    bytes[I] := b;
  end;

  aColor := Cardinal(bytes[0]) or (Cardinal(bytes[1]) shl 8) or (Cardinal(bytes[2]) shl 16) or (Cardinal(bytes[3]) shl 24);
  Result := True;
end;


procedure LoadUITheme(const aFileName: string);
var
  sl: TStringList;
  I, p, code: Integer;
  line, key, value: string;
  col: Cardinal;
  f: Single;
  ok: Boolean;
begin
  gUITheme := UI_THEME_DEFAULT;
  if not FileExists(aFileName) then Exit;

  sl := TStringList.Create;
  try
    sl.LoadFromFile(aFileName);
    for I := 0 to sl.Count - 1 do
    begin
      line := Trim(sl[I]);
      p := Pos('=', line);
      if (line = '') or (line[1] = ';') or (line[1] = '[') or (p = 0) then Continue;

      key := LowerCase(Trim(Copy(line, 1, p - 1)));
      value := Trim(Copy(line, p + 1, MaxInt));
      ok := True;

      if key = 'bevelalpha' then
      begin
        // The alpha the engine's default panel (0.5) should get; every other alpha follows the same curve
        Val(value, f, code);
        ok := (code = 0) and (f > 0) and (f < 1);
        if ok then gUITheme.BevelAlphaPow := Ln(1 - f) / Ln(0.5);
      end else
      if key = 'selectoutlinewidth' then
      begin
        Val(value, p, code);
        ok := (code = 0) and InRange(p, 1, 4);
        if ok then gUITheme.DownOutlineWidth := p;
      end else
      if key = 'checkmark' then
      begin
        ok := SameText(value, 'tick') or SameText(value, 'x');
        if ok then gUITheme.TickMark := SameText(value, 'tick');
      end else
      if key = 'optionsbanner' then
      begin
        ok := (value = '0') or (value = '1');
        if ok then gUITheme.OptionsBanner := value = '1';
      end else
      begin
        ok := ParseThemeColor(value, col);
        if ok then
          if key = 'bevelcolor'                     then gUITheme.BevelColor := TKMColor3f.NewB(col and $FF, col shr 8 and $FF, col shr 16 and $FF) else
          if key = 'beveledge'                      then gUITheme.BevelEdge := TKMColor3f.NewB(col and $FF, col shr 8 and $FF, col shr 16 and $FF) else
          if key = 'textdisabled'                   then gUITheme.TextDisabled := col else
          if key = 'hover'                          then gUITheme.Hover := col else
          if key = 'selectoutline'                  then gUITheme.DownOutline := col else
          if key = 'checkcolor'                     then gUITheme.TickColor := col else
          if key = 'checkboxoutline'                then clChkboxOutline := col else
          if key = 'textselection'                  then clTextSelection := col else
          if key = 'listselection'                  then clListSelShape := col else
          if key = 'listselectionoutline'           then clListSelOutline := col else
          if key = 'listselectionunfocused'         then clListSelShapeUnfocused := col else
          if key = 'listselectionoutlineunfocused'  then clListSelOutlineUnfocused := col else
            ok := False;
      end;

      if not ok and (gLog <> nil) then
        gLog.AddTime('theme.ini: ignored line ' + IntToStr(I + 1) + ': ' + line);
    end;
  finally
    sl.Free;
  end;

  if gLog <> nil then
    gLog.AddTime('UI theme loaded from ' + aFileName);
end;


{$IFOPT C+}
procedure SelfCheck;
var
  c: Cardinal;
begin
  Assert(ParseThemeColor('#F0BE4E', c) and (c = $FF4EBEF0));
  Assert(ParseThemeColor('#F0BE4E66', c) and (c = $664EBEF0));
  Assert(not ParseThemeColor('F0BE4E', c) and not ParseThemeColor('#F0BE4', c) and not ParseThemeColor('#F0BEZZ', c));
end;
{$ENDIF}


initialization
  gUITheme := UI_THEME_DEFAULT;
  {$IFOPT C+}
  SelfCheck;
  {$ENDIF}

end.
