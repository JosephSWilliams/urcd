#include <string.h>

tai_inc(unsigned char *t, unsigned char *u, unsigned char *v)
{

  static int i;

  memmove(t,u,8);

  for (i=7;i>-1;--i)
  {

    if (!v[i]) continue;
    if ((t[i] + v[i] < 256) | (!i)){ t[i] += v[i]; continue; } t[i] += v[i];
    if ((++t[i-1]) | (!i-1)) continue;
    if ((++t[i-2]) | (!i-2)) continue;
    if ((++t[i-3]) | (!i-3)) continue;
    if ((++t[i-4]) | (!i-4)) continue;
    if ((++t[i-5]) | (!i-5)) continue;
    if ((++t[i-6]) | (!i-6)) continue;
    ++t[i-7];

  }

}
