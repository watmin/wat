/* fault NR FD ERRNO prog args...
 * Run prog with one syscall forced to fail.
 * FD >= 0 fails that syscall only when arg0 equals FD.
 * FD < 0 fails that syscall on any descriptor.
 * ERRNO must be non-zero. The control is prog run without this injector.
 * A check, not a rung. verify builds it into the sandbox.
 */
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <stddef.h>
#include <sys/prctl.h>
#include <linux/seccomp.h>
#include <linux/filter.h>
#include <sys/resource.h>

static long need_long(const char *text, const char *what) {
  char *end = NULL;
  long value;
  errno = 0;
  value = strtol(text, &end, 10);
  if (end == text || *end != '\0' || errno != 0) {
    fprintf(stderr, "fault: bad %s\n", what);
    exit(93);
  }
  return value;
}

int main(int argc, char **argv) {
  long nr_l;
  long fd_l;
  long err_l;
  int nr;
  int watch_fd;
  int err;
  int slot;
  int maxfd;
  struct rlimit lim;
  struct sock_filter anyfd[] = {
    BPF_STMT(BPF_LD | BPF_W | BPF_ABS, offsetof(struct seccomp_data, nr)),
    BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, 0, 0, 1),
    BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ERRNO),
    BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ALLOW),
  };
  struct sock_filter onefd[] = {
    BPF_STMT(BPF_LD | BPF_W | BPF_ABS, offsetof(struct seccomp_data, nr)),
    BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, 0, 0, 3),
    BPF_STMT(BPF_LD | BPF_W | BPF_ABS, offsetof(struct seccomp_data, args[0])),
    BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, 0, 0, 1),
    BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ERRNO),
    BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ALLOW),
  };
  struct sock_fprog prog;

  if (argc < 5) {
    fprintf(stderr, "usage: fault NR FD ERRNO prog args...\n");
    return 98;
  }
  nr_l = need_long(argv[1], "NR");
  fd_l = need_long(argv[2], "FD");
  err_l = need_long(argv[3], "ERRNO");
  if (err_l == 0) {
    fprintf(stderr, "fault: errno must be non-zero\n");
    return 93;
  }
  nr = (int)nr_l;
  watch_fd = (int)fd_l;
  err = (int)err_l;
  anyfd[1].k = (unsigned)nr;
  onefd[1].k = (unsigned)nr;
  onefd[3].k = (unsigned)watch_fd;
  anyfd[2].k = SECCOMP_RET_ERRNO | (err & SECCOMP_RET_DATA);
  onefd[4].k = SECCOMP_RET_ERRNO | (err & SECCOMP_RET_DATA);
  if (watch_fd < 0) {
    prog.len = 4;
    prog.filter = anyfd;
  } else {
    prog.len = 6;
    prog.filter = onefd;
  }
  for (slot = 0; slot < 3; slot++) {
    int got;
    if (fcntl(slot, F_GETFD) != -1) {
      continue;
    }
    got = open("/dev/null", O_RDWR);
    if (got < 0) {
      perror("null");
      return 94;
    }
    if (got != slot) {
      if (dup2(got, slot) < 0) {
        perror("dup");
        return 94;
      }
      close(got);
    }
  }
  maxfd = 256;
  if (getrlimit(RLIMIT_NOFILE, &lim) == 0 && lim.rlim_cur < 65536) {
    maxfd = (int)lim.rlim_cur;
  }
  for (slot = 3; slot < maxfd; slot++) {
    close(slot);
  }
  if (prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0)) {
    perror("nnp");
    return 97;
  }
  if (prctl(PR_SET_SECCOMP, SECCOMP_MODE_FILTER, &prog)) {
    perror("seccomp");
    return 96;
  }
  execv(argv[4], argv + 4);
  perror("execv");
  return 95;
}
