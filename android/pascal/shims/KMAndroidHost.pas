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
  // Size the engine lays out and renders against, in UI units (buffer px / gHostUIScale)
  gHostScreenWidth: Integer = 1920;
  gHostScreenHeight: Integer = 1080;
  // Native GL buffer size in px
  gHostBufferWidth: Integer = 1920;
  gHostBufferHeight: Integer = 1080;
  // Buffer px per UI unit
  gHostUIScale: Single = 1;
  // Buffer px per OS point (UIScreen.scale, DisplayMetrics.density)
  gHostDensity: Single = 1;
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
  // Optional: a host with a resizable window (Mac). Applies the window mode
  gHostSetDisplay: procedure(aFullScreen: Integer); cdecl;



implementation

end.
