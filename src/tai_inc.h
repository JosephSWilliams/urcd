#include <string.h>

tai_inc(unsigned char *t, unsigned char *u, unsigned char *v)
{

  static int i;

  memmove(t,u,8);

  for (i=7;i>-1;--i)
  {

    if (!v[i]) continue;
    if (t[i] + v[i] < 256){ t[i] += v[i]; continue; } t[i] += v[i];
    if (!i) continue;
    if ((++t[i-1]) | (i - 2 < 0)) continue;
    if ((++t[i-2]) | (i - 3 < 0)) continue;
    if ((++t[i-3]) | (i - 4 < 0)) continue;
    if ((++t[i-4]) | (i - 5 < 0)) continue;
    if ((++t[i-5]) | (i - 6 < 0)) continue;
    if ((++t[i-6]) | (i - 7 < 0)) continue;
    ++t[i-7];

  }

}
