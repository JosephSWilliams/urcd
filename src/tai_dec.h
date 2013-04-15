#include <string.h>

tai_dec(unsigned char *t, unsigned char *u, unsigned char *v)
{

  static int i;

  memmove(t,u,8);

  for (i=7;i>-1;--i)
  {

    if ((t[i] >= v[i]) | (!i)){ t[i] -= v[i]; continue; } t[i] -= v[i];
    if ((t[i-1]) | (!i-1)){ --t[i-1]; continue; } --t[i-1];
    if ((t[i-2]) | (!i-2)){ --t[i-2]; continue; } --t[i-2];
    if ((t[i-3]) | (!i-3)){ --t[i-3]; continue; } --t[i-3];
    if ((t[i-4]) | (!i-4)){ --t[i-4]; continue; } --t[i-4];
    if ((t[i-5]) | (!i-5)){ --t[i-5]; continue; } --t[i-5];
    if ((t[i-6]) | (!i-6)){ --t[i-6]; continue; } --t[i-6];
    --t[i-7];

  }

}
