#define USAGE "Usage: urcstream /path/to/sockets/\n"
#include <sys/socket.h>
#include <sys/fcntl.h>
#include <sys/types.h>
#include <strings.h>
#include <unistd.h>
#include <sys/un.h>
#include <stdlib.h>
#include <signal.h>
#include <dirent.h>
#include <stdio.h>
#include <poll.h>
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

  if (argc<2)
  {
    write(2,USAGE,strlen(USAGE));
    exit(64);
  }

  int rd = 0, wr = 1;
  if (getenv("TCPCLIENT")){ rd = 6; wr = 7; }

  char buffer[1024] = {0};
  char user[UNIX_PATH_MAX] = {0};
  if (itoa(user,getpid(),UNIX_PATH_MAX)<0) exit(1);

  int n;
  float LIMIT;
  n = open("env/LIMIT",0);
  if (n>0)
  {
    if (read(n,buffer,1024)>0) LIMIT = atof(buffer);
    else LIMIT = 1.0;
  } else LIMIT = 1.0;
  close(n);

  struct passwd *urcd = getpwnam("urcd");

  if ((!urcd)
  || (chdir(argv[1]))
  || (chroot(argv[1]))
  || (setgroups(0,'\x00'))
  || (setgid(urcd->pw_gid))
  || (setuid(urcd->pw_uid))) exit(64);

  int sockfd;
  struct sockaddr_un sock;
  bzero(&sock,sizeof(sock));
  sock.sun_family = AF_UNIX;

  void sock_close(int signum)
  {
    unlink(sock.sun_path);
    exit(signum);
  } signal(SIGINT,sock_close);
    signal(SIGHUP,sock_close);
    signal(SIGTERM,sock_close);

  sockfd = socket(AF_UNIX,SOCK_DGRAM,0);
  if (socket(AF_UNIX,SOCK_DGRAM,0)<0) exit(2);
  n = 1;
  if (setsockopt(sockfd,SOL_SOCKET,SO_REUSEADDR,&n,sizeof(n))<0) exit(3);
  int userlen = strlen(user);
  if (userlen > UNIX_PATH_MAX) exit(4);
  memcpy(&sock.sun_path,user,userlen);
  unlink(sock.sun_path);
  if (bind(sockfd,(struct sockaddr *)&sock,sizeof(sock))<0) exit(5);

  struct pollfd fds[2];
  fds[0].fd = rd; fds[0].events = POLLIN | POLLPRI;
  fds[1].fd = sockfd; fds[1].events = POLLIN;

  DIR *root;
  int pathlen;
  struct dirent *path;
  struct sockaddr_un paths;
  paths.sun_family = AF_UNIX;

  while (1) {

    poll(fds,2,-1);

    if (fds[0].revents) {

      usleep((int)(LIMIT*1000000));

      for (n=0;n<1024;++n)
      {
        if (read(rd,buffer+n,1)<1) sock_close(6);
        if (buffer[n] == '\n') break;
      } if (buffer[n] != '\n') goto urcwrite;
      ++n;

      root = opendir("/");
      if (!root) sock_close(7);
      while ((path = readdir(root)))
      {
        if (path->d_name[0] == '.') continue;
        pathlen = strlen(path->d_name);
        if (pathlen > UNIX_PATH_MAX) continue;
        if ((pathlen == userlen) && (!memcmp(path->d_name,user,userlen))) continue;
        bzero(paths.sun_path,UNIX_PATH_MAX);
        memcpy(&paths.sun_path,path->d_name,pathlen);
        sendto(sockfd,buffer,n,MSG_DONTWAIT,(struct sockaddr *)&paths,sizeof(paths));
      } closedir(root);
    }

    urcwrite: while (poll(fds+1,1,0))
    {
      n = read(sockfd,buffer,1024);
      if (!n) continue;
      if (n<0) sock_close(8);
      if (buffer[n-1] != '\n') continue;
      if (write(wr,buffer,n)<0) sock_close(9);
    }
  }
}
