#include <stdlib.h>
#include <string.h>
#include <poll.h>

#define NICK_CMD "NICK nameless\n"

int main() {

 int n;
 int FNC = 0;
 unsigned char buffer[1024] = {0};
 const int NICK_CMD_LEN = strlen(NICK_CMD);

 struct pollfd fds[1];
 fds[0].fd = 0;
 fds[0].events = POLLIN | POLLPRI;

 while (1) {

  poll(fds,1,-1);

  for (n=0;n<1024;++n)
  {
    if (read(0,buffer+n,1)<1) exit(1);
    if (buffer[n] == '\n') break;
  } if (buffer[n] != '\n') exit(2);
  ++n;

  if ( (!FNC) && (n>=6)
  && (
    ((!memcmp(buffer,"NICK ",5)) || (!memcmp(buffer,"nick ",5)))
   )
  ) {
   if (write(1,NICK_CMD,NICK_CMD_LEN)<0) exit(3);
   ++FNC;
  }
  else if (write(1,buffer,n)<0) exit(4);

 }
}
