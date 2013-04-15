#include <nacl/crypto_verify_16.h>
#include <sys/types.h>
#include <sys/time.h>
#include <stdlib.h>
#include <string.h>
#include <taia.h>

#include "tai_dec.h"
#include "tai_inc.h"

main()
{

  unsigned char taia0[16];
  unsigned char taia1[16];
  unsigned char taia2[16];

  taia_now(taia1);

  taia_pack(taia1,taia1);

  tai_dec(taia0,taia1,"\0\0\0\0\0\0\0\x80");
  tai_inc(taia2,taia1,"\0\0\0\0\0\0\0\x80");

  int i;

  for (i=0;i<16;++i)
  {
    if (taia0[i] < taia1[i]) break;
    if (taia0[i] > taia1[i]) exit(1);
  } if (!crypto_verify_16(taia0,taia1)) exit(2);

  for (i=0;i<16;++i)
  {
    if (taia1[i] < taia2[i]) exit(0);
    if (taia1[i] > taia2[i]) exit(3);
  } if (!crypto_verify_16(taia1,taia2)) exit(4);

}
