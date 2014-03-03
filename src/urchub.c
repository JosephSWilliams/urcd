#define USAGE "Usage: urchub ./urccache /path/to/sockets/\n"
#include <sys/socket.h>
#include <sys/fcntl.h>
#include <sys/types.h>
#include <strings.h>
#include <unistd.h>
#include <sys/un.h>
#include <stdlib.h>
#include <signal.h>
#include <dirent.h>
#include <string.h>
#include <stdio.h>
#include <poll.h>
#include <taia.h>
#include <pwd.h>

#ifndef UNIX_PATH_MAX
#define UNIX_PATH_MAX 108
#endif

main(int argc, char **argv)
{

  if (argc<3)
  {
    write(2,USAGE,strlen(USAGE));
    exit(64);
  }

  int cache_pid;
  unsigned char ret[1];
  int cachein[2], cacheout[2];

  if ((pipe(cachein)<0) || (pipe(cacheout)<0)) exit(1);
  cache_pid = fork();
  if (!cache_pid)
  {
    close(0);
    close(1);
    dup(cachein[0]);
    dup(cacheout[1]);
    close(cachein[1]);
    close(cacheout[0]);
    execvp(argv[1],argv+1);
  } else {
    if (cache_pid<0) exit(2);
  } close(cachein[0]); close(cacheout[1]);

  if (chdir(argv[2])) exit(64);
  struct passwd *urcd = getpwnam("urcd");
  if ((!urcd) || ((chroot(argv[2])) || (setgid(urcd->pw_gid)) || (setuid(urcd->pw_uid)))) exit(64);

  unsigned char buffer[2+16+8+65536];
  char user[] = "hub\0";
  int sockfd;

  struct sockaddr_un sock;
  bzero(&sock,sizeof(sock));
  sock.sun_family = AF_UNIX;

  void sock_close(int signum)
  {
    unlink(sock.sun_path);
    exit(signum);
  } signal(SIGINT,sock_close); signal(SIGHUP,sock_close); signal(SIGTERM,sock_close); signal(SIGCHLD,sock_close); 

  sockfd = socket(AF_UNIX,SOCK_DGRAM,0);
  if (sockfd<0) exit(3);
  int n = 1;
  if (setsockopt(sockfd,SOL_SOCKET,SO_REUSEADDR,&n,sizeof(n))<0) exit(4);
  int userlen = strlen(user);
  if (userlen > UNIX_PATH_MAX) exit(5);
  memcpy(&sock.sun_path,user,userlen);
  unlink(sock.sun_path);
  if (bind(sockfd,(struct sockaddr_un *)&sock,sizeof(sock))<0) exit(6);

  int strlen_recvpath;
  struct sockaddr_un recvpath;
  recvpath.sun_family = AF_UNIX;
  socklen_t recvpath_len = sizeof(struct sockaddr_un);

  DIR *root;
  int sendpath_len;
  struct dirent *sendpath;
  struct sockaddr_un sendpaths;
  sendpaths.sun_family = AF_UNIX;

  while (1)
  {
    bzero(recvpath.sun_path,UNIX_PATH_MAX);
    n = recvfrom(sockfd,buffer,65536,0,(struct sockaddr_un *)&recvpath,&recvpath_len);
    if (!n) continue;
    if (n<0) sock_close(7);
    if (n!=2+16+8+buffer[0]*256+buffer[1]) continue;
    if (write(cachein[1],buffer,n)<0) sock_close(8);
    if (read(cacheout[0],ret,1)<1) sock_close(9);
    if (ret[0]) continue;

    root = opendir("/");
    if (!root) sock_close(10);
    strlen_recvpath = strlen(recvpath.sun_path);
    while ((sendpath = readdir(root)))
    {
      if (sendpath->d_name[0] == '.') continue;
      sendpath_len = strlen(sendpath->d_name);
      if (sendpath_len > UNIX_PATH_MAX) continue;
      if ((sendpath_len == userlen) && (!memcmp(sendpath->d_name,user,userlen))) continue;
      if ((sendpath_len == strlen_recvpath) && (!memcmp(sendpath->d_name,recvpath.sun_path,strlen_recvpath))) continue;
      bzero(sendpaths.sun_path,UNIX_PATH_MAX);
      memcpy(&sendpaths.sun_path,sendpath->d_name,sendpath_len);
      sendto(sockfd,buffer,n,MSG_DONTWAIT,(struct sockaddr_un *)&sendpaths,sizeof(sendpaths));
    } closedir(root);
  }
}
