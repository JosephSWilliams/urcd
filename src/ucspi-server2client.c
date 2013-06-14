#include <unistd.h>
#include <string.h>
#define USAGE "Usage: ucspi-server2client prog [args]\n"
int main (int argc, char **argv) {
 if (argc>2) {
  dup2(0,6);
  dup2(1,7);
  execvp(argv[1],argv+1);
 }
 write(2,USAGE,strlen(USAGE));
 return 255;
}
