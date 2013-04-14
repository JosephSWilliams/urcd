#define USAGE "Usage: urccache /path/to/root/\n"
#include <nacl/crypto_hash_sha256.h>
#include <nacl/crypto_verify_32.h>
#include <nacl/randombytes.h>
#include <sys/types.h>
#include <sys/time.h>
#include <stdlib.h>
#include <string.h>
#include <taia.h>
#include <pwd.h>

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

main(int argc, char **argv)
{

  if (argc<2)
  {
    write(2,USAGE,strlen(USAGE));
    exit(64);
  }

  unsigned char salt[32];
  randombytes(salt,32);

  if (chdir(argv[1])) exit(64);
  struct passwd *urcd = getpwnam("urcd");
  if ((!urcd) || ((chroot(argv[1])) || (setgid(urcd->pw_gid)) || (setuid(urcd->pw_uid)))) exit(64);

  unsigned char cache[256][32768]={0};
  unsigned char buffer[16+8+65536+32];
  unsigned char taia0[16];
  unsigned char taia1[16];
  unsigned char hash[32];
  int i, n, l;

  while (1)
  {

    readbuffer: if (read(0,buffer,2)<2) exit(1);

    n = 0;
    l = 16 + 8 + buffer[0] * 256 + buffer[1];

    while (n<l)
    {
      i = read(0,buffer+n,l-n);
      if (i<1) exit(2);
      n += i;
    }

    taia_aprx(taia0,taia1);
    taia_pack(taia0,taia0);
    taia_pack(taia1,taia1);

    for (i=0;i<16;++i)
    {
      if (taia0[i] < buffer[i]) break;
      if (taia0[i] > buffer[i])
      {
        if (write(1,"\3",1)<1) exit(3);
        goto readbuffer;
      }
    }

    for (i=0;i<16;++i)
    {
      if (taia1[i] > buffer[i]) break;
      if (taia1[i] < buffer[i])
      {
        if (write(1,"\2",1)<1) exit(4);
        goto readbuffer;
      }
    }

    memcpy(buffer+l,salt,32);
    crypto_hash_sha256(hash,buffer,l+32);

    n = 0;
    for (i=0;i<32768;i+=32) if (!crypto_verify_32(hash,cache[hash[0]]+i)) n|=1; else n|=0;
    if (n)
    {
      if (write(1,"\1",1)<1) exit(5);
      continue;
    }

    memcpy(cache[hash[0]],cache[hash[0]]+32,32768-32);
    memcpy(cache[hash[0]]+32768-32,hash,32);

    if (write(1,"\0",1)<1) exit(6);
    usleep(250000);

  }

}
