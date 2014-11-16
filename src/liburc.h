#include <nacl/crypto_secretbox.h>
#include <nacl/crypto_sign.h>
#include <nacl/crypto_box.h>
#include <sys/time.h>
#include <strings.h>
#include <stdlib.h>
#include <fcntl.h>
#include <tai.h>

/* security: enforce compatibility and santize malicious configurations */
#if crypto_secretbox_BOXZEROBYTES != 16
exit(255);
#endif
#if crypto_secretbox_ZEROBYTES != 32
exit(255);
#endif
#if crypto_sign_BYTES != 64
exit(255);
#endif

#define URC_MTU 1024
#define IRC_MTU 512

int setlen(unsigned char *b, int blen) {
 if (blen > URC_MTU) return -1;
 b[0] = blen / 256;
 b[1] = blen % 256;
 return 0;
}

/* security: strong entropy not guaranteed */
void randombytes(unsigned char *b, int blen) {
 /*
  static int devurandomfd = -1;
  if (devurandomfd == -1) open("/dev/urandom",O_RDONLY);
  if (devurandomfd == -1) {
 */
  int i;
  struct timeval now;
  for (i=0;i<blen;++i) {
   gettimeofday(&now,'\x00');
   srand(now.tv_usec);
   b[i] = rand() & 255;
  }
 /*
  }
  else read(devurandomfd,b,blen);
 */
}

void taia96n(unsigned char *ts) {
 int i;
 struct timeval now;
 tai_now(ts);
 tai_pack(ts,ts);
 gettimeofday(&now,'\x00');
 srand((unsigned) now.tv_usec);
 ts[7] &= (240 + (rand() & 15));
 randombytes(ts+8,4);
}

int urchub_fmt(unsigned char *p, unsigned char *b, int blen) {
 if (blen > IRC_MTU) return -1;
 if (setlen(p,blen) == -1) return -1;
 taia96n(p+2);
 p[12]=0;
 p[13]=0;
 p[14]=0;
 p[15]=0;
 randombytes(p+2+12+4,8);
 memmove(p+2+12+4+8,b,blen);
 return 0;
}

int urcsign_fmt(unsigned char *p, unsigned char *b, int blen, unsigned char *sk) {
 if (blen > IRC_MTU) return -1;
 unsigned char sm[2+12+4+8+1024+64];
 unsigned long long smlen;
 if (setlen(p,blen+64) == -1) return -1;
 taia96n(p+2);
 p[12]=1;
 p[13]=0;
 p[14]=0;
 p[15]=0;
 randombytes(p+2+12+4,8);
 memmove(p+2+12+4+8,b,blen);
 if (crypto_sign(sm,&smlen,p,2+12+4+8+blen,sk) == -1) return -1;
 memmove(p+2+12+4+8+blen,sm,32);
 memmove(p+2+12+4+8+blen+32,sm+smlen-32,32);
 return 0;
}

int urcsign_verify(unsigned char *p, int plen, unsigned char *pk) {
 if (plen > URC_MTU) return -1;
 unsigned char sm[32+2+12+4+8+1024+32];
 unsigned char m[32+2+12+4+8+1024+32];
 unsigned long long mlen;
 memmove(sm,p+plen-64,32);
 memmove(sm+32,p,plen-64);
 memmove(sm+32+plen-64,p+plen-32,32);
 return crypto_sign_open(m,&mlen,(const unsigned char *)sm,plen,(const unsigned char *)pk);
}

int urcsecretbox_fmt(unsigned char *p, unsigned char *b, int blen, unsigned char *sk) {
 if (blen > IRC_MTU) return -1;
 unsigned char m[1024*2];
 unsigned char c[1024*2];
 bzero(m,32); /* http://nacl.cr.yp.to/secretbox.html */
 bzero(c,16);
 if (setlen(p,blen+16) == -1) return -1;
 taia96n(p+2);
 p[12]=2;
 p[13]=0;
 p[14]=0;
 p[15]=0;
 randombytes(p+2+12+4,8);
 memmove(m+32,b,blen);
 if (crypto_secretbox(c,m,32+blen,(const unsigned char *)p+2,(const unsigned char *)sk) == -1) return -1;
 memmove(p+2+12+4+8,c+16,blen+16);
 return 0;
}

int urcsecretbox_open(unsigned char *b, unsigned char *p, int plen, unsigned char *sk) {
 if (plen > URC_MTU) return -1;
 unsigned char m[1024*2];
 unsigned char c[1024*2];
 bzero(m,32); /* http://nacl.cr.yp.to/secretbox.html */
 bzero(c,16);
 memmove(c+16,p+2+12+4+8,-2-12-4-8+plen);
 if (crypto_secretbox_open(m,c,16-2-12-4-8+plen,(const unsigned char *)p+2,(const unsigned char *)sk) == -1) return -1;
 memmove(b,m+32,-2-4-8+plen-16);
 return 0;
}

int urccryptobox_fmt(unsigned char *p, unsigned char *b, int blen, unsigned char *pk, unsigned char *sk) {
 if (blen > IRC_MTU) return -1;
 unsigned char m[1024*2];
 unsigned char c[1024*2];
 bzero(m,32); /* http://nacl.cr.yp.to/secretbox.html */
 bzero(c,16);
 if (setlen(p,blen+16) == -1) return -1;
 taia96n(p+2);
 p[12]=4;
 p[13]=0;
 p[14]=0;
 p[15]=0;
 randombytes(p+2+12+4,8);
 memmove(m+32,b,blen);
 if (crypto_box(c,m,32+blen,(const unsigned char *)p+2,(const unsigned char *)pk,(const unsigned char *)sk) == -1) return -1;
 memmove(p+2+12+4+8,c+16,blen+16);
 return 0;
}

int urccryptobox_open(unsigned char *b, unsigned char *p, int plen, unsigned char *pk, unsigned char *sk) {
 if (plen > URC_MTU) return -1;
 unsigned char m[1024*2];
 unsigned char c[1024*2];
 bzero(m,32); /* http://nacl.cr.yp.to/secretbox.html */
 bzero(c,16);
 memmove(c+16,p+2+12+4+8,-2-12-4-8+plen);
 if (crypto_box_open(m,c,16-2-12-4-8+plen,(const unsigned char *)p+2,(const unsigned char *)pk,(const unsigned char *)sk) == -1) return -1;
 memmove(b,m+32,-2-4-8+plen-16);
 return 0;
}
