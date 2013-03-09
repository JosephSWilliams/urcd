#define USAGE "Usage: urcrecv /path/to/sockets/\n"
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

main(int argc, char **argv)
{

  if (argc<2)
  {
    write(2,USAGE,strlen(USAGE));
    exit(64);
  }

  char buffer[1024] = {0};

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
  memset(sock.sun_path,0,sizeof(sock.sun_path));
  sock.sun_family = AF_UNIX;

  if (socket(AF_UNIX,SOCK_DGRAM,0)!=3) exit(1);
  n = 1;
  if (setsockopt(3,SOL_SOCKET,SO_REUSEADDR,&n,sizeof(n))<0) exit(2);
  if (fcntl(3,F_SETFL,O_NONBLOCK)<0) exit(3);

  struct pollfd fds[1];
  fds[0].fd = 0;
  fds[0].events = POLLIN | POLLPRI;


  DIR *root;
  int pathlen;
  struct dirent *path;
  struct sockaddr_un paths;
  paths.sun_family = AF_UNIX;

  while (1)
  {

    poll(fds,1,-1);

    usleep((int)(LIMIT*1000000));

    for (n=0;n<1024;++n)
    {
      if (read(0,buffer+n,1)<1) exit(4);
      if (buffer[n] == '\n') break;
    } if (buffer[n] != '\n') continue;

    root = opendir("/");
    if (!root) exit(5);

    while ((path = readdir(root)))
    {
      if (path->d_name[0] == '.') continue;
      pathlen = strlen(path->d_name);
      if (pathlen > UNIX_PATH_MAX) continue;
      memset(paths.sun_path,0,sizeof(paths.sun_path));
      memmove(&paths.sun_path,path->d_name,pathlen);
      sendto(3,buffer,n+1,0,(struct sockaddr *)&paths,sizeof(paths));
    } closedir(root);

  }
}
