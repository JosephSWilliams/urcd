#!/bin/sh -v

if [ -e '/usr/lib/libnacl.so' ]; then
  echo $0': fatal error: move /usr/lib/libnacl.so temporarily' 1>&2
  exit 255
fi

touch conf-cc
unset HEADERS

if   [ -e '/usr/include/python2.7/Python.h'       ] &&
     [ -e '/usr/include/python2.7/structmember.h' ] ;then
       HEADERS='/usr/include/python2.7'

elif [ -e '/usr/local/include/python2.7/Python.h'       ] &&
     [ -e '/usr/local/include/python2.7/structmember.h' ] ;then
       HEADERS='/usr/local/include/python2.7'
fi

# OpenBSD \o/
export LIBRARY_PATH="/usr/local/lib:$LIBRARY_PATH"
export LIBRARY_PATH="/usr/local/include:$LIBRARY_PATH"
if [ -e /usr/local/lib/randombytes.o ]; then
 randombytes=/usr/local/lib/randombytes.o
else
 randombytes=/usr/lib/randombytes.o
fi

gcc `cat conf-cc` src/urcsend.c -o urcsend || exit 1

gcc `cat conf-cc` src/urcrecv.c -o urcrecv || exit 1

gcc `cat conf-cc` src/urcstream.c -o urcstream || exit 1

gcc `cat conf-cc` src/ucspi-stream.c -o ucspi-stream || exit 1

gcc `cat conf-cc` src/urchub.c -o urchub || exit 1

gcc `cat conf-cc` src/urchubstream.c -o urchubstream || exit 1

gcc `cat conf-cc` src/urcstream2hub.c -o urcstream2hub -l tai || exit 1

gcc `cat conf-cc` src/ucspi-client2server.c -o ucspi-client2server || exit 1

gcc `cat conf-cc` src/ucspi-server2client.c -o ucspi-server2client || exit 1

gcc `cat conf-cc` src/ucspi-socks4aclient.c -o ucspi-socks4aclient || exit 1

gcc `cat conf-cc` src/keypair.c -o keypair -l nacl $randombytes || exit 1

gcc `cat conf-cc` src/sign_keypair.c -o sign_keypair -l nacl $randombytes || exit 1

gcc -O2 -fPIC -DPIC src/nacltaia.c -shared -I $HEADERS -o nacltaia.so -l python2.7 -l tai -l nacl $randombytes || exit 1

gcc `cat conf-cc` src/check-taia.c -o check-taia -l tai -l nacl || exit 1

if ! $(./check-taia >/dev/null) ; then
  gcc `cat conf-cc` src/urccache-failover.c -o urccache -l nacl || exit 1
else
  gcc `cat conf-cc` src/urccache.c -o urccache -l tai -l nacl $randombytes || exit 1
  printf '' | ./urccache `pwd`/src/
  if [ $? != 1 ] ; then gcc `cat conf-cc` src/urccache-failover.c -o urccache -l nacl || exit 1 ; fi
fi

if ! which cython 2>/dev/null ; then
  cp src/urcd.pyx urcd || exit 1
  chmod +x urcd        || exit 1

  cp src/urc2sd.pyx urc2sd || exit 1
  chmod +x urc2sd          || exit 1

  #cp src/urcrecv.pyx urcrecv || exit 1
  #chmod +x urcrecv           || exit 1

  #cp src/urcsend.pyx urcsend || exit 1
  #chmod +x urcsend           || exit 1

  #cp src/urcstream.pyx urcstream || exit 1
  #chmod +x urcstream             || exit 1

  exit 0
fi

[ -z $HEADERS ] && exit 1

mkdir -p build || exit 1

cython --embed src/urcd.pyx -o build/urcd.c         || exit 1
gcc `cat conf-cc` -O2 -c build/urcd.c -I $HEADERS -o build/urcd.o || exit 1
gcc `cat conf-cc` -O1 -o urcd build/urcd.o -l python2.7           || exit 1

cython --embed src/urc2sd.pyx -o build/urc2sd.c         || exit 1
gcc `cat conf-cc` -O2 -c build/urc2sd.c -I $HEADERS -o build/urc2sd.o || exit 1
gcc `cat conf-cc` -O1 -o urc2sd build/urc2sd.o -l python2.7           || exit 1

#cython --embed src/urcrecv.pyx -o build/urcrecv.c         || exit 1
#gcc `cat conf-cc` -O2 -c build/urcrecv.c -I $HEADERS -o build/urcrecv.o || exit 1
#gcc `cat conf-cc` -O1 -o urcrecv build/urcrecv.o -l python2.7           || exit 1

#cython --embed src/urcsend.pyx -o build/urcsend.c         || exit 1
#gcc `cat conf-cc` -O2 -c build/urcsend.c -I $HEADERS -o build/urcsend.o || exit 1
#gcc `cat conf-cc` -O1 -o urcsend build/urcsend.o -l python2.7           || exit 1

#cython --embed src/urcstream.pyx -o build/urcstream.c         || exit 1
#gcc `cat conf-cc` -O2 -c build/urcstream.c -I $HEADERS -o build/urcstream.o || exit 1
#gcc `cat conf-cc` -O1 -o urcstream build/urcstream.o -l python2.7           || exit 1

rm -rf build || exit 1
