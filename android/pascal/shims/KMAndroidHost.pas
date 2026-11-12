unit KMAndroidHost;
{$mode delphi}
// State shared between the Android host (JNI glue) and LCL replacement units
interface
uses
  Types;

type
  TKMHostMessageProc = procedure(const aTitle, aText: UnicodeString);
  TKMHostClipboardSet = procedure(const aText: UnicodeString);
  TKMHostClipboardGet = function: UnicodeString;
  TKMHostOpenURL = procedure(const aURL: UnicodeString);
  TKMHostQuit = procedure;
  TKMHostPlayVideo = procedure(const aPath: UnicodeString; aVolume: Integer; aStretch: Boolean);
  TKMHostStopVideo = procedure;

var
  // Pointer position in render area coordinates
  gHostCursorPos: TPoint;
  // Pressed state of virtual keys (Windows VK codes)
  gHostKeyDown: array [0..255] of Boolean;
  gHostScreenWidth: Integer = 1920;
  gHostScreenHeight: Integer = 1080;
  gHostAppActive: Boolean = True;
  // Debug switches read from <data>/dbg.txt (render bisecting on device)
  gAndroidDbgMask: Cardinal = 0;
  // Called right after GL entry points are loaded
  gOnGLInitialized: procedure;



  gHostShowMessage: TKMHostMessageProc;
  gHostClipboardSet: TKMHostClipboardSet;
  gHostClipboardGet: TKMHostClipboardGet;
  gHostOpenURL: TKMHostOpenURL;
  gHostQuit: TKMHostQuit;
  gHostPlayVideo: TKMHostPlayVideo;
  gHostStopVideo: TKMHostStopVideo;
  // Optional: tells the host an achievement is unlocked (iOS reports it to Game Center), see KM_Achievements
  gHostAchievement: procedure(aId: PAnsiChar); cdecl;
  // Optional: a host with a resizable window (Mac). Applies the window mode and the game resolution, given as the
  // number of game pixels in the height of the view; the width follows the window's shape
  gHostSetDisplay: procedure(aFullScreen, aHeight: Integer); cdecl;



implementation

end.
