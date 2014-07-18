#include <nacl/crypto_scalarmult_curve25519.h>
#include <nacl/crypto_hash_sha256.h>
#include <nacl/crypto_verify_32.h>
#include <nacl/crypto_sign.h>
#include <nacl/crypto_box.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <strings.h>
#include <unistd.h>
#include <sys/un.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <taia.h>
#include <pwd.h>

#include "base16.h"

#define USAGE "./cryptoserv /path/to/sockets/ /path/to/root/\n"

#ifndef UNIX_PATH_MAX
 #ifdef __NetBSD__
  #define UNIX_PATH_MAX 104
 #else
  #define UNIX_PATH_MAX 108
 #endif
#endif

int itoa(char *s, int n, int slen)
{
 if (snprintf(s,slen,"%d",n)<0) return -1;
 return 0;
}

void randombytes(char *bytes) {
 crypto_hash_sha256(bytes,bytes,32);
}

void upper(
 unsigned char *buffer0,
 unsigned char *buffer1,
 int buffer1_len
) {
 int i;
 for(i=0;i<buffer1_len;++i) {
  if ((buffer1[i]>96)&&(buffer1[i]<123)) {
   buffer0[i] = buffer1[i] - 32;
  }
  else buffer0[i] = buffer1[i];
 }
}

main(int argc, char *argv[])
{

 if (argc<3) {
  write(2,USAGE,strlen(USAGE));
  exit(1);
 }

 struct passwd *urcd = getpwnam("urcd");
 struct sockaddr_un s;

 unsigned char buffer2[1024*2] = {0};
 unsigned char buffer1[1024*2] = {0};
 unsigned char buffer0[1024*2] = {0};
 unsigned char hk[32+32+64+64];
 unsigned char sk[32+64];

 int i = strlen(argv[1]);
 int nicklen = 0;
 int login = 0;
 int sfd = -1;
 int NICKLEN;

 bzero(&s,sizeof(s));
 s.sun_family = AF_UNIX;
 memcpy(s.sun_path,argv[1],i); /* contains potential overflow */

 if (((sfd=socket(AF_UNIX,SOCK_DGRAM,0))<0)
 || (itoa(s.sun_path+i,getppid(),UNIX_PATH_MAX-i)<0)
 || (connect(sfd,(struct sockaddr *)&s,sizeof(s))<0)
 || (setsockopt(sfd,SOL_SOCKET,SO_REUSEADDR,&i,sizeof(i))<0))
 {
  write(2,USAGE,strlen(USAGE));
  exit(2);
 }

 i = open("env/NICKLEN",0);
 if (i>0)
 {
   if (read(i,buffer0,1024)>0) NICKLEN = atoi(buffer0) & 255;
   else NICKLEN = 32;
 } else NICKLEN = 32;
 close(i);

 if ((!urcd)
 || (chdir(argv[2]))
 || (chroot(argv[2]))
 || (setgroups(0,'\x00'))
 || (setgid(urcd->pw_gid))
 || (setuid(urcd->pw_uid)))
 {
  write(2,USAGE,strlen(USAGE));
  exit(3);
 }

 fcntl(0,F_SETFL,fcntl(0,F_GETFL,0)&~O_NONBLOCK);

 memcpy(buffer2+2+12+4+8,":CryptoServ!urc@service PRIVMSG ",32);


 while (1)
 {

  for (i=0;i<1024;++i)
  {
    if (read(0,buffer0+i,1)<1) exit(4);
    if (buffer0[i] == '\r') --i;
    if (buffer0[i] == '\n') break;
  } if (buffer0[i] != '\n') continue;
  ++i;

  upper(buffer1,buffer0,i);

  if ((i>=7)&&(!memcmp("NICK ",buffer1,5))) { /* not reliable */
   nicklen=-5+i-1;
   if (nicklen<=NICKLEN) {
    memcpy(buffer2+2+12+4+8+32,buffer0+5,nicklen);
    memcpy(buffer2+2+12+4+8+32+nicklen," :",2);
   }
   else nicklen = 0;
  } else if (nicklen) {
   if ((i>=20)&&(!memcmp("PRIVMSG CRYPTOSERV :",buffer1,20))) {
    memcpy(buffer2+2+12+4+8+32+nicklen+2,"test\n",5);
    write(sfd,buffer2,2+12+4+8+32+nicklen+2+5);
    continue;
   }
  }
 if (write(1,buffer0,i)<0) exit(5);
 }
}

//   if ((i>=32) && (!memcmp(buffer1+20,"IDENTIFY ",9)
//crypto_scalarmult_curve25519_base(longtermpk,longtermsk);
