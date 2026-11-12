// iPad host for the KaM Remake engine (libkamcore.dylib, Free Pascal): window, OpenGL ES context, touch and keyboard.
// Counterpart of the Android host (android/app/src/main: KaMActivity/KaMView/KaMSurfaceView + kamhost.c).
// The engine draws with desktop OpenGL through gl4es (linked into the engine), which calls into OpenGLES.framework.
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <GameKit/GameKit.h>
#import <GameController/GameController.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#include <pthread.h>
#include <objc/message.h>

// ---------- Engine C API (android/pascal/KM_AndroidExports.pas) ----------
typedef struct {
  void (*ShowMessage)(const char *title, const char *text);
  void (*ClipboardSet)(const char *text);
  const char *(*ClipboardGet)(void);
  void (*OpenURL)(const char *url);
  void (*Quit)(void);
  void (*PlayVideo)(const char *path, int volume, int stretch);
  void (*StopVideo)(void);
} kam_host_callbacks;

extern void kam_set_callbacks(kam_host_callbacks *cb);
extern int kam_init(const char *dataDir, int width, int height);
extern void kam_frame(void);
extern void kam_resize(int width, int height);
extern void kam_pause(void);
extern void kam_resume(void);
extern void kam_mouse(int action, int button, int x, int y);
extern void kam_wheel(int steps, int x, int y);
extern void kam_touch(int action, int count, float x0, float y0, float x1, float y1);
extern void kam_key(int action, int vk, int shift);
extern void kam_char(int ch);
extern int kam_text_input_active(void);
extern void kam_video_finished(void);
extern void kam_selftest(const char *mode);
extern void kam_set_achievement_callback(void (*callback)(const char *identifier));
extern void kam_set_display_callback(void (*callback)(int fullScreen, int height));

enum { TOUCH_DOWN = 0, TOUCH_MOVE = 1, TOUCH_UP = 2, TOUCH_CANCEL = 3, TOUCH_POINTER_DOWN = 5, TOUCH_POINTER_UP = 6 };
enum { VK_BACK = 8, VK_RETURN = 13, VK_SPACE = 32 };
// Game resolution the original UI is designed for (same as the Android port)
static const float BASE_WIDTH = 1024, BASE_HEIGHT = 720;
// Game pixels in the height of the view. Fixed on touch devices; on a Mac the Options page changes it (cb_set_display)
static float gGameHeight = BASE_HEIGHT;
// Deep recursion in the engine (terrain flood fill on big maps) needs far more than the default thread stack
static const size_t RENDER_THREAD_STACK = 128u << 20;

@class KaMView;
static KaMView *gView;
@class KaMVideoView;
static KaMVideoView *gVideo; // video being played, nil otherwise
static void video_finish(void);

// ---------- View: owns the GL layer, the render thread and input ----------
@interface KaMView : UIView <UIKeyInput>
- (void)startWithDataDir:(NSString *)dataDir;
- (void)setPaused:(BOOL)paused;
- (void)post:(dispatch_block_t)event;
- (void)relayout;
- (void)handlePresses:(NSSet<UIPress *> *)presses down:(BOOL)down;
@end

@implementation KaMView {
  NSString *_dataDir;
  NSMutableArray<dispatch_block_t> *_events; // run on the render thread before the next frame
  NSMutableArray<UITouch *> *_touches;       // active touches, oldest first
  EAGLContext *_context;
  GLuint _fbo, _color, _depth;
  int _bufW, _bufH;                          // render buffer (game resolution) in pixels
  CGSize _layoutSize;                        // view size in points the buffers were made for
  volatile BOOL _paused, _resized;
  BOOL _keyboardShown;
  int _frame;
  int _mouseButton;                          // button of the pointer press in progress
  CGFloat _scrollAcc;
  BOOL _spacePanning, _spaceUsedForPan;      // Space + pointer movement pans the map
}

+ (Class)layerClass { return [CAEAGLLayer class]; }

- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    _events = [NSMutableArray new];
    _touches = [NSMutableArray new];
    self.multipleTouchEnabled = YES;
    self.layer.opaque = YES;
    [self addGestureRecognizer:[[UIHoverGestureRecognizer alloc] initWithTarget:self action:@selector(hover:)]];
    UIPanGestureRecognizer *scroll = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(scroll:)];
    scroll.allowedScrollTypesMask = UIScrollTypeMaskAll; // mouse wheel and trackpad scrolling only,
    scroll.allowedTouchTypes = @[];                      // fingers stay with touchesBegan
    [self addGestureRecognizer:scroll];
  }
  return self;
}

- (void)post:(dispatch_block_t)event {
  @synchronized(_events) { [_events addObject:[event copy]]; }
}

- (void)layoutSubviews {
  [super layoutSubviews];
  CGSize s = self.bounds.size;
  if (s.width <= 0 || CGSizeEqualToSize(s, _layoutSize)) return;
  _layoutSize = s;
  // The layer buffer gets the game resolution and is stretched to the screen, so the original UI stays readable
  // Never more game pixels than the display has
  float gameHeight = MAX(BASE_HEIGHT, MIN(gGameHeight, s.height * (self.window.screen.scale ?: 1)));
  float scale = MAX(MIN(s.height / gameHeight, s.width / (gameHeight * BASE_WIDTH / BASE_HEIGHT)), 0.25f);
  self.layer.contentsScale = 1 / scale;
  _resized = YES;
}

// The game resolution changed: lay out again although the view kept its size
- (void)relayout {
  _layoutSize = CGSizeZero;
  [self setNeedsLayout];
}

// Render thread. (Re)creates the framebuffer for the current layer size
- (void)createBuffers {
  if (_fbo) {
    glDeleteFramebuffers(1, &_fbo);
    glDeleteRenderbuffers(1, &_color);
    glDeleteRenderbuffers(1, &_depth);
  }
  glGenFramebuffers(1, &_fbo);
  glBindFramebuffer(GL_FRAMEBUFFER, _fbo);
  glGenRenderbuffers(1, &_color);
  glBindRenderbuffer(GL_RENDERBUFFER, _color);
  [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _color);
  glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_bufW);
  glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_bufH);
  glGenRenderbuffers(1, &_depth);
  glBindRenderbuffer(GL_RENDERBUFFER, _depth);
  glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8_OES, _bufW, _bufH);
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _depth);
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, _depth);
  NSLog(@"KaMHost: framebuffer %dx%d, status %x", _bufW, _bufH, glCheckFramebufferStatus(GL_FRAMEBUFFER));
}

// Test aid: KAM_TAPS="12:548,340;15:300,200" taps those game coordinates that many seconds after start
- (void)testTaps {
  static const char *p;
  static double t0, at;
  static int x, y, state; // 0 read next, 1 wait for press, 2 wait for release
  if (!p) { p = getenv("KAM_TAPS") ?: ""; t0 = CACurrentMediaTime(); }
  double now = CACurrentMediaTime() - t0;
  if (state == 0) {
    int n = 0;
    if (sscanf(p, "%lf:%d,%d%n", &at, &x, &y, &n) < 3) return;
    p += n + (p[n] == ';');
    state = 1;
  }
  if (state == 1 && now >= at) {
    if (gVideo) dispatch_async(dispatch_get_main_queue(), ^{ video_finish(); }); // like a real tap, which lands on the video
    else kam_touch(TOUCH_DOWN, 1, x, y, x, y);
    state = 2;
    at = now + 0.1;
  }
  else if (state == 2 && now >= at) { kam_touch(TOUCH_UP, 1, x, y, x, y); state = 0; }
}

- (void)renderLoop {
  _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
  [EAGLContext setCurrentContext:_context];
  _resized = NO;
  [self createBuffers];
  setenv("LIBGL_LOGSHADERERROR", "1", 1); // gl4es setting, read when the engine initializes it
  if (NSProcessInfo.processInfo.isiOSAppOnMac) setenv("KAM_SHOW_QUIT", "1", 1); // main menu keeps "Exit Game" on a Mac

  if (!kam_init(_dataDir.fileSystemRepresentation, _bufW, _bufH)) return; // the engine has shown the reason

  for (;;) {
    @autoreleasepool {
      NSArray<dispatch_block_t> *events;
      @synchronized(_events) {
        events = [_events copy];
        [_events removeAllObjects];
      }
      for (dispatch_block_t e in events) e();
      if (_paused) { usleep(50000); continue; } // no GL calls in the background: iOS kills the app for them
      if (_resized) {
        _resized = NO;
        [self createBuffers];
        kam_resize(_bufW, _bufH);
      }
      // gl4es never binds a framebuffer for this engine, but keep ours bound whatever it does internally
      glBindFramebuffer(GL_FRAMEBUFFER, _fbo);
      kam_frame();
      glBindRenderbuffer(GL_RENDERBUFFER, _color);
      [_context presentRenderbuffer:GL_RENDERBUFFER];

      // Content smoke test (see KM_AndroidSelfTest.pas): KAM_SELFTEST=campaigns ios/run_ipad.sh 300
      const char *test = getenv("KAM_SELFTEST");
      if (_frame == 120 && test && *test) kam_selftest(test);
      [self testTaps];
      if (++_frame % 15 == 0) {
        BOOL want = kam_text_input_active() != 0;
        if (want != _keyboardShown) {
          _keyboardShown = want;
          dispatch_async(dispatch_get_main_queue(), ^{
            // Without a text field the view controller is first responder, for hardware keys
            if (want) [self becomeFirstResponder]; else [self.window.rootViewController becomeFirstResponder];
          });
        }
      }
    }
  }
}

static void *render_thread(void *arg) {
  pthread_setname_np("KaMRender");
  [(__bridge KaMView *)arg renderLoop];
  return NULL;
}

- (void)startWithDataDir:(NSString *)dataDir {
  _dataDir = dataDir;
  pthread_attr_t attr;
  pthread_attr_init(&attr);
  pthread_attr_setstacksize(&attr, RENDER_THREAD_STACK);
  pthread_t t;
  pthread_create(&t, &attr, render_thread, (__bridge void *)self);
  pthread_detach(t);
}

// Blocks until the render thread has stopped drawing (called when the app leaves the foreground)
- (void)setPaused:(BOOL)paused {
  if (!_dataDir || paused == _paused) return;
  dispatch_semaphore_t done = dispatch_semaphore_create(0);
  [self post:^{
    if (paused) { kam_pause(); glFinish(); } else kam_resume();
    self->_paused = paused;
    dispatch_semaphore_signal(done);
  }];
  dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC));
}

// ---------- Touch: the engine turns touches into mouse actions and gestures itself ----------
- (void)sendTouch:(int)action {
  NSUInteger count = _touches.count;
  if (count == 0) return;
  float sx = _bufW / self.bounds.size.width, sy = _bufH / self.bounds.size.height;
  CGPoint p0 = [_touches[0] locationInView:self];
  CGPoint p1 = count > 1 ? [_touches[1] locationInView:self] : p0;
  [self post:^{ kam_touch(action, (int)count, p0.x * sx, p0.y * sy, p1.x * sx, p1.y * sy); }];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  for (UITouch *t in touches) {
    if (t.type == UITouchTypeIndirectPointer) {
      _mouseButton = (event.buttonMask & UIEventButtonMaskSecondary) ? 1 : 0;
      [self sendMouse:TOUCH_DOWN button:_mouseButton at:[t locationInView:self]];
      continue;
    }
    [_touches addObject:t];
    [self sendTouch:_touches.count == 1 ? TOUCH_DOWN : TOUCH_POINTER_DOWN];
  }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  for (UITouch *t in touches)
    if (t.type == UITouchTypeIndirectPointer) [self sendMouse:TOUCH_MOVE button:0 at:[t locationInView:self]];
  [self sendTouch:TOUCH_MOVE];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  for (UITouch *t in touches) {
    if (t.type == UITouchTypeIndirectPointer) [self sendMouse:TOUCH_UP button:_mouseButton at:[t locationInView:self]];
    if (![_touches containsObject:t]) continue;
    [self sendTouch:_touches.count == 1 ? TOUCH_UP : TOUCH_POINTER_UP];
    [_touches removeObject:t];
  }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  for (UITouch *t in touches)
    if (t.type == UITouchTypeIndirectPointer) [self sendMouse:TOUCH_UP button:_mouseButton at:[t locationInView:self]];
  [self sendTouch:TOUCH_CANCEL];
  [_touches removeAllObjects];
}

// ---------- Mouse / trackpad (Info.plist: UIApplicationSupportsIndirectInputEvents) ----------
- (void)sendMouse:(int)action button:(int)button at:(CGPoint)p {
  int x = p.x * _bufW / self.bounds.size.width, y = p.y * _bufH / self.bounds.size.height;
  if (getenv("KAM_LOG_INPUT") && action != TOUCH_MOVE) NSLog(@"KaMHost: mouse %s button=%d at %d,%d", action == TOUCH_DOWN ? "down" : "up", button, x, y);
  [self post:^{ kam_mouse(action, button, x, y); }];
}

// The physical state of the Space key. Key events cannot tell: while a key is held, a Mac delivers its auto-repeat
// as a stream of press/release pairs
static BOOL space_is_down(void) {
  return [GCKeyboard.coalescedKeyboard.keyboardInput buttonForKeyCode:GCKeyCodeSpacebar].isPressed;
}

- (void)hover:(UIHoverGestureRecognizer *)g {
  if (g.state != UIGestureRecognizerStateBegan && g.state != UIGestureRecognizerStateChanged) return;
  CGPoint p = [g locationInView:self];
  if (!space_is_down()) {
    if (_spacePanning) { _spacePanning = NO; [self post:^{ kam_touch(TOUCH_CANCEL, 1, 0, 0, 0, 0); }]; } // cancel: no click at the end
    [self sendMouse:TOUCH_MOVE button:0 at:p];
    return;
  }
  // Space held: the pointer drags the map like a finger does (the engine pans on a one-finger drag)
  float x = p.x * _bufW / self.bounds.size.width, y = p.y * _bufH / self.bounds.size.height;
  int action = _spacePanning ? TOUCH_MOVE : TOUCH_DOWN;
  if (getenv("KAM_LOG_INPUT") && !_spacePanning) NSLog(@"KaMHost: pan starts at %.0f,%.0f", x, y);
  _spacePanning = _spaceUsedForPan = YES;
  [self post:^{ kam_touch(action, 1, x, y, x, y); }];
}

- (void)scroll:(UIPanGestureRecognizer *)g {
  static const CGFloat POINTS_PER_STEP = 30;
  _scrollAcc += [g translationInView:self].y;
  [g setTranslation:CGPointZero inView:self];
  CGPoint p = [g locationInView:self];
  int x = p.x * _bufW / self.bounds.size.width, y = p.y * _bufH / self.bounds.size.height;
  for (; fabs(_scrollAcc) >= POINTS_PER_STEP; _scrollAcc -= copysign(POINTS_PER_STEP, _scrollAcc)) {
    int step = _scrollAcc > 0 ? 1 : -1;
    if (getenv("KAM_LOG_INPUT")) NSLog(@"KaMHost: wheel %d", step);
    [self post:^{ kam_wheel(step, x, y); }];
  }
}

// ---------- Hardware keyboard: USB HID usages -> Windows virtual keys (same table as android/KeyMap.java) ----------
static int vk_from_hid(long u) {
  if (u >= 0x04 && u <= 0x1D) return 'A' + (int)(u - 0x04);
  if (u >= 0x1E && u <= 0x26) return '1' + (int)(u - 0x1E);
  if (u >= 0x3A && u <= 0x45) return 112 + (int)(u - 0x3A); // F1..F12
  if (u >= 0x59 && u <= 0x61) return 97 + (int)(u - 0x59);  // keypad 1..9
  switch (u) {
    case 0x27: return '0';
    case 0x28: case 0x58: return VK_RETURN;
    case 0x29: return 27;
    case 0x2A: return VK_BACK;
    case 0x2B: return 9;
    case 0x2C: return 32;
    case 0x2D: return 189;
    case 0x2E: return 187;
    case 0x2F: return 219;
    case 0x30: return 221;
    case 0x31: return 220;
    case 0x33: return 186;
    case 0x34: return 222;
    case 0x35: return 192;
    case 0x36: return 188;
    case 0x37: return 190;
    case 0x38: return 191;
    case 0x39: return 20;
    case 0x48: return 19;
    case 0x49: return 45;
    case 0x4A: return 36;
    case 0x4B: return 33;
    case 0x4C: return 46;
    case 0x4D: return 35;
    case 0x4E: return 34;
    case 0x4F: return 39;
    case 0x50: return 37;
    case 0x51: return 40;
    case 0x52: return 38;
    case 0x54: return 111;
    case 0x55: return 106;
    case 0x56: return 109;
    case 0x57: return 107;
    case 0x62: return 96;
    case 0x63: return 110;
    case 0xE0: case 0xE4: return 17;
    case 0xE1: case 0xE5: return 16;
    case 0xE2: case 0xE6: return 18;
    default: return 0;
  }
}

- (void)handlePresses:(NSSet<UIPress *> *)presses down:(BOOL)down {
  for (UIPress *p in presses) {
    int vk = p.key ? vk_from_hid(p.key.keyCode) : 0;
    // While a text field has focus, Return and Backspace arrive through insertText/deleteBackward
    if (!vk || (self.isFirstResponder && (vk == VK_RETURN || vk == VK_BACK))) continue;
    // Space is the pan modifier outside text fields (see hover:). The game gets Space only as a single tap, once
    // the key is really up and it was not used for panning; auto-repeat pairs are dropped
    if (vk == VK_SPACE && !self.isFirstResponder) {
      if (!down && !space_is_down()) {
        if (!_spaceUsedForPan) [self sendKey:VK_SPACE];
        _spaceUsedForPan = NO;
      }
      continue;
    }
    UIKeyModifierFlags f = p.key.modifierFlags;
    int shift = (f & UIKeyModifierShift ? 1 : 0) | (f & UIKeyModifierControl ? 2 : 0) | (f & UIKeyModifierAlternate ? 4 : 0);
    if (getenv("KAM_LOG_INPUT")) NSLog(@"KaMHost: key %s vk=%d shift=%d", down ? "down" : "up", vk, shift);
    [self post:^{ kam_key(down ? 0 : 1, vk, shift); }];
  }
}

// super passes the press on, which is what types text while the soft-keyboard responder is active
- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
  [self handlePresses:presses down:YES];
  [super pressesBegan:presses withEvent:event];
}
- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
  [self handlePresses:presses down:NO];
  [super pressesEnded:presses withEvent:event];
}
- (void)pressesCancelled:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
  [self handlePresses:presses down:NO];
  [super pressesCancelled:presses withEvent:event];
}

// ---------- Soft keyboard (shown while a text field of the game has focus) ----------
- (BOOL)canBecomeFirstResponder { return YES; }
- (BOOL)hasText { return YES; }
- (UITextAutocorrectionType)autocorrectionType { return UITextAutocorrectionTypeNo; }
- (UITextAutocapitalizationType)autocapitalizationType { return UITextAutocapitalizationTypeNone; }

- (void)sendKey:(int)vk {
  [self post:^{ kam_key(0, vk, 0); kam_key(1, vk, 0); }];
}

- (void)insertText:(NSString *)text {
  for (NSUInteger i = 0; i < text.length; i++) {
    unichar c = [text characterAtIndex:i];
    if (c == '\n') [self sendKey:VK_RETURN];
    else [self post:^{ kam_char(c); }];
  }
}

- (void)deleteBackward { [self sendKey:VK_BACK]; }
@end

// ---------- Engine callbacks (called on the render thread) ----------
static NSString *str(const char *s) { return [NSString stringWithUTF8String:s ?: ""] ?: @""; }

static void cb_show_message(const char *title, const char *text) {
  NSString *t = str(title), *x = str(text);
  NSLog(@"KaMHost: %@: %@", t, x);
  dispatch_async(dispatch_get_main_queue(), ^{
    UIAlertController *a = [UIAlertController alertControllerWithTitle:t message:x preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [gView.window.rootViewController presentViewController:a animated:YES completion:nil];
  });
}

static void cb_clipboard_set(const char *text) {
  NSString *t = str(text);
  dispatch_async(dispatch_get_main_queue(), ^{ UIPasteboard.generalPasteboard.string = t; });
}

static const char *cb_clipboard_get(void) {
  static char *last;
  __block NSString *s;
  dispatch_sync(dispatch_get_main_queue(), ^{ s = UIPasteboard.generalPasteboard.string; });
  free(last);
  last = strdup(s.UTF8String ?: "");
  return last;
}

static void cb_open_url(const char *url) {
  NSURL *u = [NSURL URLWithString:str(url)];
  if (u) dispatch_async(dispatch_get_main_queue(), ^{ [UIApplication.sharedApplication openURL:u options:@{} completionHandler:nil]; });
}

static void cb_quit(void) { exit(0); }

// ---------- Videos: full-screen AVPlayer over the game, tap to skip (counterpart of android/VideoOverlay.java) ----------
// AVPlayer cannot read the game's .avi files: ffmpeg-converted .mp4 files next to them are played instead
@interface KaMVideoView : UIView
@end

// Main thread. Ends playback and tells the engine, which is waiting for it
static void video_finish(void) {
  if (!gVideo) return;
  AVPlayerLayer *layer = (AVPlayerLayer *)gVideo.layer;
  [NSNotificationCenter.defaultCenter removeObserver:gVideo];
  [layer.player.currentItem removeObserver:gVideo forKeyPath:@"status"];
  [layer.player pause];
  [gVideo removeFromSuperview];
  gVideo = nil;
  [gView post:^{ kam_video_finished(); }];
}

@implementation KaMVideoView
+ (Class)layerClass { return [AVPlayerLayer class]; }
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { video_finish(); }
- (void)ended:(NSNotification *)n { video_finish(); }
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
  if (((AVPlayerItem *)object).status == AVPlayerItemStatusFailed) {
    NSLog(@"KaMHost: video failed: %@", ((AVPlayerItem *)object).error);
    dispatch_async(dispatch_get_main_queue(), ^{ video_finish(); });
  }
}
@end

static void cb_play_video(const char *path, int volume, int stretch) {
  NSString *p = str(path), *mp4 = [[p stringByDeletingPathExtension] stringByAppendingPathExtension:@"mp4"];
  if ([NSFileManager.defaultManager fileExistsAtPath:mp4]) p = mp4;
  dispatch_async(dispatch_get_main_queue(), ^{
    video_finish();
    NSLog(@"KaMHost: video %@", p);
    if (![NSFileManager.defaultManager fileExistsAtPath:p]) { [gView post:^{ kam_video_finished(); }]; return; }
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:p]];
    AVPlayer *player = [AVPlayer playerWithPlayerItem:item];
    player.volume = MAX(0, MIN(100, volume)) / 100.0f;
    gVideo = [[KaMVideoView alloc] initWithFrame:gView.bounds];
    gVideo.backgroundColor = UIColor.blackColor;
    ((AVPlayerLayer *)gVideo.layer).player = player;
    ((AVPlayerLayer *)gVideo.layer).videoGravity = stretch ? AVLayerVideoGravityResize : AVLayerVideoGravityResizeAspect;
    [NSNotificationCenter.defaultCenter addObserver:gVideo selector:@selector(ended:) name:AVPlayerItemDidPlayToEndTimeNotification object:item];
    [NSNotificationCenter.defaultCenter addObserver:gVideo selector:@selector(ended:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:item];
    [item addObserver:gVideo forKeyPath:@"status" options:0 context:NULL];
    [gView addSubview:gVideo];
    [player play];
  });
}

static void cb_stop_video(void) {
  dispatch_async(dispatch_get_main_queue(), ^{ video_finish(); });
}

// ---------- Game Center: the engine's achievements (src/game/KM_Achievements.pas) under the same identifiers ----------
static void cb_achievement(const char *identifier) {
  NSString *i = str(identifier);
  dispatch_async(dispatch_get_main_queue(), ^{
    if (!GKLocalPlayer.localPlayer.isAuthenticated) return; // the engine reports again on the next win
    GKAchievement *a = [[GKAchievement alloc] initWithIdentifier:i];
    a.percentComplete = 100;
    a.showsCompletionBanner = YES;
    [GKAchievement reportAchievements:@[a] withCompletionHandler:^(NSError *e) {
      NSLog(@"KaMHost: Game Center achievement %@: %@", i, e ?: @"reported");
    }];
  });
}

// Points. Below this the original UI would be too small to read or tap (iPad mini is 1133 x 744)
static const CGFloat MIN_PLAY_WIDTH = 640, MIN_PLAY_HEIGHT = 450;

// ---------- Display on a Mac: window mode and game resolution, set on the game's Options page ----------
// shortcut: an iPad app on a Mac has no public window API, so this reaches its NSWindow by name; replace with a
// UIWindowScene call if Apple adds one for "Designed for iPad" apps
static id mac_window(void) {
  id app = ((id (*)(id, SEL))objc_msgSend)(NSClassFromString(@"NSApplication"), NSSelectorFromString(@"sharedApplication"));
  return [[app valueForKey:@"windows"] firstObject];
}

static void mac_set_full_screen(BOOL fullScreen) {
  id window = mac_window();
  BOOL isFullScreen = ([[window valueForKey:@"styleMask"] unsignedIntegerValue] & (1 << 14)) != 0; // NSWindowStyleMaskFullScreen
  if (window && isFullScreen != fullScreen)
    ((void (*)(id, SEL, id))objc_msgSend)(window, NSSelectorFromString(@"toggleFullScreen:"), nil);
}

// Windowed: the window takes the chosen resolution, one game pixel per point, keeping its shape (capped to the
// screen). Full screen: the chosen resolution is stretched over the display
static void cb_set_display(int fullScreen, int height) {
  dispatch_async(dispatch_get_main_queue(), ^{
    [NSUserDefaults.standardUserDefaults setBool:fullScreen forKey:@"fullScreen"];
    [NSUserDefaults.standardUserDefaults setInteger:height forKey:@"gameHeight"];
    gGameHeight = height;
    mac_set_full_screen(fullScreen);
    id window = mac_window();
    if (!fullScreen && window) {
      // The system sizes this window from its scene and ignores NSWindow resizing. The request below is the Mac
      // Catalyst geometry API: not declared for iPad apps, but present at run time when one runs on a Mac.
      // Window frames are in Mac points, the view in iPad points (a Mac shows iPad apps scaled down): k converts
      CGSize view = gView.bounds.size, screen = [[[window valueForKey:@"screen"] valueForKey:@"visibleFrame"] CGRectValue].size;
      CGRect frame = [[window valueForKey:@"frame"] CGRectValue];
      CGFloat k = frame.size.width / gView.superview.bounds.size.width, chrome = frame.size.height - gView.superview.bounds.size.height * k; // title bar
      CGFloat h = MIN(height * k, screen.height - chrome), w = MIN(h * view.width / view.height, screen.width);
      frame = CGRectMake(frame.origin.x + (frame.size.width - w) / 2, frame.origin.y + (frame.size.height - h - chrome) / 2, w, h + chrome);
      id prefs = [NSClassFromString(@"UIWindowSceneGeometryPreferencesMac") new];
      [prefs setValue:[NSValue valueWithCGRect:frame] forKey:@"systemFrame"];
      if (prefs)
        [gView.window.windowScene requestGeometryUpdateWithPreferences:prefs errorHandler:^(NSError *e) {
          NSLog(@"KaMHost: window resize refused: %@", e);
        }];
      else NSLog(@"KaMHost: no window geometry API, window keeps its size");
    }
    NSLog(@"KaMHost: display fullScreen=%d height=%d", fullScreen, height);
    [gView relayout];
  });
}

// ---------- App ----------
@interface KaMViewController : UIViewController <UIDocumentPickerDelegate>
@end

static BOOL gTooSmall, gInactive = YES;

// The game (and a playing video) runs only while the scene is active and large enough
static void update_pause(void) {
  BOOL pause = gTooSmall || gInactive;
  [gView setPaused:pause];
  AVPlayer *video = ((AVPlayerLayer *)gVideo.layer).player;
  if (pause) [video pause]; else [video play];
}

@implementation KaMViewController {
  UILabel *_hint;
  NSString *_docs; // the game's data and save folder
}
- (void)loadView {
  self.view = [UIView new];
  self.view.backgroundColor = UIColor.blackColor;
  [self.view addSubview:gView = [KaMView new]];
  _hint = [UILabel new];
  _hint.text = @"Unfold the device or enlarge the window to play";
  _hint.textColor = UIColor.whiteColor;
  _hint.textAlignment = NSTextAlignmentCenter;
  _hint.numberOfLines = 0;
  _hint.hidden = YES;
  [self.view addSubview:_hint];
}

// The game always gets its designed shape: a landscape area no taller than 4:3, with black bars for the rest, so
// the 1024 px wide UI is never cut off. Spaces too small to play in (iPhone Duo folded, a narrow window) show a
// hint instead and pause the game
- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  CGSize s = self.view.bounds.size;
  CGFloat h = MIN(s.height, s.width * 3 / 4);
  gView.frame = CGRectMake(0, (s.height - h) / 2, s.width, h);
  _hint.frame = CGRectInset(self.view.bounds, 20, 20);
  gTooSmall = s.width < MIN_PLAY_WIDTH || h < MIN_PLAY_HEIGHT;
  _hint.hidden = !gTooSmall;
  gView.hidden = gTooSmall;
  update_pause();
}
- (BOOL)prefersStatusBarHidden { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskLandscape; }
- (BOOL)prefersHomeIndicatorAutoHidden { return YES; }
- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures { return UIRectEdgeAll; }

// Hardware keyboard: first responder unless a text field of the game has the soft keyboard up (then the view handles keys)
- (BOOL)canBecomeFirstResponder { return YES; }
- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
  if (!gView.isFirstResponder) [gView handlePresses:presses down:YES];
  [super pressesBegan:presses withEvent:event];
}
- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
  if (!gView.isFirstResponder) [gView handlePresses:presses down:NO];
  [super pressesEnded:presses withEvent:event];
}
- (void)pressesCancelled:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
  if (!gView.isFirstResponder) [gView handlePresses:presses down:NO];
  [super pressesCancelled:presses withEvent:event];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  [self becomeFirstResponder];
  if (!GKLocalPlayer.localPlayer.authenticateHandler)
    GKLocalPlayer.localPlayer.authenticateHandler = ^(UIViewController *login, NSError *e) {
      if (login) [self presentViewController:login animated:YES completion:nil];
      else NSLog(@"KaMHost: Game Center %@", GKLocalPlayer.localPlayer.isAuthenticated ? @"signed in" : (id)e ?: @"not signed in");
      // Test aid: KAM_GC_RESET=1 clears this player's Game Center achievements for the app
      if (getenv("KAM_GC_RESET") && GKLocalPlayer.localPlayer.isAuthenticated)
        [GKAchievement resetAchievementsWithCompletionHandler:^(NSError *r) { NSLog(@"KaMHost: Game Center reset: %@", r ?: @"done"); }];
    };
  static BOOL started;
  if (started) return;
  started = YES;
  // Game data lives in Documents (writable: saves, settings and logs go next to it). See ios/push_data.sh
  _docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
  // Test aid: KAM_DATA_DIR=name keeps the game in Documents/<name>, e.g. to try the import with an empty folder
  if (getenv("KAM_DATA_DIR")) _docs = [_docs stringByAppendingPathComponent:@(getenv("KAM_DATA_DIR"))];
  [NSFileManager.defaultManager createDirectoryAtPath:_docs withIntermediateDirectories:YES attributes:nil error:nil];
  // The Mac development build carries the game data in the app bundle (ios/run_mac.sh); first start copies it out
  [self importFrom:[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"gamedata"]];
  [self startGame];
}

static NSArray<NSString *> *data_folders(void) {
  return @[@"data", @"Campaigns", @"Maps", @"MapsMP", @"Music", @"Sounds", @"Tutorials"];
}

- (BOOL)hasData { return [NSFileManager.defaultManager fileExistsAtPath:[_docs stringByAppendingPathComponent:@"data"]]; }

// Copies the game's data folders from a KaM Remake installation into Documents (names matched without regard to
// case). Returns nil, or what went wrong
- (NSString *)importFrom:(NSString *)source {
  NSFileManager *fm = NSFileManager.defaultManager;
  NSArray<NSString *> *found = [fm contentsOfDirectoryAtPath:source error:nil] ?: @[];
  if ([self hasData] || found.count == 0) return nil;
  BOOL any = NO;
  for (NSString *name in data_folders())
    for (NSString *entry in found) {
      if ([entry caseInsensitiveCompare:name] != NSOrderedSame) continue;
      NSString *to = [_docs stringByAppendingPathComponent:name];
      NSError *e;
      [fm removeItemAtPath:to error:nil]; // left over from an interrupted import
      if (![fm copyItemAtPath:[source stringByAppendingPathComponent:entry] toPath:to error:&e]) return e.localizedDescription;
      any = YES;
    }
  return any && [self hasData] ? nil : @"That folder has no \"data\" folder in it. Choose the folder of a KaM Remake installation.";
}

- (void)startGame {
  if ([self hasData]) {
    [gView startWithDataDir:_docs];
    // Restoring full screen has to wait until the window has finished opening: switching during launch makes
    // macOS abort the app ("Unbalanced state change freezing/thawing")
    if (NSProcessInfo.processInfo.isiOSAppOnMac && [NSUserDefaults.standardUserDefaults boolForKey:@"fullScreen"])
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ mac_set_full_screen(YES); });
    return;
  }
  UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Game data needed"
      message:@"This app is the game engine only. Choose the folder of a KaM Remake installation: the one that contains "
              @"data, Campaigns, Maps, MapsMP, Music, Sounds and Tutorials. It is copied into the app once."
      preferredStyle:UIAlertControllerStyleAlert];
  [a addAction:[UIAlertAction actionWithTitle:@"Choose game folder…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeFolder]];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
  }]];
  [self presentViewController:a animated:YES completion:nil];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller { [self startGame]; }

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
  NSURL *url = urls.firstObject;
  UIAlertController *busy = [UIAlertController alertControllerWithTitle:@"Copying game data…" message:@"About 1 GB, this takes a moment."
                                                         preferredStyle:UIAlertControllerStyleAlert];
  [self presentViewController:busy animated:YES completion:nil];
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    BOOL scoped = [url startAccessingSecurityScopedResource]; // the picked folder lies outside the app's sandbox
    NSString *problem = [self importFrom:url.path];
    if (scoped) [url stopAccessingSecurityScopedResource];
    NSLog(@"KaMHost: import from %@: %@", url.lastPathComponent, problem ?: @"done");
    dispatch_async(dispatch_get_main_queue(), ^{
      [busy dismissViewControllerAnimated:YES completion:^{
        if (!problem) { [self startGame]; return; }
        UIAlertController *failed = [UIAlertController alertControllerWithTitle:@"Could not use that folder" message:problem
                                                                 preferredStyle:UIAlertControllerStyleAlert];
        [failed addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) { [self startGame]; }]];
        [self presentViewController:failed animated:YES completion:nil];
      }];
    });
  });
}
@end

// iOS 27 terminates apps that have not adopted the scene life cycle
@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation SceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
  self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
  // Asks the system not to offer smaller windows (UIRequiresFullScreen no longer does that from iOS 27 on)
  ((UIWindowScene *)scene).sizeRestrictions.minimumSize = CGSizeMake(MIN_PLAY_WIDTH, MIN_PLAY_HEIGHT);
  self.window.rootViewController = [KaMViewController new];
  [self.window makeKeyAndVisible];
}
- (void)sceneWillResignActive:(UIScene *)scene { gInactive = YES; update_pause(); }
- (void)sceneDidBecomeActive:(UIScene *)scene { gInactive = NO; update_pause(); }
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
  static kam_host_callbacks cb = {cb_show_message, cb_clipboard_set, cb_clipboard_get, cb_open_url, cb_quit, cb_play_video, cb_stop_video};
  kam_set_callbacks(&cb);
  kam_set_achievement_callback(cb_achievement);
  if (NSProcessInfo.processInfo.isiOSAppOnMac) {
    kam_set_display_callback(cb_set_display);
    gGameHeight = [NSUserDefaults.standardUserDefaults integerForKey:@"gameHeight"] ?: BASE_HEIGHT;
  }
  application.idleTimerDisabled = YES;
  return YES;
}
@end

int main(int argc, char *argv[]) {
  @autoreleasepool {
    return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
  }
}
