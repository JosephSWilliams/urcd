#include <sys/fcntl.h>
#include <poll.h>
int main(){

fcntl(0,4,2050); fcntl(1,4,2050);
fcntl(6,4,2050); fcntl(7,4,2050);

struct pollfd fds[4];
fds[0].fd=0; fds[0].events=3;
fds[1].fd=6; fds[1].events=3;
fds[2].fd=1; fds[2].events=4;
fds[3].fd=7; fds[3].events=4;

unsigned char client_buffer[1024]={0};
unsigned char server_buffer[1024]={0};

int client_eagain=0;
int server_eagain=0;

int in=0, out=0;

while (1){

  poll(fds,2,-1);
  poll(fds+2,2,0);

  if ((server_eagain)||(fds[0].revents)){
    if (fds[3].revents){
      if (server_eagain<1024){
        in=read(0,&server_buffer[server_eagain],1024-server_eagain);
        if (in<1) break;}
      else in=0;
      out=write(7,server_buffer,server_eagain+in);
      if (out<0) break;
      if (out<server_eagain+in){
        memmove(server_buffer,&server_buffer[out],server_eagain+in-out);
        server_eagain=server_eagain+in-out;}
      else server_eagain=0;}}

  if ((client_eagain)||(fds[1].revents)){
    if (fds[2].revents){
      if (client_eagain<1024){
        in=read(6,&client_buffer[client_eagain],1024-client_eagain);
        if (in<1) break;}
      else in=0;
      out=write(1,client_buffer,client_eagain+in);
      if (out<0) break;
      if (out<client_eagain+in){
        memmove(client_buffer,&client_buffer[out],client_eagain+in-out);
        client_eagain=client_eagain+in-out;}
      else client_eagain=0;}}}}
