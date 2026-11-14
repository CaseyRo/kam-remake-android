unit KMAndroidLog;
{$mode delphi}
// Logging into Android logcat (tag "KaM")
interface

procedure ALog(const aText: string);

implementation

const
  ANDROID_LOG_INFO = 4;

{$IFNDEF DARWIN}
function __android_log_write(prio: Integer; tag, text: PAnsiChar): Integer; cdecl; external 'log';
{$ENDIF}

procedure ALog(const aText: string);
var
  s: AnsiString;
begin
  s := UTF8Encode(aText);
  {$IFDEF DARWIN}
  WriteLn(StdErr, 'KaM: ', s); // iOS port: shows up in the Xcode/device console
  {$ELSE}
  __android_log_write(ANDROID_LOG_INFO, 'KaM', PAnsiChar(s));
  {$ENDIF}
end;

end.
