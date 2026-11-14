unit KM_GUIMenuAchievements;
{$I KaM_Remake.inc}
// Main menu page listing the achievements (see KM_Achievements)
interface
uses
  KM_Controls, KM_ControlsBase,
  KM_Achievements, KM_InterfaceDefaults, KM_InterfaceTypes;


type
  TKMMenuAchievements = class(TKMMenuPageCommon)
  private
    fOnPageChange: TKMMenuChangeEventText;
    procedure BackClick(Sender: TObject);
  protected
    Panel_Achievements: TKMPanel;
    Label_Title: array [TKMAchievement] of TKMLabel;
    Button_Back: TKMButton;
  public
    constructor Create(aParent: TKMPanel; aOnPageChange: TKMMenuChangeEventText);
    procedure Show;
  end;


implementation
uses
  KM_RenderUI, KM_ResTexts, KM_ResFonts;


constructor TKMMenuAchievements.Create(aParent: TKMPanel; aOnPageChange: TKMMenuChangeEventText);
const
  ROW_HEIGHT = 50;
var
  A: TKMAchievement;
  top: Integer;
begin
  inherited Create(gpAchievements);

  fOnPageChange := aOnPageChange;
  OnEscKeyDown := BackClick;

  Panel_Achievements := TKMPanel.Create(aParent, 0, 0, aParent.Width, aParent.Height);
  Panel_Achievements.AnchorsStretch;

    TKMLabel.Create(Panel_Achievements, aParent.Width div 2, 70, 'Achievements', fntOutline, taCenter);
    for A := Low(TKMAchievement) to High(TKMAchievement) do
    begin
      top := 120 + Ord(A) * ROW_HEIGHT;
      Label_Title[A] := TKMLabel.Create(Panel_Achievements, aParent.Width div 2, top, '', fntMetal, taCenter);
      TKMLabel.Create(Panel_Achievements, aParent.Width div 2, top + 20, ACHIEVEMENT_HINT[A], fntGrey, taCenter);
    end;

    Button_Back := TKMButton.Create(Panel_Achievements, 400, 700, 224, 30, gResTexts[TX_MENU_BACK], bsMenu);
    Button_Back.Anchors := [anLeft, anBottom];
    Button_Back.OnClick := BackClick;
end;


procedure TKMMenuAchievements.Show;
var
  A: TKMAchievement;
begin
  for A := Low(TKMAchievement) to High(TKMAchievement) do
    if AchievementUnlocked(A) then
      Label_Title[A].Caption := '[$00D0FF]' + ACHIEVEMENT_TITLE[A] + '[]' // Gold
    else
      Label_Title[A].Caption := '[$808080]' + ACHIEVEMENT_TITLE[A] + ' (locked)[]';

  Panel_Achievements.Show;
end;


procedure TKMMenuAchievements.BackClick(Sender: TObject);
begin
  fOnPageChange(gpMainMenu);
end;


end.
