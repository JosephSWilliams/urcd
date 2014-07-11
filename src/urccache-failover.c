#define USAGE "Usage: urccache /path/to/root/\n"
#include <nacl/crypto_hash_sha256.h>
#include <nacl/crypto_verify_32.h>
#include <sys/types.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <pwd.h>

main(int argc, char **argv)
{

  if (argc<2)
  {
    write(2,USAGE,strlen(USAGE));
    exit(64);
  }

  unsigned char cache[131072*32]={0};

  if (chdir(argv[1])) exit(64);
  struct passwd *urcd = getpwnam("urcd");
  if ((!urcd) || ((chroot(argv[1])) || (setgroups(0,'\x00')) || (setgid(urcd->pw_gid)) || (setuid(urcd->pw_uid)))) exit(64);

  unsigned char buffer[16+8+65536+32];
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

    crypto_hash_sha256(hash,buffer,l);

    for (i=131072*32-32;i>-32;i-=32) if (!crypto_verify_32(hash,cache+i))
    {
      if (write(1,"\1",1)<1) exit(3);
      goto readbuffer;
    }

    memcpy(cache,cache+32,131072*32-32);
    memcpy(cache+131072*32-32,hash,32);

    if (write(1,"\0",1)<1) exit(4);

  }

}
