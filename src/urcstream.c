#define USAGE "Usage: urcstream /path/to/sockets/\n"
#include <sys/socket.h>
#include <sys/fcntl.h>
#include <sys/types.h>
#include <unistd.h>
#include <sys/un.h>
#include <stdlib.h>
#include <signal.h>
#include <dirent.h>
#include <stdio.h>
#include <poll.h>
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

  if (argc<2)
  {
    write(2,USAGE,strlen(USAGE));
    exit(64);
  }

  int rd, wr = 1;
  if (getenv("TCPCLIENT")) wr += 6;
  rd = wr - 1;

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

  if (chdir(argv[1])) exit(64);
  struct passwd *urcd = getpwnam("urcd");
  if ((!urcd) || ((chroot(argv[1])) || (setgid(urcd->pw_gid)) || (setuid(urcd->pw_uid)))) exit(64);

  struct sockaddr_un sock;
  memset(&sock,0,sizeof(sock));
  sock.sun_family = AF_UNIX;

  void sock_close(int signum)
  {
    unlink(sock.sun_path);
    exit(signum);
  } signal(SIGINT,sock_close); signal(SIGHUP,sock_close); signal(SIGTERM,sock_close); 

  if (socket(AF_UNIX,SOCK_DGRAM,0)!=3) exit(2);
  n = 1;
  if (setsockopt(3,SOL_SOCKET,SO_REUSEADDR,&n,sizeof(n))<0) exit(3);
  int userlen = strlen(user);
  if (userlen > UNIX_PATH_MAX) exit(4);
  memmove(&sock.sun_path,user,userlen+1);
  unlink(sock.sun_path);
  if (bind(3,(struct sockaddr *)&sock,sizeof(sock.sun_family)+userlen)<0) exit(5);
  if (fcntl(3,F_SETFL,O_NONBLOCK)<0) sock_close(6);

  struct pollfd fds[2];
  fds[0].fd = rd; fds[0].events = POLLIN | POLLPRI;
  fds[1].fd = 3; fds[1].events = POLLIN;

  DIR *root;
  int pathlen;
  struct dirent *path;
  struct sockaddr_un paths;
  paths.sun_family = AF_UNIX;

  while (1)
  {

    poll(fds,2,-1);

    if (fds[0].revents)
    {

      usleep((int)(LIMIT*1000000));

      for (n=0;n<1024;++n)
      {
        if (read(rd,buffer+n,1)<1) sock_close(7);
        if (buffer[n] == '\n') break;
      } if (buffer[n] != '\n') goto urcwrite;

      root = opendir("/");
      if (!root) sock_close(8);

      while ((path = readdir(root)))
      {
        if (path->d_name[0] == '.') continue;
        pathlen = strlen(path->d_name);
        if (pathlen > UNIX_PATH_MAX) continue;
        if ((pathlen == userlen) && (!memcmp(path->d_name,user,userlen))) continue;
        memset(paths.sun_path,0,sizeof(paths.sun_path));
        memmove(&paths.sun_path,path->d_name,pathlen);
        sendto(3,buffer,n+1,0,(struct sockaddr *)&paths,sizeof(paths));
      } closedir(root);

    }

    urcwrite: while (poll(fds+1,1,0))
    {
      n = read(3,buffer,1024);
      if (n<1) sock_close(9);
      if (buffer[n-1] != '\n') continue;
      if (write(wr,buffer,n)<0) sock_close(10);
    }

  }
}
