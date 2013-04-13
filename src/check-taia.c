#include <sys/types.h>
#include <sys/time.h>
#include <stdlib.h>
#include <string.h>
#include <taia.h>

void taia_slow(t)
struct taia *t;
{
  struct timeval now;
  gettimeofday(&now,(struct timezone *) 0);
  t->sec.x = 4611686018427387914ULL - 128ULL + (uint64) now.tv_sec;
  t->nano = 1000 * now.tv_usec + 500;
  t->atto = 0;
}

main()
{

  unsigned char taia0[16];
  unsigned char taia1[16];

  taia_now(taia0);
  taia_slow(taia1);

  taia_pack(taia0,taia0);
  taia_pack(taia1,taia1);

  int i;

  for (i=0;i<16;++i)
  {
    if (taia0[i] > taia1[i]) exit(0);
    if (taia0[i] < taia1[i]) exit(1);
  } exit(1);

}
