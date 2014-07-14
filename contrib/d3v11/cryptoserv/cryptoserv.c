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
#include <poll.h>
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
 struct pollfd fd[1];

 unsigned char buffer0[1024];
 unsigned char buffer1[1024];
 unsigned char hk[32+32+64+64];
 unsigned char sk[32+64];

 int i = strlen(argv[1]);
 int sfd = -1;

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
// fd[0].events = POLLIN | POLLPRI;
// fd[0].fd = 0;

 while (1)
 {

//  poll(fd,1,-1);

  for (i=0;i<1024;++i)
  {
    if (read(0,buffer1+i,1)<1) exit(4);
    if (buffer1[i] == '\r') --i;
    if (buffer1[i] == '\n') break;
  } if (buffer1[i] != '\n') continue;
  ++i;

  if (write(1,buffer1,i)<0) exit(5);

 }

//  upper(buffer0,buffer1,n);

  
//crypto_scalarmult_curve25519_base(longtermpk,longtermsk);

}
