#include <nacl/crypto_hash_sha512.h>
#include <nacl/crypto_secretbox.h>
#include <nacl/crypto_stream.h>
#include <nacl/crypto_sign.h>
#include <nacl/crypto_box.h>
#include <sys/types.h>
#include <sys/time.h>
#include <strings.h>
#include <unistd.h>
#include <stdlib.h>
#include <fcntl.h>
#include <tai.h>
#include <pwd.h>

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

int devurandomfd = -1;

int urc_jail(char *path) {
 if (devurandomfd == -1) devurandomfd = open("/dev/arandom",O_RDONLY);
 if (devurandomfd == -1) devurandomfd = open("/dev/urandom",O_RDONLY);
 struct passwd *urcd = getpwnam("urcd");
 if ((!urcd)
 || (chdir(path))
 || (chroot(path))
 || (setgroups(0,'\x00'))
 || (setgid(urcd->pw_gid))
 || (setuid(urcd->pw_uid)))
  return -1;
 return 0;
}

/* security: strong entropy not guaranteed without devurandomfd open */
void randombytes(unsigned char *d, int dlen) {
 unsigned char *b = malloc(64 * sizeof(unsigned char));
 unsigned char a[64];
 unsigned char c[64];
 struct timeval now;
 int i;
 if (devurandomfd == -1) devurandomfd = open("/dev/arandom",O_RDONLY);
 if (devurandomfd == -1) devurandomfd = open("/dev/urandom",O_RDONLY);
 if (devurandomfd == -1) {
  for (i=0;i<64;++i) {
   gettimeofday(&now,'\x00'); srand(now.tv_usec); a[i] = 255 & rand();
   if (b) a[i] ^= b[i];
   a[i] ^= c[i];
  }
 }
 else while (read(devurandomfd,a,64) != 64) sleep(1); /* potential EDEADLK */
 crypto_hash_sha512(c,a,64);
 crypto_stream(d,dlen,c,c+24);
 if (b) free(b);
}

int setlen(unsigned char *b, int blen) {
 if (blen > URC_MTU) return -1;
 b[0] = blen / 256;
 b[1] = blen % 256;
 return 0;
}

void taia96n(unsigned char *ts) {
 struct timeval now;
 tai_now(ts);
 tai_pack(ts,ts);
 gettimeofday(&now,'\x00');
 srand((unsigned) now.tv_usec);
 ts[7] &= (240 + (rand() & 15));
 randombytes(ts+8,4);
}

int urchub_fmt(unsigned char *p, int *plen, unsigned char *b, int blen) {
 if (blen > IRC_MTU) return -1;
 if (setlen(p,blen) == -1) return -1;
 taia96n(p+2);
 p[14]=0;
 p[15]=0;
 p[16]=0;
 p[17]=0;
 randombytes(p+2+12+4,8);
 memmove(p+2+12+4+8,b,blen);
 *plen=2+12+4+8+blen;
 return 0;
}

int urcsign_fmt(unsigned char *p, int *plen, unsigned char *b, int blen, unsigned char *sk) {
 if (blen > IRC_MTU) return -1;
 unsigned char sm[1024*2] = {0};
 unsigned long long smlen;
 if (setlen(p,blen+64) == -1) return -1;
 taia96n(p+2);
 p[14]=1;
 p[15]=0;
 p[16]=0;
 p[17]=0;
 randombytes(p+2+12+4,8);
 memmove(p+2+12+4+8,b,blen);
 if (crypto_sign_edwards25519sha512batch(sm,&smlen,p,(unsigned long long)(2+12+4+8+blen),sk) == -1) return -1;
 memmove(p+2+12+4+8+blen,sm,32);
 memmove(p+2+12+4+8+blen+32,sm+smlen-32,32);
 *plen=2+12+4+8+blen+64;
 return 0;
}

int urcsign_verify(unsigned char *p, int plen, unsigned char *pk) {
 if (p[14] != 1) return -1;
 if (plen > URC_MTU) return -1;
 unsigned char sm[1024*2] = {0};
 unsigned char m[1024*2] = {0};
 unsigned long long mlen;
 memmove(sm,p+plen-64,32);
 memmove(sm+32,p,plen-64);
 memmove(sm+32+plen-64,p+plen-32,32);
 return crypto_sign_edwards25519sha512batch_open(m,&mlen,(const unsigned char *)sm,(unsigned long long)plen,(const unsigned char *)pk);
}

int urcsecretbox_fmt(unsigned char *p, int *plen, unsigned char *b, int blen, unsigned char *sk) {
 if (blen > IRC_MTU) return -1;
 int zlen = blen + (256 - blen % 256);
 unsigned char m[1024*2] = {0};
 unsigned char c[1024*2] = {0};
 bzero(m,32+zlen); /* http://nacl.cr.yp.to/secretbox.html */
 bzero(c,16);
 if (setlen(p,zlen+16) == -1) return -1;
 taia96n(p+2);
 p[14]=2;
 p[15]=0;
 p[16]=0;
 p[17]=0;
 randombytes(p+2+12+4,8);
 memmove(m+32,b,blen);
 if (crypto_secretbox(c,m,32+zlen,(const unsigned char *)p+2,(const unsigned char *)sk) == -1) return -1;
 memmove(p+2+12+4+8,c+16,zlen+16);
 *plen=2+12+4+8+zlen+16;
 return 0;
}

int urcsecretbox_open(unsigned char *b, int *blen, unsigned char *p, int plen, unsigned char *sk) {
 if (p[14] != 2) return -1;
 if (plen > URC_MTU) return -1;
 unsigned char m[1024*2] = {0};
 unsigned char c[1024*2] = {0};
 bzero(m,32); /* http://nacl.cr.yp.to/secretbox.html */
 bzero(c,16);
 memmove(c+16,p+2+12+4+8,-2-12-4-8+plen);
 if (crypto_secretbox_open(m,c,16-2-12-4-8+plen,(const unsigned char *)p+2,(const unsigned char *)sk) == -1) return -1;
 memmove(b,m+32,-2-12-4-8+plen-16);
 *blen=-2-12-4-8+plen-16;
 return 0;
}

int urcsignsecretbox_fmt(unsigned char *p, int *plen, unsigned char *b, int blen, unsigned char *ssk, unsigned char *csk) {
 if (blen > IRC_MTU) return -1;
 int zlen = blen + (256 - blen % 256);
 unsigned char sm[1024*2] = {0};
 unsigned char m[1024*2] = {0};
 unsigned char c[1024*2] = {0};
 unsigned long long smlen;
 if (setlen(p,zlen+64+16) == -1) return -1;
 taia96n(p+2);
 p[14]=3;
 p[15]=0;
 p[16]=0;
 p[17]=0;
 randombytes(p+2+12+4,8);
 memmove(p+2+12+4+8,b,blen);
 bzero(p+2+12+4+8+blen,-blen+zlen);
 if (crypto_sign(sm,&smlen,p,2+12+4+8+zlen,ssk) == -1) return -1;
 memmove(p+2+12+4+8+zlen,sm,32);
 memmove(p+2+12+4+8+zlen+32,sm+smlen-32,32);
 bzero(m,32); /* http://nacl.cr.yp.to/secretbox.html */
 bzero(c,16);
 memmove(m+32,p+2+12+4+8,zlen+64);
 if (crypto_secretbox(c,m,32+zlen+64,(const unsigned char *)p+2,(const unsigned char *)csk) == -1) return -1;
 memmove(p+2+12+4+8,c+16,zlen+64+16);
 *plen=2+12+4+8+zlen+64+16;
 return 0;
}

int urcsignsecretbox_open(unsigned char *b, int *blen, unsigned char *p, int plen, unsigned char *sk) {
 if (p[14] != 3) return -1;
 if (plen > URC_MTU) return -1;
 unsigned char m[1024*2] = {0};
 unsigned char c[1024*2] = {0};
 bzero(m,32); /* http://nacl.cr.yp.to/secretbox.html */
 bzero(c,16);
 memmove(c+16,p+2+12+4+8,-2-12-4-8+plen);
 if (crypto_secretbox_open(m,c,16-2-12-4-8+plen,(const unsigned char *)p+2,(const unsigned char *)sk) == -1) return -1;
 memmove(b,p,2+12+4+8);
 memmove(b+2+12+4+8,m+32,-2-12-4-8+plen-16);
 *blen=plen-16;
 return 0;
}

int urcsignsecretbox_verify(unsigned char *p, int plen, unsigned char *pk) {
 if (p[14] != 3) return -1;
 if (plen > URC_MTU) return -1;
 unsigned char sm[1024*2] = {0};
 unsigned char m[1024*2] = {0};
 unsigned long long mlen;
 memmove(sm,p+plen-64,32);
 memmove(sm+32,p,plen-64);
 memmove(sm+32+plen-64,p+plen-32,32);
 return crypto_sign_open(m,&mlen,(const unsigned char *)sm,plen,(const unsigned char *)pk);
}

int urccryptobox_fmt(unsigned char *p, int *plen, unsigned char *b, int blen, unsigned char *pk, unsigned char *sk) {
 if (blen > IRC_MTU) return -1;
 int zlen = blen + (256 - blen % 256);
 unsigned char m[1024*2] = {0};
 unsigned char c[1024*2] = {0};
 bzero(m,32+zlen); /* http://nacl.cr.yp.to/box.html */
 bzero(c,16);
 if (setlen(p,zlen+16) == -1) return -1;
 taia96n(p+2);
 p[14]=4;
 p[15]=0;
 p[16]=0;
 p[17]=0;
 randombytes(p+2+12+4,8);
 memmove(m+32,b,blen);
 if (crypto_box(c,m,32+zlen,(const unsigned char *)p+2,(const unsigned char *)pk,(const unsigned char *)sk) == -1) return -1;
 memmove(p+2+12+4+8,c+16,zlen+16);
 *plen=2+12+4+8+zlen+16;
 return 0;
}

int urccryptobox_open(unsigned char *b, int *blen, unsigned char *p, int plen, unsigned char *pk, unsigned char *sk) {
 if (p[14] != 4) return -1;
 if (plen > URC_MTU) return -1;
 unsigned char m[1024*2] = {0};
 unsigned char c[1024*2] = {0};
 bzero(m,32); /* http://nacl.cr.yp.to/box.html */
 bzero(c,16);
 memmove(c+16,p+2+12+4+8,-2-12-4-8+plen);
 if (crypto_box_open(m,c,16-2-12-4-8+plen,(const unsigned char *)p+2,(const unsigned char *)pk,(const unsigned char *)sk) == -1) return -1;
 memmove(b,m+32,-2-12-4-8+plen-16);
 *blen=-2-12-4-8+plen-16;
 return 0;
}
