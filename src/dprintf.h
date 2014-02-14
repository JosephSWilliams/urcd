/* NetBSD workaround: (thanks epoch) */
#ifdef HAVE_NBTOOL_CONFIG_H
#include "nbtool_config.h"
#endif

#if !HAVE_DPRINTF
#include <stdlib.h>
#ifndef HAVE_NBTOOL_CONFIG_H
#include <stdio.h>
#include <stdarg.h>
#include <unistd.h>
#endif

int dprintf(int fd, const char *format, ...) {
 FILE *f;
 int d;
 va_list ap;
 if ((d=dup(fd))==-1) return -1;
 if ((f=fdopen(d,"r+"))==NULL) {
  close(d);
  return -1;
 }
 va_start(ap,format);
 d=vfprintf(f,format,ap);
 va_end(ap);
 fclose(f);
 return d;
}

#endif
