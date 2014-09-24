#include <nacl/crypto_scalarmult_curve25519.h>
#include <nacl/crypto_hash_sha512.h>
#include <nacl/crypto_verify_32.h>
#include <nacl/crypto_sign.h>
#include <nacl/crypto_box.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <strings.h>
#include <dirent.h>
#include <unistd.h>
#include <sys/un.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <pwd.h>

#include "base16.h"

#define USAGE "./cryptoserv /path/to/sockets/ /path/to/root/\n"

#ifndef UNIX_PATH_MAX
 #ifdef __NetBSD__
  #define UNIX_PATH_MAX 104
 #else
  #define UNIX_PATH_MAX 108
 #endif
#endif

int itoa(char *s, int n, int slen)
{
 if (snprintf(s,slen,"%d",n)<0) return -1;
 return 0;
}

void randombytes(char *bytes) {} // override: hack crypto_*_keypair functions

void lower(
 unsigned char *buffer0,
 unsigned char *buffer1,
 int buffer1_len
) {
 int i;
 for(i=0;i<buffer1_len;++i) {
  if ((buffer1[i]>64)&&(buffer1[i]<91)) {
   buffer0[i] = buffer1[i] + 32;
  }
  else buffer0[i] = buffer1[i];
 }
}

main(int argc, char *argv[])
{

 if (argc<3) {
  write(2,USAGE,strlen(USAGE));
  exit(1);
 }

 struct passwd *urcd = getpwnam("urcd"); 
 struct sockaddr_un s;
 struct dirent *file;
 struct stat stats;

 DIR *directory;

 unsigned char buffer3[1024*2] = {0};
 unsigned char buffer2[1024*2] = {0};
 unsigned char buffer1[1024*2] = {0};
 unsigned char buffer0[1024*2] = {0};
 unsigned char identifiednick[256];
 unsigned char path[512];
 unsigned char hex[192];
 unsigned char pk0[32];
 unsigned char pk1[32];
 unsigned char sk[64];

 float LIMIT;

 long starttime;
 long EXPIRY;

 int i = strlen(argv[1]);
 int identifiednicklen;
 int identified = 0;
 int informed = 0;
 int nicklen = 0;
 int sfd = -1;
 int NICKLEN;
 int fd;

 fd = open("env/LIMIT",0);
 if (fd>0)
 {
   if (read(fd,buffer0,1024)>0) LIMIT = atof(buffer0);
   else LIMIT = 1.0;
 } else LIMIT = 1.0;
 close(fd);

 bzero(buffer0,1024);

 fd = open("env/EXPIRY",0);
 if (fd>0)
 {
   if (read(fd,buffer0,1024)>0) EXPIRY = atol(buffer0) * 24L * 60L * 60L;
   else EXPIRY = 32L * 24L * 60L * 60L;
 } else EXPIRY = 32L * 24L * 60L * 60L;
 close(fd);

 fd = open("env/NICKLEN",0);
 if (fd>0)
 {
   if (read(fd,buffer0,1024)>0) NICKLEN = atoi(buffer0) & 255;
   else NICKLEN = 32;
 } else NICKLEN = 32;
 close(fd);

 bzero(&s,sizeof(s));
 s.sun_family = AF_UNIX;
 memcpy(s.sun_path,argv[1],i); /* contains potential overflow */

 if (((sfd=socket(AF_UNIX,SOCK_DGRAM,0))<0)
 || (itoa(s.sun_path+i,getppid(),UNIX_PATH_MAX-i)<0)
 || (connect(sfd,(struct sockaddr *)&s,sizeof(s))<0)
 || (setsockopt(sfd,SOL_SOCKET,SO_REUSEADDR,&i,sizeof(i))<0))
 {
  write(2,USAGE,strlen(USAGE));
  exit(2);
 }

 if ((!urcd)
 || (chdir(argv[2]))
 || (chroot(argv[2]))
 || (setgroups(0,'\x00'))
 || (setgid(urcd->pw_gid))
 || (setuid(urcd->pw_uid)))
 {
  write(2,USAGE,strlen(USAGE));
  exit(3);
 }

 starttime = time((long *)0);

 fcntl(0,F_SETFL,fcntl(0,F_GETFL,0)&~O_NONBLOCK);

 memcpy(buffer2+2+12+4+8,":CryptoServ!URCD@service NOTICE ",32);

 if (EXPIRY) {
  memcpy(path,"urcsigndb/",10); 
  if (!(directory=opendir("urcsigndb/"))) exit(4);
  while ((file=readdir(directory)))
  {
    if (file->d_name[0] == '.') continue;
    bzero(path+10,-10+512);
    memcpy(path+10,file->d_name,strlen(file->d_name));
    stat(path,(struct stat *)&stats);
    if (time((long *)0) - stats.st_atime >= EXPIRY) remove(path);
  } closedir(directory);

  memcpy(path,"urccryptoboxdir/",16); 
  if (!(directory=opendir("urccryptoboxdir/"))) exit(5);
  while ((file=readdir(directory)))
  {
    if (file->d_name[0] == '.') continue;
    bzero(path+16,-16+512);
    memcpy(path+16,file->d_name,strlen(file->d_name));
    stat(path,(struct stat *)&stats);
    if (time((long *)0) - stats.st_atime >= EXPIRY) remove(path);
  } closedir(directory);
 }

 while (1)
 {

  for (i=0;i<1024;++i)
  {
    if (read(0,buffer0+i,1)<1) exit(6);
    if (buffer0[i] == '\r') --i;
    if (buffer0[i] == '\n') break;
  } if (buffer0[i] != '\n') continue;
  ++i;

  lower(buffer1,buffer0,i);

  /// NICK
  if ((i>=7)&&(!memcmp("nick ",buffer1,5))) { /* not reliable */
   nicklen=-5+i-1;
   if (nicklen<=NICKLEN) {
    memcpy(buffer2+2+12+4+8+32,buffer1+5,nicklen);
    memcpy(buffer2+2+12+4+8+32+nicklen," :",2);
   }
   else nicklen = 0;
  } else if (nicklen) {
   if ((i>=20)&&(!memcmp("privmsg cryptoserv :",buffer1,20))) {

    usleep((int)(LIMIT*1000000));

    /// IDENTIFY
    if ((i>=20+9+1+1)&&(!memcmp("identify ",buffer1+20,9))) {
     bzero(path,512);
     memcpy(path,"urcsigndb/",10);
     memcpy(path+10,buffer2+2+12+4+8+32,nicklen);
     if (((fd=open(path,O_RDONLY))<0) || (read(fd,hex,64)<64) || (base16_decode(pk0,hex,64)<32)) {
      memcpy(buffer2+2+12+4+8+32+nicklen+2,"Account does not exist.\n",24);
      write(sfd,buffer2,2+12+4+8+32+nicklen+2+24);
      close(fd);
      continue;
     }close(fd);
     memcpy(buffer3,buffer0+20+9,-20-9+i-1);
     memcpy(buffer3-20-9+i-1,buffer2+2+12+4+8+32,nicklen);
     crypto_hash_sha512(sk,buffer3,-20-9+i-1+nicklen);
     crypto_sign_keypair(pk1,sk);
     if (memcmp(pk0,pk1,32)) {
      memcpy(buffer2+2+12+4+8+32+nicklen+2,"Invalid passwd.\n",16);
      write(sfd,buffer2,2+12+4+8+32+nicklen+2+16);
      continue;
     }
     bzero(path,512);
     memcpy(path,"urccryptoboxdir/",16);
     memcpy(path+16,buffer2+2+12+4+8+32,nicklen);
     if (((fd=open(path,O_RDONLY))<0) || (read(fd,hex,64)<64) || (base16_decode(pk0,hex,64)<32)) {
      memcpy(buffer2+2+12+4+8+32+nicklen+2,"Account does not exist.\n",24);
      write(sfd,buffer2,2+12+4+8+32+nicklen+2+24);
      close(fd);
      continue;
     }close(fd);
     crypto_scalarmult_curve25519_base(pk1,sk);
     if (memcmp(pk0,pk1,32)) {
      memcpy(buffer2+2+12+4+8+32+nicklen+2,"Invalid passwd.\n",16);
      write(sfd,buffer2,2+12+4+8+32+nicklen+2+16);
      continue;
     }
     base16_encode(hex,sk,32);
     base16_encode(hex+64,sk,64);
     memcpy(buffer0,"PASS ",5);
     memcpy(buffer0+5,hex,192);
     memcpy(buffer0+5+192,"\n",1);
     if (write(1,buffer0,5+192+1)<=0) exit(7);
     memcpy(buffer2+2+12+4+8+32+nicklen+2,"Success\n",8);
     write(sfd,buffer2,2+12+4+8+32+nicklen+2+8);
     memcpy(identifiednick,buffer2+2+12+4+8+32,nicklen);
     identifiednicklen = nicklen;
     identified = 1;
     continue;
    }

    /// REGISTER
    if ((i>=20+9+1+1)&&(!memcmp("register ",buffer1+20,9))) {
     if ((identified) || (time((long *)0)-starttime<128)) goto HELP;
     memcpy(buffer3,buffer0+20+9,-20-9+i-1);
     memcpy(buffer3-20-9+i-1,buffer2+2+12+4+8+32,nicklen);
     crypto_hash_sha512(sk,buffer3,-20-9+i-1+nicklen);
     REGISTER:
      crypto_sign_keypair(pk0,sk);
      bzero(path,512);
      memcpy(path,"urcsigndb/",10);
      if (identified) memcpy(path+10,identifiednick,identifiednicklen);
      else memcpy(path+10,buffer2+2+12+4+8+32,nicklen);
      if (!access(path,F_OK)) {
       memcpy(buffer2+2+12+4+8+32+nicklen+2,"Account already exists.\n",24);
       write(sfd,buffer2,2+12+4+8+32+nicklen+2+24);
       continue;
      }
      if (((fd=open(path,O_CREAT|O_WRONLY))<0) || (fchmod(fd,S_IRUSR|S_IWUSR))<0) {
       memcpy(buffer2+2+12+4+8+32+nicklen+2,"Failure\n",8);
       write(sfd,buffer2,2+12+4+8+32+nicklen+2+8);
       close(fd);
       continue;
      }
      base16_encode(hex,pk0,32);
      if (write(fd,hex,64)<64) exit(8);
      close(fd);
      crypto_scalarmult_curve25519_base(pk0,sk);
      bzero(path,512);
      memcpy(path,"urccryptoboxdir/",16);
      if (identified) memcpy(path+16,identifiednick,identifiednicklen);
      else memcpy(path+16,buffer2+2+12+4+8+32,nicklen);
      if (((fd=open(path,O_CREAT|O_WRONLY))<0) || (fchmod(fd,S_IRUSR|S_IWUSR))<0) {
       memcpy(buffer2+2+12+4+8+32+nicklen+2,"Failure\n",8);
       write(sfd,buffer2,2+12+4+8+32+nicklen+2+8);
       close(fd);
       continue;
      }
      base16_encode(hex,pk0,32);
      if (write(fd,hex,64)<64) exit(9);
      close(fd);
      base16_encode(hex,sk,32);
      base16_encode(hex+64,sk,64);
      memcpy(buffer0,"PASS ",5);
      memcpy(buffer0+5,hex,192);
      memcpy(buffer0+5+192,"\n",1);
      if (write(1,buffer0,5+192+1)<=0) exit(10);
      memcpy(buffer2+2+12+4+8+32+nicklen+2,"Success\n",8);
      write(sfd,buffer2,2+12+4+8+32+nicklen+2+8);
      if (!identified) {
       memcpy(identifiednick,buffer2+2+12+4+8+32,nicklen);
       identifiednicklen = nicklen;
       identified = 1;
      }
     continue;
    }

    /// SET PASSWORD
    if ((i>=20+13+1+1)&&(!memcmp("set password ",buffer1+20,13))) {
     if (!identified) goto HELP;
     memcpy(buffer3,buffer0+20+9,-20-9+i-1);
     memcpy(buffer3-20-9+i-1,identifiednick,nicklen);
     crypto_hash_sha512(sk,buffer3,-20-9+i-1+nicklen);
     goto REGISTER;
    }

    /// SET PFS
    if ((i>=20+8+2+1)&&(!memcmp("set pfs ",buffer1+20,8))) {
     if (!identified) {
      memcpy(buffer2+2+12+4+8+32+nicklen+2,"You are not identified.\n",24);
      write(sfd,buffer2,2+12+4+8+32+nicklen+2+24);
      continue;
     }
     bzero(path,512);
     memcpy(path,"urccryptoboxpfs/",16);
     memcpy(path+16,identifiednick,identifiednicklen);
     if ((i>=20+8+3+1)&&(!memcmp("off",buffer1+20+8,3))) {
      if (remove(path)<0) {
       memcpy(buffer2+2+12+4+8+32+nicklen+2,"Failure\n",8);
       write(sfd,buffer2,2+12+4+8+32+nicklen+2+8);
       continue;
      }
     } else if ((i>=20+8+2+1)&&(!memcmp("on",buffer1+20+8,2))) {
      if ((fd=open(path,O_CREAT))<0) {
       memcpy(buffer2+2+12+4+8+32+nicklen+2,"Failure\n",8);
       write(sfd,buffer2,2+12+4+8+32+nicklen+2+8);
       close(fd);
       continue;
      }close(fd);
     } else {
      memcpy(buffer2+2+12+4+8+32+nicklen+2,"Invalid option.\n",16);
      write(sfd,buffer2,2+12+4+8+32+nicklen+2+16);
      continue;
     }
     memcpy(buffer2+2+12+4+8+32+nicklen+2,"Success\n",8);
     write(sfd,buffer2,2+12+4+8+32+nicklen+2+8);
     continue;
    }

    /// DROP
    if ((i>=20+4)&&(!memcmp("drop",buffer1+20,4))) {
     if (!identified) goto HELP;
     bzero(path,512);
     memcpy(path,"urccryptoboxdir/",16);
     memcpy(path+16,identifiednick,identifiednicklen);
     if (remove(path)<0) {
      memcpy(buffer2+2+12+4+8+32+nicklen+2,"Failure\n",8);
      write(sfd,buffer2,2+12+4+8+32+nicklen+2+8);
     }
     bzero(path,512);
     memcpy(path,"urcsigndb/",10);
     memcpy(path+10,identifiednick,identifiednicklen);
     if (remove(path)<0) {
      memcpy(buffer2+2+12+4+8+32+nicklen+2,"Failure\n",8);
      write(sfd,buffer2,2+12+4+8+32+nicklen+2+8);
      continue;
     }
     memcpy(buffer0,"PASS ",5);
     memcpy(buffer0+5+192,"\n",1);
     for (i=0;i<192;++i) buffer0[5+i]='0';
     if (write(1,buffer0,5+192+1)<=0) exit(11);
     memcpy(buffer2+2+12+4+8+32+nicklen+2,"Success\n",8);
     write(sfd,buffer2,2+12+4+8+32+nicklen+2+8);
     starttime = time((long *)0);
     identified = 0;
     continue;
    }

    /// LOGOUT
    if ((i>=20+6)&&(!memcmp("logout",buffer1+20,6))) {
     if (!identified) {
      memcpy(buffer2+2+12+4+8+32+nicklen+2,"You are not identified.\n",24);
      write(sfd,buffer2,2+12+4+8+32+nicklen+2+24);
      continue;
     }
     memcpy(buffer0,"PASS ",5);
     memcpy(buffer0+5+192,"\n",1);
     for (i=0;i<192;++i) buffer0[5+i]='0';
     if (write(1,buffer0,5+192+1)<=0) exit(12);
     memcpy(buffer2+2+12+4+8+32+nicklen+2,"Success\n",8);
     write(sfd,buffer2,2+12+4+8+32+nicklen+2+8);
     starttime = time((long *)0);
     identified = 0;
     continue;
    }

    /// HELP
    if ((i>=20+4)&&(!memcmp("help",buffer1+20,4))) {
     HELP:
      informed = 1;
      memcpy(buffer2+2+12+4+8+32+nicklen+2,"The following commands will most likely take effect when you and/or your peers /reconnect:\n",91);
      write(sfd,buffer2,2+12+4+8+32+nicklen+2+91);
      memcpy(buffer2+2+12+4+8+32+nicklen+2,"`REGISTER <passwd>' after 128 seconds to create an account.\n",60);
      write(sfd,buffer2,2+12+4+8+32+nicklen+2+60);
      memcpy(buffer2+2+12+4+8+32+nicklen+2,"`IDENTIFY <passwd>' to login to your account and activate URCSIGN and URCCRYPTOBOX.\n",84);
      write(sfd,buffer2,2+12+4+8+32+nicklen+2+84);
      memcpy(buffer2+2+12+4+8+32+nicklen+2,"`SET PASSWORD <passwd>' changes your password after you REGISTER/IDENTIFY.\n",75);
      write(sfd,buffer2,2+12+4+8+32+nicklen+2+75);
      memcpy(buffer2+2+12+4+8+32+nicklen+2,"`SET PFS <ON, OFF>' toggles perfect forward secrecy for PM.\n",60);
      write(sfd,buffer2,2+12+4+8+32+nicklen+2+60);
      memcpy(buffer2+2+12+4+8+32+nicklen+2,"`DROP' removes your account after you REGISTER/IDENTIFY.\n",57);
      write(sfd,buffer2,2+12+4+8+32+nicklen+2+57);
      memcpy(buffer2+2+12+4+8+32+nicklen+2,"`LOGOUT' deactivates URCSIGN and URCCRYPTOBOX.\n",47);
      write(sfd,buffer2,2+12+4+8+32+nicklen+2+47);
    }

    if (!informed) goto HELP;
    continue;
   }
  }
 if (write(1,buffer0,i)<=0) exit(13);
 }
}
