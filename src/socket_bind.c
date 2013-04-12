#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <errno.h>
#include "socket.h"
#include "byte.h"

int socket_bind(int fd,const unsigned char *ip,const unsigned char *port)
{
  struct sockaddr_in sa;
  byte_zero(&sa,sizeof sa);
  byte_copy(&sa.sin_addr,4,ip);
  byte_copy(&sa.sin_port,2,port);

  /* AF_UNSPEC EAFNOSUPPORT -- d3v11 */
  if (bind(fd,(struct sockaddr *) &sa,sizeof sa) < 0)
  {
    sa.sin_family = AF_INET;
    return bind(fd,(struct sockaddr *) &sa,sizeof sa);
  }
  return 0;
}
