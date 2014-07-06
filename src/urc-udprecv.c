#define USAGE "Usage: urc-udprecv addr port /path/to/sockets/\n"
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/fcntl.h>
#include <sys/types.h>
#include <strings.h>
#include <unistd.h>
#include <sys/un.h>
#include <stdlib.h>
#include <signal.h>
#include <stdio.h>
#include <pwd.h>

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

main(int argc, char **argv)
{

 int udpfd;
 struct sockaddr_in udp;
 bzero(&udp,sizeof(udp));
 udp.sin_family = AF_INET;

 if (
    (argc<4)
 || (!(udp.sin_port=htons(atoi(argv[2]))))
 || (!inet_pton(AF_INET,argv[1],&udp.sin_addr))
 || ((udpfd=socket(AF_INET,SOCK_DGRAM,IPPROTO_UDP))<0)
 || (bind(udpfd,(struct sockaddr *)&udp,sizeof(udp))<0)
    )
 {
  write(2,USAGE,strlen(USAGE));
  exit(64);
 }

 unsigned char buffer[1024] = {0};

 int n;
 float LIMIT;
 n = open("env/LIMIT",0);
 if (n>0)
 {
   if (read(n,buffer,1024)>0) LIMIT = atof(buffer);
   else LIMIT = 1.0;
 } else LIMIT = 1.0;
 close(n);

 if (chdir(argv[3])) exit(64);
 struct passwd *urcd = getpwnam("urcd");
 if ((!urcd) || ((chroot(argv[3])) || (setgid(urcd->pw_gid)) || (setuid(urcd->pw_uid)))) exit(64);

 int sockfd;
 struct sockaddr_un sock;
 bzero(&sock,sizeof(sock));
 sock.sun_family = AF_UNIX;

 if ((sockfd=socket(AF_UNIX,SOCK_DGRAM,0))<0) exit(1);
 if (setsockopt(sockfd,SOL_SOCKET,SO_REUSEADDR,&n,sizeof(n=1))<0) exit(2);
 if (fcntl(sockfd,F_SETFL,O_NONBLOCK)<0) exit(3);

 struct sockaddr_un hub;
 bzero(&hub,sizeof(hub));
 hub.sun_family = AF_UNIX;
 memcpy(&hub.sun_path,"hub\0",4);

 while (1)
 {
  usleep((int)(LIMIT*1000000));
  if (
     ((n=read(udpfd,buffer,1024))<2+12+4+8)
  || (n!=buffer[0]*256+buffer[1])
     ) continue;
  if (sendto(sockfd,buffer,n,MSG_DONTWAIT,(struct sockaddr *)&hub,sizeof(hub))<0) usleep(262144);
 }
}
