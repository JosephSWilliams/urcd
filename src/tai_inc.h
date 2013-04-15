#include <string.h>

tai_inc(unsigned char *t, unsigned char *u, unsigned char *v)
{

  static int i;

  memmove(t,u,8);

  for (i=7;i>-1;--i)
  {

    if (!v[i]) continue;
    if (t[i] + v[i] < 256){ t[i] += v[i]; continue; } t[i] += v[i];
    if (!i) break;
    if (t[i-1] < 255){ ++t[i-1]; continue; } ++t[i-1];
    if (!i-1) continue;
    if (t[i-2] < 255){ ++t[i-2]; continue; } ++t[i-2];
    if (!i-2) continue;
    if (t[i-3] < 255){ ++t[i-3]; continue; } ++t[i-3];
    if (!i-3) continue;
    if (t[i-4] < 255){ ++t[i-4]; continue; } ++t[i-4];
    if (!i-4) continue;
    if (t[i-5] < 255){ ++t[i-5]; continue; } ++t[i-5];
    if (!i-5) continue;
    if (t[i-6] < 255){ ++t[i-6]; continue; } ++t[i-6];
    if (!i-6) continue;
    if (t[i-7] < 255){ ++t[i-7]; continue; } ++t[i-7];

  }

}
