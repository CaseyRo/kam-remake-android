unit KM_Achievements;
{$I KaM_Remake.inc}
// Single player achievements: unlocked when a mission is won, kept in Achievements.txt next to the settings file.
// shortcut: titles are English only, move them into the text libraries (gResTexts) when they need translating
interface

type
  TKMAchievement = (
    acFirstVictory, acApprentice, acMasterBuilder, acWarlord, acBloodless, acUnbroken, acSwift,
    acShatteredKingdom, acPeasantsRebellion);

  // What the rules look at, taken from the human player's statistics when the mission is won
  TKMAchievementFacts = record
    Mission: string;       // Mission name
    Campaign: string;      // Campaign id ('TSK', 'TPR', ..), '' outside campaigns
    LastMission: Boolean;  // Last mission of that campaign
    Minutes: Single;       // Game time
    HousesBuilt, HousesLost, WarriorsKilled, WarriorsLost: Integer;
  end;

const
  ACHIEVEMENT_TITLE: array [TKMAchievement] of string = (
    'First Victory', 'Apprentice', 'Master Builder', 'Warlord', 'Bloodless', 'Unbroken', 'Swift',
    'The Shattered Kingdom', 'The Peasants Rebellion');
  ACHIEVEMENT_HINT: array [TKMAchievement] of string = (
    'Win a mission',
    'Win a tutorial',
    'Win a mission in which you built 30 houses',
    'Win a mission in which you defeated 100 enemy soldiers',
    'Win a battle of 20 or more defeated soldiers without losing one of your own',
    'Win a mission in which you built 10 houses and lost none',
    'Win a mission that is not a tutorial within 30 minutes',
    'Finish the campaign The Shattered Kingdom',
    'Finish the campaign The Peasants Rebellion');

function AchievementEarned(aAchievement: TKMAchievement; const aFacts: TKMAchievementFacts): Boolean;
function AchievementUnlocked(aAchievement: TKMAchievement): Boolean;
// Call once the human player has won a single player mission.
// Returns the titles this win unlocked, separated by ', ' ('' when there are none)
function AchievementsMissionWon: string;


implementation
uses
  Classes, SysUtils, TypInfo,
  {$IFDEF ANDROID} KMAndroidHost, {$ENDIF}
  KM_Game, KM_GameParams, KM_GameApp, KM_GameAppSettings, KM_HandsCollection, KM_Campaigns;


function IsTutorial(const aMission: string): Boolean;
begin
  Result := Pos('tutorial', LowerCase(aMission)) > 0;
end;


function AchievementEarned(aAchievement: TKMAchievement; const aFacts: TKMAchievementFacts): Boolean;
begin
  case aAchievement of
    acFirstVictory:      Result := True;
    acApprentice:        Result := IsTutorial(aFacts.Mission);
    acMasterBuilder:     Result := aFacts.HousesBuilt >= 30;
    acWarlord:           Result := aFacts.WarriorsKilled >= 100;
    acBloodless:         Result := (aFacts.WarriorsKilled >= 20) and (aFacts.WarriorsLost = 0);
    acUnbroken:          Result := (aFacts.HousesBuilt >= 10) and (aFacts.HousesLost = 0);
    acSwift:             Result := (aFacts.Minutes <= 30) and not IsTutorial(aFacts.Mission);
    acShatteredKingdom:  Result := aFacts.LastMission and (aFacts.Campaign = 'TSK');
    acPeasantsRebellion: Result := aFacts.LastMission and (aFacts.Campaign = 'TPR');
    else                 Result := False;
  end;
end;


function StoreFile: string;
begin
  Result := ExtractFilePath(gGameAppSettings.Path) + 'Achievements.txt';
end;


// One achievement name per line. The list is tiny, so it is simply read from disk whenever it is needed
function LoadUnlocked: TStringList;
begin
  Result := TStringList.Create;
  try
    if FileExists(StoreFile) then
      Result.LoadFromFile(StoreFile);
  except
    Result.Clear; // An unreadable file only costs the list, never the game
  end;
end;


function KeyOf(aAchievement: TKMAchievement): string;
begin
  Result := GetEnumName(TypeInfo(TKMAchievement), Ord(aAchievement));
end;


function AchievementUnlocked(aAchievement: TKMAchievement): Boolean;
var
  list: TStringList;
begin
  list := LoadUnlocked;
  try
    Result := list.IndexOf(KeyOf(aAchievement)) <> -1;
  finally
    list.Free;
  end;
end;


function AchievementsMissionWon: string;
var
  facts: TKMAchievementFacts;
  camp: TKMCampaign;
  list: TStringList;
  A: TKMAchievement;
begin
  Result := '';
  if (gGame = nil) or (gMySpectator = nil) then Exit;

  facts.Mission := gGameParams.Name;
  facts.Campaign := '';
  facts.LastMission := False;
  if gGameParams.IsCampaign and (gGame.CampaignName <> nil) then
  begin
    facts.Campaign := string(gGame.CampaignName.ID);
    camp := gGameApp.Campaigns.CampaignById(gGame.CampaignName);
    facts.LastMission := (camp <> nil) and (gGame.CampaignMap = camp.Spec.MissionsCount - 1);
  end;
  facts.Minutes := gGameParams.Tick / 600; // 10 ticks per second
  with gMySpectator.Hand.Stats do
  begin
    facts.HousesBuilt := GetHousesBuilt;
    facts.HousesLost := GetHousesLost;
    facts.WarriorsKilled := GetWarriorsKilled;
    facts.WarriorsLost := GetWarriorsLost;
  end;

  list := LoadUnlocked;
  try
    for A := Low(TKMAchievement) to High(TKMAchievement) do
    begin
      if (list.IndexOf(KeyOf(A)) = -1) and AchievementEarned(A, facts) then
      begin
        list.Add(KeyOf(A));
        if Result <> '' then Result := Result + ', ';
        Result := Result + ACHIEVEMENT_TITLE[A];
      end;
      {$IFDEF ANDROID}
      // Every win reports all unlocked ones again, so the host catches up on any it missed (reporting is idempotent)
      if Assigned(gHostAchievement) and (list.IndexOf(KeyOf(A)) <> -1) then
        gHostAchievement(PAnsiChar(AnsiString(KeyOf(A))));
      {$ENDIF}
    end;
    if Result <> '' then
      try
        list.SaveToFile(StoreFile);
      except
        Result := ''; // Not stored, so do not announce it
      end;
  finally
    list.Free;
  end;
end;


{$IFOPT C+}
// Self-check of the rules (only in builds with assertions)
procedure SelfCheck;
var
  f: TKMAchievementFacts;
begin
  f := Default(TKMAchievementFacts);
  f.Mission := 'Town Tutorial';
  f.Minutes := 20;
  Assert(AchievementEarned(acFirstVictory, f) and AchievementEarned(acApprentice, f));
  Assert(not AchievementEarned(acSwift, f), 'tutorials do not count as swift');
  Assert(not AchievementEarned(acBloodless, f) and not AchievementEarned(acUnbroken, f), 'needs a real battle / town');
  f.Mission := 'Mission 20';
  f.Campaign := 'TSK';
  f.LastMission := True;
  f.HousesBuilt := 30;
  f.WarriorsKilled := 100;
  Assert(AchievementEarned(acSwift, f) and AchievementEarned(acMasterBuilder, f) and AchievementEarned(acWarlord, f));
  Assert(AchievementEarned(acBloodless, f) and AchievementEarned(acUnbroken, f));
  Assert(AchievementEarned(acShatteredKingdom, f) and not AchievementEarned(acPeasantsRebellion, f));
  f.WarriorsLost := 1;
  f.HousesLost := 1;
  Assert(not AchievementEarned(acBloodless, f) and not AchievementEarned(acUnbroken, f));
end;


initialization
  SelfCheck;
{$ENDIF}

end.
