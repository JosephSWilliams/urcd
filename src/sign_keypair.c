#include <nacl/crypto_sign.h>
#include <stdio.h>

int main(){
unsigned char pk [32];
unsigned char sk [64];
          int  i     ;

crypto_sign_keypair(pk,sk);

	printf("PUBKEY: ");
	for (i=0;i<32;++i) printf("%02x",pk[i]);
	  printf("\n");

	printf("SECKEY: ");
	for (i=0;i<64;++i) printf("%02x",sk[i]);
	  printf("\n");}
/*
void randombytes(char *bytes) {
	           read(0,bytes,64);}*/
