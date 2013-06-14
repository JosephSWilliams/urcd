#include <unistd.h>
#include <string.h>
#define USAGE "Usage: ucspi-client2server prog [args]\n"
int main (int argc, char **argv) {
 if (argc>2) {
  dup2(6,0);
  dup2(7,1);
  execvp(argv[1],argv+1);
 }
 write(2,USAGE,strlen(USAGE));
 return 255;
}
