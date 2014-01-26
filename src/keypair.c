#include <nacl/crypto_box.h>
int main(){
unsigned char pk [32];
unsigned char sk [32];
          int  i     ;

crypto_box_keypair(pk,sk);

	printf("PUBKEY: ");
	for (i=0;i<32;++i) printf("%02x",pk[i]);
	  printf("\n");

	printf("SECKEY: ");
	for (i=0;i<32;++i) printf("%02x",sk[i]);
	  printf("\n");}
/*
void randombytes(char *bytes) {
	           read(0,bytes,32);}*/
