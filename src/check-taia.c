#include <nacl/crypto_verify_16.h>
#include <sys/types.h>
#include <sys/time.h>
#include <stdlib.h>
#include <string.h>
#include <taia.h>

void taia_aprx(a,b)
struct taia *a;
struct taia *b;
{
  struct timeval now;
  gettimeofday(&now,(struct timezone *) 0);

  a->sec.x = 4611686018427387914ULL + (uint64) now.tv_sec;
  a->nano = 1000 * now.tv_usec + 500;
  a->atto = 0;

  b->sec.x = a->sec.x;
  b->nano = a->nano;
  b->atto = a->atto;

  b->sec.x += 128ULL;
  a->sec.x -= 128ULL;
}

main()
{

  unsigned char taia0[16];
  unsigned char taia1[16];
  unsigned char taia2[16];

  taia_now(taia1);
  taia_aprx(taia0,taia2);

  taia_pack(taia0,taia0);
  taia_pack(taia1,taia1);
  taia_pack(taia2,taia2);

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
