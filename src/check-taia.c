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

  unsigned char slow[16];
  unsigned char norm[16];
  unsigned char fast[16];

  taia_now(norm);

  taia_pack(norm,norm);

  tai_dec(slow,norm,"\0\0\0\0\0\0\0\x80");
  tai_inc(fast,norm,"\0\0\0\0\0\0\0\x80");

  write(1,slow,16);
  write(1,norm,16);
  write(1,fast,16);

  int i;

  for (i=0;i<16;++i)
  {
    if (slow[i] < norm[i]) break;
    if (slow[i] > norm[i]) exit(1);
  } if (!crypto_verify_16(slow,norm)) exit(2);

  for (i=0;i<16;++i)
  {
    if (norm[i] < fast[i]) exit(0);
    if (norm[i] > fast[i]) exit(3);
  } if (!crypto_verify_16(norm,fast)) exit(4);

}
