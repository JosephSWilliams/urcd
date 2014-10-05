#include <nacl/crypto_hash_sha512.h>
#include <nacl/crypto_hash_sha256.h>
#include <nacl/crypto_secretbox.h>
#include <nacl/crypto_sign.h>
#include <nacl/crypto_box.h>
#include <sys/time.h>
#include <stdlib.h>
#include <fcntl.h>
#include <tai.h>

void setlen(unsigned char *b, int blen) {
 b[0] = blen / 256;
 b[1] = blen % 256;
}

/* security: strong entropy not guaranteed */
void randombytes(unsigned char *b, int blen) {
 int i;
 struct timeval now;
 for (i=0;i<blen;++i) {
  gettimeofday(&now,'\x00');
  srand(now.tv_usec);
  b[i] = rand() & 255;
 }
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
 setlen(p,blen);
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
 unsigned char sm[2+12+4+8+1024+crypto_sign_BYTES];
 unsigned long long smlen;
 setlen(p,blen+crypto_sign_BYTES);
 taia96n(p+2);
 p[12]=1;
 p[13]=0;
 p[14]=0;
 p[15]=0;
 randombytes(p+2+12+4,8);
 memmove(p+2+12+4+8,b,blen);
 if (crypto_sign(sm,&smlen,p,2+12+4+8+blen,sk) == -1) return -1;
 memmove(p+2+12+4+8+blen,sm,32);
 memmove(p+2+12+4+8+blen+32,sm+32+blen,32);
 return 0;
}
