/* fault NR FD ERRNO NTH prog args...
 * Run prog with one syscall forced to fail.
 * FD >= 0 fails that syscall only when arg0 equals FD.
 * FD < 0 fails that syscall on any descriptor.
 * ERRNO is in 1..4095. NTH is the 1-based matching call to fail.
 * Every NTH is counted with ptrace, so one call fails on that path.
 * and the call is skipped before the kernel runs it.
 * Exit codes:
 *   93  bad NR, FD, ERRNO, or NTH
 *   94  could not fill fds 0-2 from /dev/null, or could not close the rest
 *   95  exec failed
 *   96  seccomp or ptrace failed
 *   97  PR_SET_NO_NEW_PRIVS failed
 *   98  usage
 * Fd layout guaranteed before exec: 0, 1 and 2 are open, and every fd
 * from 3 up is closed. The program's first open is then 3 and its second
 * is 4. A check, not a rung. The gate builds this into the sandbox.
 */
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <stddef.h>
#include <sys/prctl.h>
#include <sys/ptrace.h>
#include <sys/resource.h>
#include <sys/syscall.h>
#include <sys/user.h>
#include <sys/wait.h>
#include <linux/seccomp.h>
#include <linux/filter.h>

#ifndef SYS_close_range
#define SYS_close_range 436
#endif

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

static int prepare_fds(void) {
  int slot;
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
  if (syscall(SYS_close_range, 3, ~0U, 0) != 0) {
    perror("close_range");
    return 94;
  }
  return 0;
}

static int trace_nth(int nr, int watch_fd, int err, int nth, char **argv) {
  pid_t pid;
  int status;
  int entering;
  int seen;
  int armed;
  int prep;
  pid = fork();
  if (pid < 0) {
    perror("fork");
    return 94;
  }
  if (pid == 0) {
    prep = prepare_fds();
    if (prep != 0) {
      _exit(prep);
    }
    if (ptrace(PTRACE_TRACEME, 0, 0, 0) < 0) {
      _exit(96);
    }
    raise(SIGSTOP);
    execv(argv[0], argv);
    _exit(95);
  }
  if (waitpid(pid, &status, 0) < 0) {
    return 96;
  }
  if (ptrace(PTRACE_SETOPTIONS, pid, 0,
             PTRACE_O_TRACESYSGOOD | PTRACE_O_TRACEEXEC) < 0) {
    return 96;
  }
  entering = 1;
  seen = 0;
  armed = 0;
  int inject = 0;
  for (;;) {
    struct user_regs_struct regs;
    int sig;
    if (ptrace(PTRACE_SYSCALL, pid, 0, inject) < 0) {
      return 96;
    }
    inject = 0;
    if (waitpid(pid, &status, 0) < 0) {
      return 96;
    }
    if (WIFEXITED(status)) {
      return WEXITSTATUS(status);
    }
    if (WIFSIGNALED(status)) {
      return 128 + WTERMSIG(status);
    }
    if (!WIFSTOPPED(status)) {
      continue;
    }
    sig = WSTOPSIG(status);
    /* Exec stops as SIGTRAP. Delivering it kills the child (status 133). */
    if ((status >> 16) != 0 || sig == SIGTRAP) {
      inject = 0;
      continue;
    }
    if (sig != (SIGTRAP | 0x80)) {
      inject = sig;
      continue;
    }
    if (ptrace(PTRACE_GETREGS, pid, 0, &regs) < 0) {
      return 96;
    }
    if (entering) {
      int match = regs.orig_rax == (unsigned long)nr;
      if (watch_fd >= 0 && (long)regs.rdi != watch_fd) {
        match = 0;
      }
      if (match) {
        seen++;
        if (seen == nth) {
          regs.orig_rax = (unsigned long)-1;
          if (ptrace(PTRACE_SETREGS, pid, 0, &regs) < 0) {
            return 96;
          }
          armed = 1;
        }
      }
    } else if (armed) {
      regs.rax = (unsigned long)(-(long)err);
      if (ptrace(PTRACE_SETREGS, pid, 0, &regs) < 0) {
        return 96;
      }
      armed = 0;
    }
    entering = !entering;
  }
}

int main(int argc, char **argv) {
  long nr_l;
  long fd_l;
  long err_l;
  long nth_l;
  int nr;
  int watch_fd;
  int err;
  int nth;

  if (argc < 6) {
    fprintf(stderr, "usage: fault NR FD ERRNO NTH prog args...\n");
    return 98;
  }
  nr_l = need_long(argv[1], "NR");
  fd_l = need_long(argv[2], "FD");
  err_l = need_long(argv[3], "ERRNO");
  nth_l = need_long(argv[4], "NTH");
  if (nr_l < 0 || nr_l > 511) {
    fprintf(stderr, "fault: nr out of range\n");
    return 93;
  }
  if (fd_l < -1 || fd_l > 65535) {
    fprintf(stderr, "fault: fd out of range\n");
    return 93;
  }
  if (err_l < 1 || err_l > 4095) {
    fprintf(stderr, "fault: errno must be 1..4095\n");
    return 93;
  }
  if (nth_l < 1 || nth_l > 1000000) {
    fprintf(stderr, "fault: nth out of range\n");
    return 93;
  }
  nr = (int)nr_l;
  watch_fd = (int)fd_l;
  err = (int)err_l;
  nth = (int)nth_l;
  return trace_nth(nr, watch_fd, err, nth, argv + 5);
}
