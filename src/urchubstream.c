#define USAGE "Usage: urchubstream /path/to/sockets/\n"
#include <sys/socket.h>
#include <sys/fcntl.h>
#include <sys/types.h>
#include <strings.h>
#include <unistd.h>
#include <sys/un.h>
#include <stdlib.h>
#include <signal.h>
#include <stdio.h>
#include <poll.h>
#include <pwd.h>

#ifndef UNIX_PATH_MAX
#define UNIX_PATH_MAX 108
#endif

int itoa(char *s, int n, int slen)
{
  if (snprintf(s,slen,"%d",n)<0) return -1;
  return 0;
}

main(int argc, char **argv)
{

  if (argc<2)
  {
    write(2,USAGE,strlen(USAGE));
    exit(64);
  }

  int devurandomfd = open("/dev/urandom",O_RDONLY);
  if (devurandomfd<0) exit(255);
  unsigned char byte[1];

  int i, n, l;
  unsigned char buffer[2+16+8+1024] = {0};
  int rd = 0, wr = 1, sd = -1;
  if (getenv("TCPCLIENT")){ rd = 6; wr = 7; }

  float LIMIT;
  n = open("env/LIMIT",0);
  if (n>0)
  {
    if (read(n,buffer,1024)>0) LIMIT = atof(buffer);
    else LIMIT = 1.0;
  } else LIMIT = 1.0;
  close(n);

  char user[UNIX_PATH_MAX] = {0};
  if (itoa(user,getpid(),UNIX_PATH_MAX)<0) exit(1);

  if (chdir(argv[1])) exit(64);
  struct passwd *urcd = getpwnam("urcd");
  if ((!urcd) || ((chroot(argv[1])) || (setgid(urcd->pw_gid)) || (setuid(urcd->pw_uid)))) exit(64);

  struct sockaddr_un sock;
  bzero(&sock,sizeof(sock));
  sock.sun_family = AF_UNIX;

  void sock_close(int signum)
  {
    unlink(sock.sun_path);
    exit(signum);
  } signal(SIGINT,sock_close); signal(SIGHUP,sock_close); signal(SIGTERM,sock_close); 

  if ((sd=socket(AF_UNIX,SOCK_DGRAM,0))<0) exit(2);
  n = 1;
  if (setsockopt(sd,SOL_SOCKET,SO_REUSEADDR,&n,sizeof(n))<0) exit(3);
  int userlen = strlen(user);
  if (userlen > UNIX_PATH_MAX) exit(4);
  memcpy(&sock.sun_path,user,userlen);
  unlink(sock.sun_path);
  if (bind(sd,(struct sockaddr *)&sock,sizeof(sock))<0) exit(5);

  struct pollfd fds[2];
  fds[0].fd = rd; fds[0].events = POLLIN | POLLPRI;
  fds[1].fd = sd; fds[1].events = POLLIN;

  struct sockaddr_un hub;
  bzero(&hub,sizeof(hub));
  hub.sun_family = AF_UNIX;
  memcpy(&hub.sun_path,"hub\0",4);

  while (1) {

    poll(fds,2,-1);

    if (fds[0].revents)
    {
      if (read(rd,buffer,2)<2) sock_close(7);
      n = 2;
      l = 2+16+8+buffer[0]*256+buffer[1];
      if (l>2+16+8+1024) sock_close(8);

      while (n<l)
      {
        i = read(rd,buffer+n,l-n);
        if (i<1) sock_close(9);
        n += i;
      } usleep((int)(LIMIT*1000000));
      if (sendto(sd,buffer,n,MSG_DONTWAIT,(struct sockaddr *)&hub,sizeof(hub))<0) usleep(262144);
    }

    while ((poll(fds,2,0)) && (!fds[0].revents))
    {
      n = read(sd,buffer,2+16+8+1024);
      if (!n) continue;
      if (n<0) sock_close(10);
      if (read(devurandomfd,byte,1)<1) sock_close(11);
      poll(fds+1,1,byte[0]<<4);
      if (n!=2+16+8+buffer[0]*256+buffer[1]) continue;
      if (write(wr,buffer,n)<0) sock_close(12);
    }
  }
}
