#define USAGE "Usage: urcstream2hub /path/to/hub/sockets/ ./urcstream /path/to/sockets/\n"
#include <sys/socket.h>
#include <sys/fcntl.h>
#include <sys/types.h>
#include <unistd.h>
#include <sys/un.h>
#include <stdlib.h>
#include <signal.h>
#include <string.h>
#include <stdio.h>
#include <poll.h>
#include <taia.h>
#include <pwd.h>

#ifndef UNIX_PATH_MAX
#define UNIX_PATH_MAX 108
#endif

int itoa(char *s, int n, int slen)
{
  int fd[2], ret = 0;
  if (pipe(fd)<0) return -1;
  if ((dprintf(fd[1],"%d",n)<0) || (read(fd[0],s,slen)<0)) --ret;
  close(fd[0]);
  close(fd[1]);
  return ret;
}

main(int argc, char **argv)
{

  if (argc<4)
  {
    write(2,USAGE,strlen(USAGE));
    exit(64);
  }

  int urcstream_pid;
  int urcstreamin[2], urcstreamout[2];

  if ((pipe(urcstreamin)<0) || (pipe(urcstreamout)<0)) exit(1);
  urcstream_pid = fork();
  if (!urcstream_pid)
  {
    close(0);
    close(1);
    dup(urcstreamin[0]);
    dup(urcstreamout[1]);
    close(urcstreamin[1]);
    close(urcstreamout[0]);
    execvp(argv[2],argv+2);
  } else {
    if (urcstream_pid<0) exit(2);
  } close(urcstreamin[0]); close(urcstreamout[1]);

  int devurandom = open("/dev/urandom",O_RDONLY);
  if (devurandom<0) exit(3);

  if (chdir(argv[1])) exit(64);
  struct passwd *urcd = getpwnam("urcd");
  if ((!urcd) || ((chroot(argv[1])) || (setgid(urcd->pw_gid)) || (setuid(urcd->pw_uid)))) exit(64);

  char buffer[2+16+8+1024] = {0};
  char user[UNIX_PATH_MAX] = {0};
  if (itoa(user,getpid(),UNIX_PATH_MAX)<0) exit(4);

  int sockfd;
  struct sockaddr_un sock;
  memset(&sock,0,sizeof(sock));
  sock.sun_family = AF_UNIX;

  void sock_close(int signum)
  {
    unlink(sock.sun_path);
    exit(signum);
  } signal(SIGINT,sock_close); signal(SIGHUP,sock_close); signal(SIGTERM,sock_close); signal(SIGCHLD,sock_close); 

  sockfd = socket(AF_UNIX,SOCK_DGRAM,0);
  if (sockfd<0) exit(5);
  int n = 1;
  if (setsockopt(sockfd,SOL_SOCKET,SO_REUSEADDR,&n,sizeof(n))<0) exit(6);
  int userlen = strlen(user);
  if (userlen > UNIX_PATH_MAX) exit(7);
  memmove(&sock.sun_path,user,userlen+1);
  unlink(sock.sun_path);
  if (bind(sockfd,(struct sockaddr *)&sock,sizeof(sock.sun_family)+userlen)<0) exit(8);
  if (fcntl(sockfd,F_SETFL,O_NONBLOCK)<0) sock_close(9);

  struct pollfd fds[2];
  fds[0].fd = urcstreamout[0]; fds[0].events = POLLIN | POLLPRI;
  fds[1].fd = sockfd; fds[1].events = POLLIN;

  struct sockaddr_un hub;
  memset(&hub,0,sizeof(hub));
  hub.sun_family = AF_UNIX;
  memset(hub.sun_path,0,UNIX_PATH_MAX);
  memmove(&hub.sun_path,"hub\0",4);

  while (1)
  {

    poll(fds,2,-1);

    if (fds[0].revents)
    {

      for (n=0;n<1024;++n)
      {
        if (read(urcstreamout[0],buffer+2+16+8+n,1)<1) sock_close(10);
        if (buffer[2+16+8+n] == '\n') break;
      } if (buffer[2+16+8+n] != '\n') goto urcwrite;
      ++n;
      buffer[0] = n / 256;
      buffer[1] = n % 256;
      taia_now(buffer+2);
      taia_pack(buffer+2,buffer+2);
      if (read(devurandom,buffer+2+16,8)<8) sock_close(11);
      if (sendto(sockfd,buffer,2+16+8+n,0,(struct sockaddr *)&hub,sizeof(hub))<0) usleep(250000);

    }

    urcwrite: while (poll(fds+1,1,0))
    {
      n = read(sockfd,buffer,2+16+8+1024);
      if (n<1) sock_close(12);
      if (buffer[n-1] != '\n') continue;
      if (n!=2+16+8+buffer[0]*256+buffer[1]) continue;
      if (write(urcstreamin[1],buffer+2+16+8,-2-16-8+n)<0) sock_close(13);
    }

  }

}
