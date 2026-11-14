// Case-insensitive file lookup for the engine on iOS, whose file system is case-sensitive.
// KaM Remake is a Windows game: code and data disagree on letter case (data/Sprites vs data/sprites, ...).
// Linked statically into libkamcore.dylib, so these definitions replace libc's for the engine only.
// A path is corrected only after the exact one was not found, so matching names cost nothing extra.
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>
#include <sys/stat.h>
#include <unistd.h>

// Rebuilds an absolute path component by component, replacing components that only differ by case.
// Returns 1 when the result differs from the input.
static int fix_case(const char *path, char *out) {
  if (path[0] != '/' || strlen(path) >= PATH_MAX) return 0;
  struct stat st;
  size_t len = 0;
  int changed = 0, missing = 0;
  out[0] = 0;
  for (const char *p = path; *p;) {
    while (*p == '/') p++;
    if (!*p) break;
    const char *end = strchr(p, '/');
    size_t n = end ? (size_t)(end - p) : strlen(p);
    size_t base = len;
    out[len++] = '/';
    memcpy(out + len, p, n);
    len += n;
    out[len] = 0;
    if (!missing && fstatat(AT_FDCWD, out, &st, 0) != 0) {
      out[base ? base : 1] = 0; // parent directory
      int fd = openat(AT_FDCWD, out, O_RDONLY | O_DIRECTORY);
      DIR *d = fd >= 0 ? fdopendir(fd) : NULL;
      struct dirent *e;
      int found = 0;
      while (d && (e = readdir(d)) != NULL)
        if (strlen(e->d_name) == n && strncasecmp(e->d_name, p, n) == 0) {
          out[base] = '/';
          memcpy(out + base + 1, e->d_name, n);
          found = changed = 1;
          break;
        }
      if (d) closedir(d); else if (fd >= 0) close(fd);
      if (!found) {
        out[base] = '/';
        memcpy(out + base + 1, p, n);
        missing = 1; // the rest does not exist under any spelling (e.g. a file about to be created)
      }
      out[len] = 0;
    }
    p += n;
  }
  return changed;
}

#define RETRY(call_exact, call_fixed, fail) \
  char fixed[PATH_MAX]; \
  __typeof__(call_exact) r = call_exact; \
  if (r == (fail) && errno == ENOENT && fix_case(path, fixed)) r = call_fixed; \
  return r;

int open(const char *path, int flags, ...) {
  va_list ap;
  va_start(ap, flags);
  int mode = (flags & O_CREAT) ? va_arg(ap, int) : 0;
  va_end(ap);
  RETRY(openat(AT_FDCWD, path, flags, mode), openat(AT_FDCWD, fixed, flags, mode), -1)
}

int stat(const char *path, struct stat *st) { RETRY(fstatat(AT_FDCWD, path, st, 0), fstatat(AT_FDCWD, fixed, st, 0), -1) }
int lstat(const char *path, struct stat *st) {
  RETRY(fstatat(AT_FDCWD, path, st, AT_SYMLINK_NOFOLLOW), fstatat(AT_FDCWD, fixed, st, AT_SYMLINK_NOFOLLOW), -1)
}
int access(const char *path, int mode) { RETRY(faccessat(AT_FDCWD, path, mode, 0), faccessat(AT_FDCWD, fixed, mode, 0), -1) }

DIR *opendir(const char *path) {
  int fd = open(path, O_RDONLY | O_DIRECTORY);
  if (fd < 0) return NULL;
  DIR *d = fdopendir(fd);
  if (!d) close(fd);
  return d;
}

#ifdef CASEFS_TEST // cc -DCASEFS_TEST ios/casefs.c -o casefs && ./casefs <dir on a case-sensitive volume>
#include <assert.h>
#include <stdlib.h>
int main(int argc, char **argv) {
  char dir[PATH_MAX], p[PATH_MAX], f[PATH_MAX];
  snprintf(dir, sizeof dir, "%s/casefsXXXXXX", argc > 1 ? argv[1] : "/tmp");
  assert(mkdtemp(dir));
  snprintf(p, sizeof p, "%s/sprites", dir); mkdir(p, 0755);
  snprintf(p, sizeof p, "%s/sprites/Tileset.rxx", dir); close(openat(AT_FDCWD, p, O_CREAT | O_WRONLY, 0644));
  snprintf(p, sizeof p, "%s/Sprites/TILESET.RXX", dir);
  assert(fix_case(p, f) && strstr(f, "/sprites/Tileset.rxx"));
  snprintf(p, sizeof p, "%s/SPRITES/new.txt", dir);
  assert(fix_case(p, f) && strstr(f, "/sprites/new.txt")); // parent fixed, new file name kept
  snprintf(p, sizeof p, "%s/sprites/Tileset.rxx", dir);
  assert(!fix_case(p, f));
  puts("casefs ok");
  return 0;
}
#endif
