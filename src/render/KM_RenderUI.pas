unit KM_RenderUI;
{$I KaM_Remake.inc}
interface
uses
  {$IFDEF WDC}
  Generics.Collections,
  {$ENDIF}
  {$IFDEF FPC}
  Generics.Collections,
  {$ENDIF}
  KromOGLUtils,
  KM_Defaults, KM_CommonTypes, KM_Points, KM_ResTypes,
  KM_RenderTypes,
  KM_ResFonts;

type
  TKMAnchors = (anLeft, anTop, anRight, anBottom);
  TKMAnchorsSet = set of TKMAnchors;
  TKMButtonStateSet = set of (bsOver, bsDown, bsDisabled);
  TKMButtonStyle = (bsMenu, bsGame); //Menu buttons are metal, game buttons are stone
  TKMTextAlign = (taLeft, taCenter, taRight);
  TKMTextVAlign = (tvaNone, tvaTop, tvaMiddle, tvaBottom);

  TKMPointDesc = record
    P: TKMPoint;
    Desc: string;
  end;

  TKMRenderUI = class
  private
    {$IF DEFINED(WDC) OR DEFINED(FPC)} // FPC: same nested clipping as Delphi
    class var
      fClipXStack: TStack<TKMRangeInt>;
      fClipYStack: TStack<TKMRangeInt>;
    {$ENDIF}
    class procedure ApplyClipX (X1,X2: SmallInt);
    class procedure ApplyClipY (Y1,Y2: SmallInt);
    class function RoundedButtonLip(aHeight: SmallInt): Integer;
    class procedure WriteRoundedButton(aWidth, aHeight: SmallInt; aTexID: Cardinal; const A, B: TKMPointF;
      aState: TKMButtonStateSet; aRing: Boolean);
  public
    class procedure SetupClipX (X1,X2: SmallInt);
    class procedure SetupClipY (Y1,Y2: SmallInt);
    class procedure ReleaseClipX;
    class procedure ReleaseClipY;

    class procedure Write3DButton  (aLeft, aTop, aWidth, aHeight: SmallInt; aRX: TRXType; aID: Word; aFlagColor: TColor4;
      aState: TKMButtonStateSet; aStyle: TKMButtonStyle; aImageEnabled: Boolean = True);
    class function ButtonContentShift(aState: TKMButtonStateSet; aHeight: SmallInt): TKMPoint;

    class procedure WriteBevel(aLeft, aTop, aWidth, aHeight: SmallInt;
                               aEdgeAlpha: Single = BEVEL_EDGE_ALPHA_DEF; aBackAlpha: Single = BEVEL_BACK_ALPHA_DEF); overload;
    class procedure WriteBevel(aLeft, aTop, aWidth, aHeight: SmallInt; const aColor: TKMColor3f;
                               aEdgeAlpha: Single = BEVEL_EDGE_ALPHA_DEF; aBackAlpha: Single = BEVEL_BACK_ALPHA_DEF); overload;

    class procedure WritePercentBar(aLeft, aTop, aWidth, aHeight: SmallInt; aPos: Single; aSeam: Single;
      aMainColor: Cardinal = icBarColorGreen; aAddColor: Cardinal = icBarColorBlue);
    class procedure WriteReplayBar (aLeft, aTop, aWidth, aHeight: SmallInt; aPos, aPeacetime, aMaxValue: Integer; aMarks: TList<Integer>; aPattern: Word; aHighlightedMark: Integer = -1);
    class procedure WritePicture   (aLeft, aTop, aWidth, aHeight: SmallInt; aAnchors: TKMAnchorsSet; aRX: TRXType; aID: Word;
      aEnabled: Boolean = True; aColor: TColor4 = $FFFF00FF; aLightness: Single = 0; aTint: TColor4 = 0);
    class procedure WriteLockedPicture(aLeft, aTop, aWidth, aHeight: SmallInt; aRX: TRXType; aID: Word);
    class procedure WritePlot      (aLeft, aTop, aWidth, aHeight: SmallInt; aValues: TKMCardinalArray; aMaxValue: Cardinal;
      aColor: TColor4; aLineWidth: Byte);
    class procedure WriteOutline   (aLeft, aTop, aWidth, aHeight, aLineWidth: SmallInt; Col: TColor4);
    class procedure WriteShape     (aLeft, aTop, aWidth, aHeight: SmallInt; Col: TColor4; Outline: TColor4 = $00000000);
    class procedure WritePolyShape (aPoints: TKMPointArray; aColor: TColor4; aPattern: Word = $FFFF); overload;
    class procedure WritePolyShape (aPoints: TKMPointFArray; aColor: TColor4; aPattern: Word = $FFFF); overload;
//    class procedure WritePolyShape (aPoints: TKMPointFArray; aColor: TKMColor4f; aPattern: Word = $FFFF); overload;
    class procedure WriteLine      (aFromX, aFromY, aToX, aToY: Single; aCol: TColor4; aPattern: Word = $FFFF; aLineWidth: Integer = -1);
    class procedure WriteText      (aLeft, aTop, aWidth: SmallInt; aText: UnicodeString; aFont: TKMFont; aAlign: TKMTextAlign;
      aColor: TColor4 = $FFFFFFFF; aIgnoreMarkup: Boolean = False; aShowMarkup: Boolean = False;
      aShowEolSymbol: Boolean = False; aTabWidth: Integer = FONT_TAB_WIDTH);
    class procedure WriteTextInShape(const aText: string; X,Y: SmallInt; aLineColor, aTextColor: Cardinal; aShapeColor1: Cardinal = $80000000; aText2: string = ''; aShapeColor2: Cardinal = 0; aTextColor2: Cardinal = 0);
    class procedure WriteTexture   (aLeft, aTop, aWidth, aHeight: SmallInt; const aTexture: TTexture; aCol: TColor4);
    class procedure WriteCircle    (aCenterX, aCenterY: SmallInt; aRadius: Byte; aFillColor: TColor4);
    class procedure WriteShadow    (aLeft, aTop, aWidth, aHeight: SmallInt; aBlur: Byte; aCol: TColor4);
  end;


implementation
uses
  Math, StrUtils, SysUtils,
  dglOpenGL,
  KM_Render, KM_Resource, KM_ResSprites, KM_ResTheme;


{ TKMRenderUI }
//X axis uses planes 0,1 and Y axis uses planes 2,3, so that they don't interfere when both axis are
//clipped from both sides
class procedure TKMRenderUI.ApplyClipX(X1,X2: SmallInt);
var
  cp: array[0..3] of Double; //Function uses 8byte floats //ClipPlane X+Y+Z=-D
begin
  glEnable(GL_CLIP_PLANE0);
  glEnable(GL_CLIP_PLANE1);
  FillChar(cp, SizeOf(cp), 0);
  cp[0] := 1; cp[3] := -X1; //Upper edge
  glClipPlane(GL_CLIP_PLANE0, @cp);
  cp[0] := -1; cp[3] := X2; //Lower edge
  glClipPlane(GL_CLIP_PLANE1, @cp);
end;


class procedure TKMRenderUI.ApplyClipY(Y1,Y2: SmallInt);
var
  cp: array[0..3] of Double; //Function uses 8byte floats //ClipPlane X+Y+Z=-D
begin
  glEnable(GL_CLIP_PLANE2);
  glEnable(GL_CLIP_PLANE3);
  FillChar(cp, SizeOf(cp), 0);
  cp[1] := 1; cp[3] := -Y1; //Upper edge
  glClipPlane(GL_CLIP_PLANE2, @cp);
  cp[1] := -1; cp[3] := Y2; //Lower edge
  glClipPlane(GL_CLIP_PLANE3, @cp);
end;


class procedure TKMRenderUI.SetupClipX(X1,X2: SmallInt);
var
  P: TKMRangeInt;
begin
  {$IF DEFINED(WDC) OR DEFINED(FPC)} // FPC: same nested clipping as Delphi
  if fClipXStack.Count > 0 then
  begin
    P := fClipXStack.Peek;
    ApplyClipX(Max(P.Min, X1), Min(P.Max, X2)); //Make clip areas intersection
  end else
    ApplyClipX(X1,X2);
  fClipXStack.Push(KMRange(X1, X2));
  {$ELSE}
  ApplyClipX(X1,X2);
  {$ENDIF}
end;


class procedure TKMRenderUI.SetupClipY(Y1,Y2: SmallInt);
var
  P: TKMRangeInt;
begin
  {$IF DEFINED(WDC) OR DEFINED(FPC)} // FPC: same nested clipping as Delphi
  if fClipYStack.Count > 0 then
  begin
    P := fClipYStack.Peek;
    ApplyClipY(Max(P.Min, Y1), Min(P.Max, Y2)); //Make clip areas intersection
  end else
    ApplyClipY(Y1,Y2);
  fClipYStack.Push(KMRange(Y1, Y2));
  {$ELSE}
  ApplyClipY(Y1,Y2);
  {$ENDIF}
end;


//Separate release of clipping planes
class procedure TKMRenderUI.ReleaseClipX;

  procedure ReleaseX;
  begin
    glDisable(GL_CLIP_PLANE0);
    glDisable(GL_CLIP_PLANE1);
  end;

var
  P: TKMRangeInt;
begin
  {$IF DEFINED(WDC) OR DEFINED(FPC)} // FPC: same nested clipping as Delphi
  if fClipXStack.Count <> 0 then
  begin
    ReleaseX;
    fClipXStack.Pop;
    if fClipXStack.Count <> 0 then
    begin
      P := fClipXStack.Peek;
      ApplyClipX(P.Min, P.Max);
    end;
  end else
  {$ENDIF}
    ReleaseX;
end;


//Separate release of clipping planes
class procedure TKMRenderUI.ReleaseClipY;

  procedure ReleaseY;
  begin
    glDisable(GL_CLIP_PLANE2);
    glDisable(GL_CLIP_PLANE3);
  end;

var
  P: TKMRangeInt;
begin
  {$IF DEFINED(WDC) OR DEFINED(FPC)} // FPC: same nested clipping as Delphi
  if fClipYStack.Count <> 0 then
  begin
    ReleaseY;
    fClipYStack.Pop;
    if fClipYStack.Count <> 0 then
    begin
      P := fClipYStack.Peek;
      ApplyClipY(P.Min, P.Max);
    end;
  end else
  {$ENDIF}
    ReleaseY;
end;


class procedure TKMRenderUI.Write3DButton(aLeft, aTop, aWidth, aHeight: SmallInt; aRX: TRXType; aID: Word; aFlagColor: TColor4; aState: TKMButtonStateSet; aStyle: TKMButtonStyle; aImageEnabled: Boolean = True);
var
  down: Byte;
  chamfer: Byte;
  A, B: TKMPointF;
  insetX, insetY: Single;
  c1, c2: Byte;
  backRX: TRXType;
  backID: Word;
  shift: TKMPoint;
begin
  if aStyle = bsMenu then
  begin
    backRX := rxGuiMain;
    backID := 9; //GuiMain-3 is a metal background used in main menu
  end else
  begin
    backRX := rxGui;
    backID := 402; //Gui-402 is a stone background
  end;

  down := Byte(bsDown in aState);

  with gGFXData[backRX, backID] do
  with gGFXData[backRX, backID].Tex do
  if PxWidth * PxHeight <> 0 then //Make sure data was loaded properly
  begin
    A.X := u1 + (u2 - u1) * (aLeft - down) / 2 / PxWidth;
    B.X := u1 + (u2 - u1) * (aLeft + aWidth - down) / 2 / PxWidth;
    A.Y := v1 + (v2 - v1) * (aTop - down) / 2 / PxHeight;
    B.Y := v1 + (v2 - v1) * (aTop + aHeight - down) / 2 / PxHeight;
    A.X := A.X - (u2 - u1) * ((aLeft + aWidth div 2) div PxWidth) / 2;
    B.X := B.X - (u2 - u1) * ((aLeft + aWidth div 2) div PxWidth) / 2;
    A.Y := A.Y - (v2 - v1) * ((aTop + aHeight div 2) div PxHeight) / 2;
    B.Y := B.Y - (v2 - v1) * ((aTop + aHeight div 2) div PxHeight) / 2;
    A.X := EnsureRange(A.X, u1, u2);
    B.X := EnsureRange(B.X, u1, u2);
    A.Y := EnsureRange(A.Y, v1, v2);
    B.Y := EnsureRange(B.Y, v1, v2);
  end;

  if gUITheme.ButtonRadius > 0 then
  begin
    glPushMatrix;
    try
      glTranslatef(aLeft, aTop, 0);
      WriteRoundedButton(aWidth, aHeight, gGFXData[backRX, backID].Tex.TexID, A, B, aState, False);
      if aID <> 0 then
      begin
        shift := ButtonContentShift(aState, aHeight);
        WritePicture(shift.X, shift.Y, aWidth, aHeight, [], aRX, aID, aImageEnabled, aFlagColor);
      end;
      // The ring goes over the picture
      if (bsOver in aState) and not (bsDisabled in aState) then
        WriteRoundedButton(aWidth, aHeight, 0, A, B, aState, True);
      TKMRender.BindTexture(0);
    finally
      glPopMatrix;
    end;
    Exit;
  end;

  glPushMatrix;
  try
    glTranslatef(aLeft, aTop, 0);

      //Background
      glColor4f(1, 1, 1, 1);
      TKMRender.BindTexture(gGFXData[backRX, backID].Tex.TexID);
      glBegin(GL_QUADS);
        glTexCoord2f(A.x,A.y); glVertex2f(0,0);
        glTexCoord2f(B.x,A.y); glVertex2f(aWidth,0);
        glTexCoord2f(B.x,B.y); glVertex2f(aWidth,aHeight);
        glTexCoord2f(A.x,B.y); glVertex2f(0,aHeight);
      glEnd;

      //Render beveled edges
      TKMRender.BindTexture(0);

      c1 := 1 - down;
      c2 := down;
      chamfer := 2 + Byte(Min(aWidth, aHeight) > 25);

      glPushMatrix;
      try
        //Scale to save on XY+/-Inset coordinates calculations
        glScalef(aWidth, aHeight, 0);
        insetX := chamfer / aWidth;
        insetY := chamfer / aHeight;
        glBegin(GL_QUADS);
          glColor4f(c1,c1,c1,0.7); glkQuad(0, 0, 1,        0,        1-insetX, 0+insetY, 0+insetX, 0+insetY);
          glColor4f(c1,c1,c1,0.6); glkQuad(0, 0, 0+insetX, 0+insetY, 0+insetX, 1-insetY, 0,        1       );
          glColor4f(c2,c2,c2,0.5); glkQuad(1, 0, 1,        1,        1-insetX, 1-insetY, 1-insetX, 0+insetY);
          glColor4f(c2,c2,c2,0.4); glkQuad(0, 1, 0+insetX, 1-insetY, 1-insetX, 1-insetY, 1,        1       );
        glEnd;
      finally
        glPopMatrix;
      end;

    //Render a pic ontop
    if aID <> 0 then
    begin
      glColor4f(1, 1, 1, 1);
      WritePicture(down, down, aWidth, aHeight, [], aRX, aID, aImageEnabled, aFlagColor);
    end;

    TKMRender.BindTexture(0);

    //Render MouseOver highlight
    if bsOver in aState then
    begin
      glColor4f(1, 1, 1, 0.15);
      glBegin(GL_QUADS);
        glkRect(0, 0, aWidth, aHeight);
      glEnd;
    end;

    //Render darklight when Disabled
    if bsDisabled in aState then
    begin
      glColor4f(0, 0, 0, 0.5);
      glBegin(GL_QUADS);
        glkRect(0, 0, aWidth, aHeight);
      glEnd;
    end;
  finally
    glPopMatrix;
  end;
end;


// Lip of the rounded button, at most a quarter of its height (scroll thumbs, small arrows)
class function TKMRenderUI.RoundedButtonLip(aHeight: SmallInt): Integer;
begin
  Result := Min(gUITheme.ButtonLip, aHeight div 4);
end;


// Where a 3D button's caption and picture go relative to the button: the chamfered button moves them 1 px when
// pressed; the rounded one centres them on its face, which sits on the lip, sinks onto it when pressed and covers
// the whole button when disabled
class function TKMRenderUI.ButtonContentShift(aState: TKMButtonStateSet; aHeight: SmallInt): TKMPoint;
var
  lip: Integer;
begin
  if gUITheme.ButtonRadius = 0 then
    Exit(KMPoint(Byte(bsDown in aState), Byte(bsDown in aState)));

  lip := RoundedButtonLip(aHeight);
  if bsDisabled in aState then
    Result := KMPoint(0, 0)
  else
  if bsDown in aState then
    Result := KMPoint(0, lip - lip div 2)
  else
    Result := KMPoint(0, -(lip div 2));
end;


// The theme's rounded 3D button, at 0,0 (the caller translates). aRing = False draws the body: the button tile
// (aTexID, mapped A..B over the button like the square button) as a rounded face on a lip of the same tile,
// darker; pressed, the face sits on the lip; disabled, the face alone, faded. aRing = True draws the hover ring
// just inside the face. Edges get a 1 screen px alpha fringe in place of multisampling. Hit area = the button rect
class procedure TKMRenderUI.WriteRoundedButton(aWidth, aHeight: SmallInt; aTexID: Cardinal; const A, B: TKMPointF;
  aState: TKMButtonStateSet; aRing: Boolean);
const
  SEG = 5;          // Segments per corner
  N = 4 * (SEG + 1); // Points on the contour
  LIP_SHADE = 0.6;  // The lip is the face's own tile, darker, so it suits every button style
  RING_W = 2;
var
  r, lip, aa: Single;
  colR, colG, colB, colA: Single;
  textured: Boolean;
  faceTop, faceBottom: Single;

  // Point I of the contour of rect x0..x1, y0..y1 with corner radius r, inset by d (corners keep their centres)
  procedure ContourPt(x0, y0, x1, y1, d: Single; I: Integer; out aX, aY: Single);
  var
    rr, cx, cy, ang: Single;
    corner: Integer;
  begin
    rr := r - d;
    if rr < 0 then rr := 0;
    corner := I div (SEG + 1);
    // Clockwise from the top-left corner, which starts pointing left (180 degrees; y grows down)
    ang := (corner + 2 + (I mod (SEG + 1)) / SEG) * Pi / 2;
    if corner in [0, 3] then cx := x0 + d + rr else cx := x1 - d - rr;
    if corner in [0, 1] then cy := y0 + d + rr else cy := y1 - d - rr;
    aX := cx + rr * Cos(ang);
    aY := cy + rr * Sin(ang);
  end;

  procedure Vtx(aX, aY, aAlpha: Single);
  begin
    glColor4f(colR, colG, colB, colA * aAlpha);
    if textured then
      glTexCoord2f(A.X + (B.X - A.X) * aX / aWidth, A.Y + (B.Y - A.Y) * aY / aHeight);
    glVertex2f(aX, aY);
  end;

  // Strip between the contour inset d1 (alpha a1) and the one inset d2 (alpha a2)
  procedure Band(x0, y0, x1, y1, d1, a1, d2, a2: Single);
  var
    I: Integer;
    x, y: Single;
  begin
    glBegin(GL_TRIANGLE_STRIP);
      for I := 0 to N do
      begin
        ContourPt(x0, y0, x1, y1, d1, I mod N, x, y);
        Vtx(x, y, a1);
        ContourPt(x0, y0, x1, y1, d2, I mod N, x, y);
        Vtx(x, y, a2);
      end;
    glEnd;
  end;

  procedure Fill(x0, y0, x1, y1: Single);
  var
    I: Integer;
    x, y: Single;
  begin
    glBegin(GL_TRIANGLE_FAN);
      Vtx((x0 + x1) / 2, (y0 + y1) / 2, 1);
      for I := 0 to N do
      begin
        ContourPt(x0, y0, x1, y1, aa, I mod N, x, y);
        Vtx(x, y, 1);
      end;
    glEnd;
    Band(x0, y0, x1, y1, 0, 0, aa, 1);
  end;

  procedure SetCol(aR, aG, aB, aA: Single);
  begin
    colR := aR; colG := aG; colB := aB; colA := aA;
  end;

begin
  if (aWidth <= 0) or (aHeight <= 0) then Exit;

  r := Min(gUITheme.ButtonRadius, Min(aWidth, aHeight) div 2);
  lip := RoundedButtonLip(aHeight);
  aa := 1 / gRender.UIScale; // 1 screen px

  if bsDisabled in aState then
  begin
    faceTop := 0;
    faceBottom := aHeight;
  end else
  if bsDown in aState then
  begin
    faceTop := lip;
    faceBottom := aHeight;
  end else
  begin
    faceTop := 0;
    faceBottom := aHeight - lip;
  end;

  if aRing then
  begin
    textured := False;
    TKMRender.BindTexture(0);
    SetCol((gUITheme.ButtonRing and $FF) / 255, (gUITheme.ButtonRing shr 8 and $FF) / 255,
           (gUITheme.ButtonRing shr 16 and $FF) / 255, (gUITheme.ButtonRing shr 24) / 255);
    Band(0, faceTop, aWidth, faceBottom, 0, 0, aa, 1);
    Band(0, faceTop, aWidth, faceBottom, aa, 1, RING_W, 1);
    Band(0, faceTop, aWidth, faceBottom, RING_W, 1, RING_W + aa, 0);
    Exit;
  end;

  textured := True;
  TKMRender.BindTexture(aTexID);

  if bsDisabled in aState then
    SetCol(1, 1, 1, gUITheme.ButtonDisabledAlpha)
  else
  if bsDown in aState then
    SetCol(0.9, 0.9, 0.9, 1)
  else
  begin
    // Lip: starts lower so its top corners stay under the face
    SetCol(LIP_SHADE, LIP_SHADE, LIP_SHADE, 1);
    Fill(0, lip, aWidth, aHeight);
    SetCol(1, 1, 1, 1);
  end;
  Fill(0, faceTop, aWidth, faceBottom);
end;


class procedure TKMRenderUI.WriteBevel(aLeft, aTop, aWidth, aHeight: SmallInt;
                                       aEdgeAlpha: Single = BEVEL_EDGE_ALPHA_DEF; aBackAlpha: Single = BEVEL_BACK_ALPHA_DEF);
begin
  WriteBevel(aLeft, aTop, aWidth, aHeight, COLOR3F_BLACK, aEdgeAlpha, aBackAlpha);
end;


class procedure TKMRenderUI.WriteBevel(aLeft, aTop, aWidth, aHeight: SmallInt; const aColor: TKMColor3f;
                                       aEdgeAlpha: Single = BEVEL_EDGE_ALPHA_DEF; aBackAlpha: Single = BEVEL_BACK_ALPHA_DEF);
var
  back, edge: TKMColor3f;
  light: Cardinal;
begin
  if (aWidth < 0) or (aHeight < 0) then Exit;

  // The engine's black panels take the mod theme's colour and density (no theme = black, alphas as given)
  back := aColor;
  edge := COLOR3F_BLACK;
  light := 0;
  if (aColor.R = 0) and (aColor.G = 0) and (aColor.B = 0) then
  begin
    light := gUITheme.ListLine;
    back := gUITheme.BevelColor;
    edge := gUITheme.BevelEdge;
    aBackAlpha := ThemedBevelAlpha(aBackAlpha);
  end;

  // Reset texture to default (0), because it could be bind to any other texture (atlas)
  TKMRender.BindTexture(0);

  glPushMatrix;
  try
    glTranslatef(aLeft, aTop, 0);

    //Background
    glColor4f(back.R, back.G, back.B, aBackAlpha);
    glBegin(GL_QUADS);
      glkRect(1, 1, aWidth-1, aHeight-1);
    glEnd;

    //2 Thin outlines rendered on top of background to avoid inset calculations
    if aEdgeAlpha > 0 then
    begin
      //Bright edge. Additive light turns pure white over a light backdrop: a theme can give it a colour instead
      if light <> 0 then
        glColor4ub(light and $FF, light shr 8 and $FF, light shr 16 and $FF, Round((light shr 24) * aEdgeAlpha))
      else
      begin
        glBlendFunc(GL_DST_COLOR, GL_ONE);
        glColor3f(0.75 * aEdgeAlpha, 0.75 * aEdgeAlpha, 0.75 * aEdgeAlpha);
      end;
      glBegin(GL_LINE_STRIP);
        glVertex2f(aWidth-0.5, 0.5);
        glVertex2f(aWidth-0.5, aHeight-0.5);
        glVertex2f(0.5, aHeight-0.5);
      glEnd;

      //Dark edge
      glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
      glColor4f(edge.R, edge.G, edge.B, aEdgeAlpha);
      glBegin(GL_LINE_STRIP);
        glVertex2f(0.5, aHeight-0.5);
        glVertex2f(0.5, 0.5);
        glVertex2f(aWidth-0.5, 0.5);
      glEnd;
    end;
  finally
    glPopMatrix;
  end;
end;


class procedure TKMRenderUI.WritePercentBar(aLeft,aTop,aWidth,aHeight: SmallInt; aPos: Single; aSeam: Single;
                                            aMainColor: Cardinal = icBarColorGreen; aAddColor: Cardinal = icBarColorBlue);
var
  barWidth: Word;
begin
  // Reset texture to default (0), because it could be bind to any other texture (atlas)
  TKMRender.BindTexture(0);

  glPushMatrix;
  try  glTranslatef(aLeft, aTop, 0);

    WriteBevel(0, 0, aWidth, aHeight);

    //At least 2px wide to show up from under the shadow
    barWidth := Round((aWidth - 2) * aPos) + 2;
    if aMainColor = icBarColorGreen then
      aMainColor := ThemeOr(gUITheme.BarFill, aMainColor);
    glColor4ubv(@aMainColor);
    glBegin(GL_QUADS);
      glkRect(1, 1, barWidth-1, aHeight-1);
    glEnd;

    if (aSeam > 0) then
    begin
      //At least 2px wide to show up from under the shadow
      barWidth := Round((aWidth - 2) * Min(aPos, aSeam)) + 2;
      glColor4ubv(@aAddColor);
      glBegin(GL_QUADS);
        glkRect(1, 1, barWidth-1, aHeight-1);
      glEnd;

      //Skip the seam if it matches high border
      if (aSeam < 1) then
        WriteOutline(Round(aSeam * (aWidth - 2)) + 1, 1, 1, aHeight-2, 1, $FFFFFFFF);
    end;

    //Draw shadow on top and left of the bar, just like real one
    glColor4f(0,0,0,0.5); //Set semi-transparent black
    glBegin(GL_LINE_STRIP); //List vertices, order is important
      glVertex2f(1.5,aHeight-1.5);
      glVertex2f(1.5,1.5);
      glVertex2f(aWidth-1.5,1.5);
      glVertex2f(aWidth-1.5,2.5);
      glVertex2f(2.5,2.5);
      glVertex2f(2.5,aHeight-1.5);
    glEnd;
  finally
    glPopMatrix;
  end;
end;


class procedure TKMRenderUI.WriteReplayBar(aLeft, aTop, aWidth, aHeight: SmallInt; aPos, aPeacetime, aMaxValue: Integer;
                                           aMarks: TList<Integer>; aPattern: Word; aHighlightedMark: Integer = -1);
const
  BAR_COLOR_GREEN: TColor4 = $FF00AA26;
  BAR_COLOR_BLUE: TColor4 = $FFBBAA00;

  function GetPos(aValue: Integer): Word;
  begin
    //At least 2px wide to show up from under the shadow
    Result := Min( High(Word), Round((aWidth - 2) * (Max(0, aValue - 1)/ aMaxValue)) + 2);  //-1 just to draw 1st tick in a better way...
  end;

  procedure WriteWideLine(aX: Word; aColor: Cardinal; aPattern: Word = $FFFF);
  begin
    if InRange(aX, 0, aWidth) then  //Dont allow to render outside of control
      WriteLine(aX, 1, aX , aHeight - 1, aColor, aPattern, 2);
  end;

var
  PTPos, pos: Word;
  mark: Integer;
begin
  // Reset texture to default (0), because it could be bind to any other texture (atlas)
  TKMRender.BindTexture(0);

  glPushMatrix;
  try
    glTranslatef(aLeft, aTop, 0);

    WriteBevel(0, 0, aWidth, aHeight);

    PTPos := GetPos(aPeacetime);
    pos := GetPos(aPos);

    if aPos < aPeacetime then
    begin
      glColor4ubv(@BAR_COLOR_GREEN);
      glBegin(GL_QUADS);
        glkRect(1, 1, pos - 1, aHeight - 1);
      glEnd;

      WriteWideLine(PTPos, icCyan);
    end
    else
    begin
      glColor4ubv(@BAR_COLOR_GREEN);
      glBegin(GL_QUADS);
        glkRect(1, 1, PTPos, aHeight - 1);
      glEnd;

      glColor4ubv(@BAR_COLOR_BLUE);
      glBegin(GL_QUADS);
        glkRect(PTPos, 1, pos - 1, aHeight - 1);
      glEnd;
    end;

    for mark in aMarks do
      WriteWideLine(GetPos(mark), icYellow, aPattern);

    if aHighlightedMark <> -1 then
      WriteWideLine(GetPos(aHighlightedMark), icOrange);

    //Draw shadow on top and left of the bar, just like real one
    glColor4f(0, 0, 0, 0.5); //Set semi-transparent black
    glBegin(GL_LINE_STRIP); //List vertices, order is important
      glVertex2f(1.5, aHeight - 1.5);
      glVertex2f(1.5, 1.5);
      glVertex2f(aWidth - 1.5, 1.5);
      glVertex2f(aWidth - 1.5, 2.5);
      glVertex2f(2.5, 2.5);
      glVertex2f(2.5, aHeight - 1.5);
    glEnd;
  finally
    glPopMatrix;
  end;
end;


// aTint <> 0 draws the picture multiplied by that colour and alpha, without its flag colour layer
class procedure TKMRenderUI.WritePicture(aLeft, aTop, aWidth, aHeight: SmallInt; aAnchors: TKMAnchorsSet; aRX: TRXType;
                                         aID: Word; aEnabled: Boolean = True; aColor: TColor4 = $FFFF00FF; aLightness: Single = 0;
                                         aTint: TColor4 = 0);
var
  offX, offY: Integer;
  drawWidth, drawHeight: Integer;
begin
  if aID = 0 then Exit;
  if aID > High(gGFXData[aRX]) then Exit;

  offX  := 0;
  offY  := 0;
  drawWidth   := gGFXData[aRX, aID].PxWidth;
  drawHeight  := gGFXData[aRX, aID].PxHeight;

  //Both aAnchors means that we will need to stretch the image
  if (anLeft in aAnchors) and (anRight in aAnchors) then
    drawWidth := aWidth
  else
  if anLeft in aAnchors then
    //Use defaults
  else
  if anRight in aAnchors then
    offX := aWidth - drawWidth
  else
    //No aAnchors means: draw the image in center
    offX := (aWidth - drawWidth) div 2;

  if (anTop in aAnchors) and (anBottom in aAnchors) then
    drawHeight  := aHeight
  else
  if anTop in aAnchors then
    //Use defaults
  else
  if anBottom in aAnchors then
    offY := aHeight - drawHeight
  else
    offY := (aHeight - drawHeight) div 2;

  with gGFXData[aRX, aID] do
  begin
    glPushMatrix;
    try
      glTranslatef(aLeft + offX, aTop + offY, 0);

      //Base layer
      TKMRender.BindTexture(Tex.TexID);
      if aTint <> 0 then
        glColor4ubv(@aTint)
      else
      if aEnabled then glColor3f(1,1,1) else glColor3f(0.33,0.33,0.33);
      glBegin(GL_QUADS);
        glTexCoord2f(Tex.u1,Tex.v1); glVertex2f(0            , 0             );
        glTexCoord2f(Tex.u2,Tex.v1); glVertex2f(0 + drawWidth, 0             );
        glTexCoord2f(Tex.u2,Tex.v2); glVertex2f(0 + drawWidth, 0 + drawHeight);
        glTexCoord2f(Tex.u1,Tex.v2); glVertex2f(0            , 0 + drawHeight);
      glEnd;

      //Color overlay for unit icons and scrolls
      if (Alt.TexID <> 0) and (aTint = 0) then
      begin
        TKMRender.BindTexture(Alt.TexID);
        if aEnabled then
          glColor3ub(aColor AND $FF, aColor SHR 8 AND $FF, aColor SHR 16 AND $FF)
        else
          glColor3f(aColor AND $FF / 768, aColor SHR 8 AND $FF / 768, aColor SHR 16 AND $FF / 768);
        glBegin(GL_QUADS);
          glTexCoord2f(Alt.u1,Alt.v1); glVertex2f(0            , 0             );
          glTexCoord2f(Alt.u2,Alt.v1); glVertex2f(0 + drawWidth, 0             );
          glTexCoord2f(Alt.u2,Alt.v2); glVertex2f(0 + drawWidth, 0 + drawHeight);
          glTexCoord2f(Alt.u1,Alt.v2); glVertex2f(0            , 0 + drawHeight);
        glEnd;
      end;

      //Highlight for active/focused/mouseOver images
      if aLightness <> 0 then
      begin
        TKMRender.BindTexture(Tex.TexID); //Replace AltID if it was used
        if aLightness > 0 then
          glBlendFunc(GL_SRC_ALPHA, GL_ONE)
        else
        begin
          glBlendFunc(GL_SRC_ALPHA, GL_ZERO);
          aLightness := 1-Abs(aLightness);
        end;
        glColor3f(aLightness, aLightness, aLightness);
        glBegin(GL_QUADS);
          glTexCoord2f(Tex.u1,Tex.v1); glVertex2f(0            , 0             );
          glTexCoord2f(Tex.u2,Tex.v1); glVertex2f(0 + drawWidth, 0             );
          glTexCoord2f(Tex.u2,Tex.v2); glVertex2f(0 + drawWidth, 0 + drawHeight);
          glTexCoord2f(Tex.u1,Tex.v2); glVertex2f(0            , 0 + drawHeight);
        glEnd;
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
      end;
    finally
      glPopMatrix;
    end;
  end;
end;


// A house the player cannot build yet, as the theme asks: its own icon (centred) in the theme's tint, with the
// "not available" sprite (GUI 41) small in the icon's top-left corner
class procedure TKMRenderUI.WriteLockedPicture(aLeft, aTop, aWidth, aHeight: SmallInt; aRX: TRXType; aID: Word);
const
  LOCK_H = 12;
var
  lockW: Integer;
begin
  if (aID = 0) or (aID > High(gGFXData[aRX])) then Exit;

  WritePicture(aLeft, aTop, aWidth, aHeight, [], aRX, aID, True, $FFFF00FF, 0, gUITheme.LockedHouse);

  if gGFXData[rxGui, 41].PxHeight = 0 then Exit;
  lockW := Round(LOCK_H * gGFXData[rxGui, 41].PxWidth / gGFXData[rxGui, 41].PxHeight);
  WritePicture(aLeft + Max((aWidth - gGFXData[aRX, aID].PxWidth) div 2, 0) + 1,
               aTop + Max((aHeight - gGFXData[aRX, aID].PxHeight) div 2, 0) + 1,
               lockW, LOCK_H, [anLeft, anTop, anRight, anBottom], rxGui, 41);
end;


class procedure TKMRenderUI.WritePlot(aLeft,aTop,aWidth,aHeight: SmallInt; aValues: TKMCardinalArray; aMaxValue: Cardinal; aColor: TColor4; aLineWidth: Byte);
var
  I: Integer;
begin
  // Reset texture to default (0), because it could be bind to any other texture (atlas)
  TKMRender.BindTexture(0);

  glPushAttrib(GL_LINE_BIT);
  glPushMatrix;
  try
    //glEnable(GL_LINE_SMOOTH); //Smooth lines actually look odd in KaM
    glTranslatef(aLeft, aTop, 0);
    glLineWidth(aLineWidth * gRender.UIScale);
    glColor4ubv(@aColor);
    glBegin(GL_LINE_STRIP);
      for I := 0 to High(aValues) do
        glVertex2f(I / High(aValues) * aWidth, aHeight - aValues[I] / aMaxValue * aHeight);
    glEnd;
  finally
    glPopAttrib;
    glPopMatrix;
  end;
end;


class procedure TKMRenderUI.WriteOutline(aLeft, aTop, aWidth, aHeight, aLineWidth: SmallInt; Col: TColor4);
begin
  if aLineWidth = 0 then Exit;

  // Reset texture to default (0), because it could be bind to any other texture (atlas)
  TKMRender.BindTexture(0);

  glPushAttrib(GL_LINE_BIT);
  try
    glLineWidth(aLineWidth * gRender.UIScale);
    glColor4ubv(@Col);
    glBegin(GL_LINE_LOOP);
      glkRect(aLeft + aLineWidth / 2, aTop + aLineWidth / 2, aLeft + aWidth - aLineWidth / 2, aTop + aHeight - aLineWidth / 2);
    glEnd;
  finally
    glPopAttrib;
  end;
end;


//Renders plane with given color and optional 1px outline
class procedure TKMRenderUI.WriteShape(aLeft, aTop, aWidth, aHeight: SmallInt; Col: TColor4; Outline: TColor4 = $00000000);
begin
  // Reset texture to default (0), because it could be bind to any other texture (atlas)
  TKMRender.BindTexture(0);

  glPushAttrib(GL_LINE_BIT);
  try
    glColor4ubv(@Col);
    glBegin(GL_QUADS);
      glkRect(aLeft, aTop, aLeft + aWidth, aTop + aHeight);
    glEnd;
    glLineWidth(gRender.UIScale);
    glColor4ubv(@Outline);
    glBegin(GL_LINE_LOOP);
      glkRect(aLeft + 0.5, aTop + 0.5, aLeft + aWidth - 0.5, aTop + aHeight - 0.5);
    glEnd;
  finally
    glPopAttrib;
  end;
end;


//Renders polygon shape with given color
class procedure TKMRenderUI.WritePolyShape(aPoints: TKMPointArray; aColor: TColor4; aPattern: Word = $FFFF);
var
  I: Integer;
begin
  // Reset texture to default (0), because it could be bind to any other texture (atlas)
  TKMRender.BindTexture(0);

  glColor4ubv(@aColor);
  glLineStipple(Math.Max(1, Round(2 * gRender.UIScale)), aPattern);
  glBegin(GL_POLYGON);
    for I := 0 to High(aPoints) do
      glVertex2f(aPoints[I].X, aPoints[I].Y);
  glEnd;
end;


class procedure TKMRenderUI.WritePolyShape(aPoints: TKMPointFArray; aColor: TColor4; aPattern: Word = $FFFF);
var
  I: Integer;
begin
  // Reset texture to default (0), because it could be bind to any other texture (atlas)
  TKMRender.BindTexture(0);

  glColor4ubv(@aColor);
  glLineStipple(Math.Max(1, Round(2 * gRender.UIScale)), aPattern);
  glBegin(GL_POLYGON);
    for I := 0 to High(aPoints) do
      glVertex2f(aPoints[I].X, aPoints[I].Y);
  glEnd;
end;


class procedure TKMRenderUI.WriteLine(aFromX, aFromY, aToX, aToY: Single; aCol: TColor4; aPattern: Word = $FFFF; aLineWidth: Integer = -1);
begin
  // Reset texture to default (0), because it could be bind to any other texture (atlas)
  TKMRender.BindTexture(0);

  glColor4ubv(@aCol);

  if aLineWidth <> -1 then
  begin
    glPushAttrib(GL_LINE_BIT);
    glLineWidth(aLineWidth * gRender.UIScale);
  end;

  // Solid pattern needs no stipple (stipple is emulated with an extra texture pass on GLES)
  if aPattern <> $FFFF then
  begin
    glEnable(GL_LINE_STIPPLE);
    glLineStipple(Math.Max(1, Round(2 * gRender.UIScale)), aPattern);
  end;

  glBegin(GL_LINES);
    glVertex2f(aFromX, aFromY);
    glVertex2f(aToX, aToY);
  glEnd;
  if aPattern <> $FFFF then
    glDisable(GL_LINE_STIPPLE);


  if aLineWidth <> -1 then
    glPopAttrib;
end;


// Renders a line of text
// By default color must be non-transparent white
class procedure TKMRenderUI.WriteText(aLeft, aTop, aWidth: SmallInt; aText: UnicodeString; aFont: TKMFont; aAlign: TKMTextAlign;
  aColor: TColor4 = $FFFFFFFF; aIgnoreMarkup: Boolean = False; aShowMarkup: Boolean = False; aShowEolSymbol: Boolean = False;
  aTabWidth: Integer = FONT_TAB_WIDTH);
var
  I, K, off: Integer;
  lineCount, dx, dy, lineHeight, blockWidth, prevAtlas, lineWidthInc: Integer;
  lineWidth: array of Integer; //Use signed format since some fonts may have negative CharSpacing
  fontSpec: TKMFontSpec;
  let: TKMLetter;
  tmpColor: Integer;
  colors: array of record
    FirstChar: Word;
    Color: TColor4;
  end;

  procedure DrawLetter;
  begin
    let := fontSpec.GetLetter(aText[I]);

    if (prevAtlas = -1) or (prevAtlas <> let.AtlasId) then
    begin
      if prevAtlas <> -1 then
        glEnd; // End previous draw
      prevAtlas := let.AtlasId;
      TKMRender.BindTexture(fontSpec.TexID[let.AtlasId]);
      glBegin(GL_QUADS);
    end;

    glTexCoord2f(let.u1, let.v1); glVertex2f(dx            , dy            + let.YOffset);
    glTexCoord2f(let.u2, let.v1); glVertex2f(dx + let.Width, dy            + let.YOffset);
    glTexCoord2f(let.u2, let.v2); glVertex2f(dx + let.Width, dy+let.Height + let.YOffset);
    glTexCoord2f(let.u1, let.v2); glVertex2f(dx            , dy+let.Height + let.YOffset);
    Inc(dx, Max(0, let.Width + fontSpec.CharSpacing)); // CharSpacing could be negative
  end;

var
  setupClipXApplied: Boolean;
begin
  if (aText = '') or (aColor = $00000000) or DBG_SKIP_RENDER_TEXT then Exit;

  SetLength(colors, 0);

  setupClipXApplied := aWidth <> 0;
  if setupClipXApplied then
    SetupClipX(aLeft, aLeft + aWidth);

  //Look for [$FFFFFF][] patterns that markup text color
  off := 1;
  if not aIgnoreMarkup then
  repeat
    I := PosEx('[', aText, off);

    //Check for reset
    if (I <> 0) and (I+1 <= Length(aText)) and (aText[I+1] = ']') then
    begin
      SetLength(colors, Length(colors) + 1);
      colors[High(colors)].FirstChar := I;
      colors[High(colors)].Color := 0;
      if not aShowMarkup then Delete(aText, I, 2);
    end;

    //Check for new color
    if (I <> 0) and (I+8 <= Length(aText))
    and (aText[I+1] = '$') and (aText[I+8] = ']')
    and TryStrToInt(Copy(aText, I+1, 7), tmpColor) then
    begin
      SetLength(colors, Length(colors) + 1);
      colors[High(colors)].FirstChar := I;
      if aShowMarkup then
        Inc(colors[High(colors)].FirstChar, 9); //Don't color the markup itself
      colors[High(colors)].Color := Abs(tmpColor) or $FF000000;
      if not aShowMarkup then
      begin
        Delete(aText, I, 9);
        off := I; //We could try to find 1 more color right after this one (could happen in case of wrap colors)
      end else
        off := I + 1; //Continue search from the next letter
    end
    else
      off := I + 1; //Continue search from the next letter

  until(I = 0);


  fontSpec := gRes.Fonts[aFont]; //Shortcut

  //Calculate line count and each lines width to be able to properly aAlign them
  lineCount := 1;
  if not aShowEolSymbol then
    for I := 1 to Length(aText) do
      if aText[I] = #124 then
        Inc(lineCount);

  SetLength(lineWidth, lineCount+2); //1..n+1 (for last line)

  lineCount := 1;

  for I := 1 to Length(aText) do
  begin
    if aText[I] = #9 then // Tab char
      lineWidthInc := (Floor(lineWidth[lineCount] / aTabWidth) + 1) * aTabWidth - lineWidth[lineCount]
    else
      lineWidthInc := fontSpec.GetCharWidth(aText[I], aShowEolSymbol);
    Inc(lineWidth[lineCount], lineWidthInc);

    //If EOL or aText end
    if (not aShowEolSymbol and (aText[I] = #124)) or (I = Length(aText)) then
    begin
      if aText[I] <> #9 then // for Tab reduce line width for CharSpacing and also for TAB 'jump'
        lineWidthInc := 0;
      lineWidth[lineCount] := Math.max(0, lineWidth[lineCount] - fontSpec.CharSpacing - lineWidthInc); //Remove last interletter space and negate double EOLs
      Inc(lineCount);
    end;
  end;

  lineHeight := fontSpec.BaseHeight + fontSpec.LineSpacing;

  dec(lineCount);
  blockWidth := 0;
  for I := 1 to lineCount do
    blockWidth := Math.Max(blockWidth, lineWidth[I]);

  case aAlign of
    taLeft:   dx := aLeft;
    taCenter: dx := aLeft + (aWidth - lineWidth[1]) div 2;
    taRight:  dx := aLeft + aWidth - lineWidth[1];
    else      dx := aLeft;
  end;
  dy := aTop;
  lineCount := 1;

  glColor4ubv(@aColor);

  K := 0;
  prevAtlas := -1;
  for I := 1 to Length(aText) do
  begin
    //Loop as there might be adjoined tags on same position
    while (K < Length(colors)) and (I = colors[K].FirstChar) do
    begin
      if colors[K].Color = 0 then
        glColor4ubv(@aColor)
      else
        glColor4ubv(@colors[K].Color);
      Inc(K);
    end;

    case aText[I] of
      #9:   dx := aLeft + (Floor((dx - aLeft) / aTabWidth) + 1) * aTabWidth;
      #32:  Inc(dx, fontSpec.WordSpacing);
      #124: if aShowEolSymbol then
              DrawLetter
            else
            begin
              //KaM uses #124 or vertical bar (|) for new lines in the LIB files,
              //so lets do the same here. Saves complex conversions...
              Inc(dy, lineHeight);
              Inc(lineCount);
              case aAlign of
                taLeft:   dx := aLeft;
                taCenter: dx := aLeft + (aWidth - lineWidth[lineCount]) div 2;
                taRight:  dx := aLeft + aWidth - lineWidth[lineCount];
              end;
            end;
    else
      DrawLetter;
    end;

    //When we reach the end, if we painted something then we need to end it
    if (I = Length(aText)) and (prevAtlas <> -1) then
      glEnd;
  end;

  if DBG_SHOW_TEXT_OUTLINES then
  begin
    TKMRender.BindTexture(0);
    glPushMatrix;
      case aAlign of
        taLeft:   glTranslatef(aLeft,                               aTop, 0);
        taCenter: glTranslatef(aLeft + (aWidth - blockWidth) div 2, aTop, 0);
        taRight:  glTranslatef(aLeft + (aWidth - blockWidth),       aTop, 0);
      end;

      glColor4f(1,0,0,0.5);
      glBegin(GL_LINE_LOOP);
        glVertex2f(0.5           , 0.5       );
        glVertex2f(blockWidth+0.5, 0.5       );
        glVertex2f(blockWidth+0.5, lineHeight*lineCount+0.5);
        glVertex2f(0.5           , lineHeight*lineCount+0.5);
      glEnd;

      glBegin(GL_LINE_LOOP);
        glVertex2f(0.5           , 0.5       );
        glVertex2f(blockWidth+0.5, 0.5       );
        glVertex2f(blockWidth+0.5, lineHeight+0.5);
        glVertex2f(0.5           , lineHeight+0.5);
      glEnd;
    glPopMatrix;
  end;

  if setupClipXApplied then
    ReleaseClipX;
end;


class procedure TKMRenderUI.WriteTextInShape(const aText: string; X,Y: SmallInt; aLineColor, aTextColor: Cardinal; aShapeColor1: Cardinal = $80000000;
                                             aText2: string = ''; aShapeColor2: Cardinal = 0; aTextColor2: Cardinal = 0);
var
  W, W1, W2: Integer;
  hasText2: Boolean;
begin
  TKMRender.BindTexture(0);

  hasText2 := aShapeColor2 <> 0;

  W1 := 10 + 10 * Length(aText);
  W2 := Ord(hasText2)*(10 + 10 * Length(aText2));
  W := W1 + W2;
  WriteShape(X - W div 2, Y - 10, W1, 20, aShapeColor1);

  if hasText2 then
  begin
    WriteShape  (X - W div 2 + W1, Y - 10, W2, 20, aShapeColor2);
    WriteText   (X - W div 2 + W1 + W2 div 2, Y - 7, 0, aText2, fntMetal, taCenter, aTextColor2);
    WriteOutline(X - W div 2, Y - 10, W, 20, 2, aLineColor); // Outline for both texts
    // Separator between texts
    WriteLine   (X - W div 2 + W1, Y - 10,
                 X - W div 2 + W1, Y + 10, aLineColor, $FFFF, 2);
  end
  else
    WriteOutline(X - W div 2, Y - 10, W1, 20, 2, aLineColor);

  //Paint the label on top of the background
  WriteText(X - ((W - W1) div 2), Y - 7, 0, aText, fntMetal, taCenter, aTextColor);
end;


class procedure TKMRenderUI.WriteTexture(aLeft, aTop, aWidth, aHeight: SmallInt; const aTexture: TTexture; aCol: TColor4);
begin
  TKMRender.BindTexture(aTexture.Tex);

  glColor4ubv(@aCol);
  glBegin(GL_QUADS);
    glTexCoord2f(0, 0);                   glVertex2f(aLeft, aTop);
    glTexCoord2f(aTexture.U, 0);          glVertex2f(aLeft+aWidth, aTop);
    glTexCoord2f(aTexture.U, aTexture.V); glVertex2f(aLeft+aWidth, aTop+aHeight);
    glTexCoord2f(0, aTexture.V);          glVertex2f(aLeft, aTop+aHeight);
  glEnd;
end;


class procedure TKMRenderUI.WriteCircle(aCenterX, aCenterY: SmallInt; aRadius: Byte; aFillColor: TColor4);
var
  ang: Single;
  I: Byte;
begin
  if aRadius = 0 then Exit;

  // Reset texture to default (0), because it could be bind to any other texture (atlas)
  TKMRender.BindTexture(0);

  glColor4ubv(@aFillColor);
  glBegin(GL_POLYGON);
    for I := 0 to 15 do
    begin
      ang := I / 8 * Pi;
      glVertex2f(aCenterX + Sin(ang) * aRadius, aCenterY + Cos(ang) * aRadius);
    end;
  glEnd;
end;


class procedure TKMRenderUI.WriteShadow(aLeft, aTop, aWidth, aHeight: SmallInt; aBlur: Byte; aCol: TColor4);

  procedure DoNode(aX, aY: Single; aColor: TColor4);
  begin
    glColor4ubv(@aColor);
    glVertex2f(aX, aY);
  end;

var
  bCol: TColor4;
begin
  //Same color, but fully transparent
  bCol := aCol and $FFFFFF;

  // Reset texture to default (0), because it could be bind to any other texture (atlas)
  TKMRender.BindTexture(0);

  glPushMatrix;
  try
    //Slightly shifted shadow looks nicer
    glTranslatef(aLeft + aBlur / 8, aTop + aBlur / 6, 0);

    glColor4ubv(@aCol);
    glBegin(GL_QUADS);
      glkRect(0, 0, aWidth, aHeight);
    glEnd;

    glBegin(GL_QUAD_STRIP);
      DoNode(-aBlur, 0, bCol);
      DoNode(0, 0, aCol);
      DoNode(-aBlur * 0.7, -aBlur * 0.7, bCol);
      DoNode(0, 0, aCol);
      DoNode(0, -aBlur, bCol);
      DoNode(0, 0, aCol);

      DoNode(aWidth, -aBlur, bCol);
      DoNode(aWidth, 0, aCol);
      DoNode(aWidth + aBlur * 0.7, -aBlur * 0.7, bCol);
      DoNode(aWidth, 0, aCol);
      DoNode(aWidth + aBlur, 0, bCol);
      DoNode(aWidth, 0, aCol);

      DoNode(aWidth + aBlur, aHeight, bCol);
      DoNode(aWidth, aHeight, aCol);
      DoNode(aWidth + aBlur * 0.7, aHeight + aBlur * 0.7, bCol);
      DoNode(aWidth, aHeight, aCol);
      DoNode(aWidth, aHeight + aBlur, bCol);
      DoNode(aWidth, aHeight, aCol);

      DoNode(0, aHeight + aBlur, bCol);
      DoNode(0, aHeight, aCol);
      DoNode(-aBlur * 0.7, aHeight + aBlur * 0.7, bCol);
      DoNode(0, aHeight, aCol);
      DoNode(-aBlur, aHeight, bCol);
      DoNode(0, aHeight, aCol);

      DoNode(-aBlur, 0, bCol);
      DoNode(0, 0, aCol);
    glEnd;
  finally
    glPopMatrix;
  end;
end;


initialization
begin
  {$IF DEFINED(WDC) OR DEFINED(FPC)} // FPC: same nested clipping as Delphi
  //todo -cPractical: Move into class constructor
  TKMRenderUI.fClipXStack := TStack<TKMRangeInt>.Create;
  TKMRenderUI.fClipYStack := TStack<TKMRangeInt>.Create;
  {$ENDIF}
end;


finalization
begin
  {$IF DEFINED(WDC) OR DEFINED(FPC)} // FPC: same nested clipping as Delphi
  TKMRenderUI.fClipXStack.Free;
  TKMRenderUI.fClipYStack.Free;
  {$ENDIF}
end;


end.
