#define USAGE "Usage: ucspi-socks4aclient addr port prog [args]\n"
int main(int argc, char **argv){

if ((argc<4)||(strlen(argv[1])>256)||(atoi(argv[2])<0)||(atoi(argv[2])>65535)){
  write(2,USAGE,strlen(USAGE));
  exit(64);}

unsigned char packet[512]={0};
packet[ 0] = '\x04';
packet[ 1] = '\x01';
packet[ 2] = atoi(argv[2])/256;
packet[ 3] = atoi(argv[2])%256;
packet[ 7] = '\x01';
packet[ 8] = 'u';
packet[ 9] = 'c';
packet[10] = 's';
packet[11] = 'p';
packet[12] = 'i';

memmove(&packet[14],argv[1],strlen(argv[1])+1);
if (write(7,packet,14+strlen(argv[1])+1)<14+strlen(argv[1])+1) exit(128+111);
bzero(packet,512);
if (read(6,packet,8)<8) exit(128+32);
if ((packet[0]!=0)||(packet[1]!=90)) exit(128+111);
execvp(argv[3],argv+3);}
