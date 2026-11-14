// Desktop smoke test for the Apple arm64 engine build (KAM_TARGET=darwin): boots libkamcore.dylib in a GLUT window.
// Not the iPad host; it only proves the engine runs on Darwin before a device is involved.
// Usage: mactest <data dir> [selftest mode] [frames before exit]
#define GL_SILENCE_DEPRECATION
#include <GLUT/glut.h>
#include <stdio.h>
#include <stdlib.h>

typedef struct {
  void (*ShowMessage)(const char *, const char *);
  void (*ClipboardSet)(const char *);
  const char *(*ClipboardGet)(void);
  void (*OpenURL)(const char *);
  void (*Quit)(void);
  void (*PlayVideo)(const char *, int, int);
  void (*StopVideo)(void);
} kam_host_callbacks;

extern void kam_set_callbacks(kam_host_callbacks *cb);
extern int kam_init(const char *dataDir, int width, int height);
extern void kam_frame(void);
extern void kam_resize(int width, int height);
extern void kam_mouse(int action, int button, int x, int y);
extern void kam_video_finished(void);
extern void kam_selftest(const char *mode);

static const char *g_selftest;
static int g_frames, g_max_frames;

static void cb_msg(const char *t, const char *x) { fprintf(stderr, "MESSAGE %s: %s\n", t, x); }
static void cb_clip_set(const char *t) { (void)t; }
static const char *cb_clip_get(void) { return ""; }
static void cb_url(const char *u) { fprintf(stderr, "URL %s\n", u); }
static void cb_quit(void) { exit(0); }
static void cb_video(const char *p, int v, int s) { (void)v; (void)s; fprintf(stderr, "VIDEO %s (skipped)\n", p); kam_video_finished(); }
static void cb_video_stop(void) {}

static void display(void) {
  kam_frame();
  glutSwapBuffers();
  g_frames++;
  if (g_frames == 120 && g_selftest) kam_selftest(g_selftest);
  if (g_max_frames && g_frames >= g_max_frames) exit(0);
}
static void idle(void) { glutPostRedisplay(); }
static void reshape(int w, int h) { kam_resize(w, h); }
static void mouse(int button, int state, int x, int y) {
  kam_mouse(state == GLUT_DOWN ? 0 : 2, button == GLUT_RIGHT_BUTTON ? 1 : 0, x, y);
}
static void motion(int x, int y) { kam_mouse(1, 0, x, y); }

int main(int argc, char **argv) {
  glutInit(&argc, argv);
  if (argc < 2) { fprintf(stderr, "usage: mactest <data dir> [selftest mode] [frames]\n"); return 2; }
  g_selftest = argc > 2 && argv[2][0] ? argv[2] : NULL;
  g_max_frames = argc > 3 ? atoi(argv[3]) : 0;
  glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGBA | GLUT_DEPTH | GLUT_STENCIL);
  glutInitWindowSize(1280, 800);
  glutCreateWindow("KaM Remake engine smoke test");
  static kam_host_callbacks cb = {cb_msg, cb_clip_set, cb_clip_get, cb_url, cb_quit, cb_video, cb_video_stop};
  kam_set_callbacks(&cb);
  if (!kam_init(argv[1], 1280, 800)) { fprintf(stderr, "kam_init failed\n"); return 1; }
  glutDisplayFunc(display);
  glutIdleFunc(idle);
  glutReshapeFunc(reshape);
  glutMouseFunc(mouse);
  glutMotionFunc(motion);
  glutPassiveMotionFunc(motion);
  glutMainLoop();
  return 0;
}
