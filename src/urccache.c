#define USAGE "Usage: urccache /path/to/root/\n"
#include <nacl/crypto_hash_sha256.h>
#include <nacl/crypto_verify_32.h>
#include <nacl/randombytes.h>
#include <sys/types.h>
#include <sys/time.h>
#include <strings.h>
#include <stdlib.h>
#include <string.h>
#include <taia.h>
#include <pwd.h>

#include "tai_dec.h"
#include "tai_inc.h"

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

  unsigned long timecached = time((long *) 0);
  unsigned char cache[256][16384]={0};
  unsigned char buffer[16+8+65536+32];
  unsigned char hash[32];
  unsigned char ts[16];
  float cached[256];
  bzero(cached,sizeof(cached));
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

    taia_now(ts);
    taia_pack(ts,ts);

    tai_dec(ts,ts,"\0\0\0\0\0\0\0\x80");

    for (i=0;i<16;++i)
    {
      if (ts[i] < buffer[i]) break;
      if (ts[i] > buffer[i])
      {
        if (write(1,"\3",1)<1) exit(3);
        goto readbuffer;
      }
    }

    tai_inc(ts,ts,"\0\0\0\0\0\0\1\0");

    for (i=0;i<16;++i)
    {
      if (ts[i] > buffer[i]) break;
      if (ts[i] < buffer[i])
      {
        if (write(1,"\2",1)<1) exit(4);
        goto readbuffer;
      }
    }

    memcpy(buffer+l,salt,32);
    crypto_hash_sha256(hash,buffer,l+32);

    n = 0;
    for (i=0;i<16384;i+=32) if (!crypto_verify_32(hash,cache[hash[0]]+i)) n|=1; else n|=0;
    if (n)
    {
      if (write(1,"\1",1)<1) exit(5);
      continue;
    }

    memcpy(cache[hash[0]],cache[hash[0]]+32,16384-32);
    memcpy(cache[hash[0]]+16384-32,hash,32);

    if (write(1,"\0",1)<1) exit(6);

    if (cached[hash[0]] == 512.0) cached[hash[0]] = 0.0;
    if (time((long *) 0) - timecached >= 256)
    {
      timecached = time((long *) 0);
      bzero(cached,sizeof(cached));
    } ++cached[hash[0]];

    usleep((int) (cached[hash[0]] / 512.0 * 1000000.0));

  }

}
