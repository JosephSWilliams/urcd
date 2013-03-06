#define USAGE "Usage: urcstream /path/to/sockets/\n"
#include <sys/socket.h>
#include <sys/fcntl.h>
#include <sys/types.h>
#include <sys/time.h>
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
  int fd[2];
  if (pipe(fd)<0) return -1;
  dprintf(fd[1],"%d",n);
  read(fd[0],s,slen);
  close(fd[0]);
  close(fd[1]);
  return 0;
}

main(int argc, char **argv)
{

  if (argc<2)
  {
    write(2,USAGE,strlen(USAGE));
    exit(64);
  }

  if (chdir(argv[1])) exit(64);
  struct passwd *urcd = getpwnam("urcd");
  if ((!urcd) || ((chroot(argv[1])) || (setgid(urcd->pw_gid)) || (setuid(urcd->pw_uid)))) exit(64);

  int rd, wr = 1;
  if (getenv("TCPCLIENT")) wr += 6;
  rd = wr - 1;

  char buffer[1024] = {0};

  char user[UNIX_PATH_MAX] = {0};
  if (itoa(user,getpid(),UNIX_PATH_MAX)<0) exit(1);

  int n, LIMIT;
  n = open("env/LIMIT",0);
  if (n>0)
  {
    if (read(n,buffer,1024)) LIMIT = atoi(buffer);
    else LIMIT = 1;
  } else LIMIT = 1;
  close(n);

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
  n = strlen(user);
  if (n>=UNIX_PATH_MAX) exit(4);
  memmove(&sock.sun_path,user,n+1);
  unlink(sock.sun_path);
  if (bind(3,(struct sockaddr *)&sock,sizeof(sock.sun_family)+n)<0) exit(5);
  if (fcntl(3,F_SETFL,O_NONBLOCK)<0) sock_close(6);

  struct pollfd fds[2];
  fds[0].fd = rd; fds[0].events = POLLIN | POLLPRI;
  fds[1].fd = 3; fds[1].events = POLLIN;

  DIR *root;
  struct dirent *path;
  struct sockaddr_un paths;
  paths.sun_family = AF_UNIX;

  int old;
  struct timeval now;
  struct timezone *utc = (struct timezone *)0;
  gettimeofday(&now,utc);
  old = now.tv_sec;

  while (1)
  {

    poll(fds,2,-1);

    gettimeofday(&now,utc);
    if (now.tv_sec - old > LIMIT) old = now.tv_sec;
    else sleep(LIMIT);

    if (fds[0].revents)
    {

      for (n=0;n<1024;++n)
      {
        if (read(rd,buffer+n,1)<1) sock_close(7);
        if (buffer[n] == '\n') break;
      } if (buffer[n] != '\n') continue;

      root = opendir("/");
      if (!root) sock_close(8);

      while ((path = readdir(root)))
      {
        if (path->d_name[0] == '.') continue;
        if (strlen(path->d_name) >= UNIX_PATH_MAX) continue;
        if ((strlen(path->d_name) == strlen(user)) && (!memcmp(path->d_name,user,strlen(user)))) continue;
        memset(paths.sun_path,0,sizeof(paths.sun_path));
        memmove(&paths.sun_path,path->d_name,strlen(path->d_name));
        sendto(3,buffer,n+1,0,(struct sockaddr *)&paths,sizeof(paths));
      }

    }

    if (fds[1].revents)
    {
      n = read(3,buffer,1024);
      if (n<1) sock_close(9);
      if (buffer[n-1] != '\n') continue;
      if (write(wr,buffer,n)<0) sock_close(10);
    }

  }
}

