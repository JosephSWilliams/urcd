#!/bin/sh -v

if [ -e '/usr/lib/libnacl.so' ]; then
  echo $0': fatal error: move /usr/lib/libnacl.so temporarily' 1>&2
  exit 255
fi

unset HEADERS

if   [ -e '/usr/include/python2.6/Python.h'       ] &&
     [ -e '/usr/include/python2.6/structmember.h' ] ;then
       HEADERS='/usr/include/python2.6'

elif [ -e '/usr/local/include/python2.6/Python.h'       ] &&
     [ -e '/usr/local/include/python2.6/structmember.h' ] ;then
       HEADERS='/usr/local/include/python2.6'
fi

gcc src/urcsend.c -o urcsend || exit 1

gcc src/urcrecv.c -o urcrecv || exit 1

gcc src/urcstream.c -o urcstream || exit 1

gcc src/ucspi-stream.c -o ucspi-stream || exit 1

gcc src/urchub.c -o urchub || exit 1

gcc src/urchubstream.c -o urchubstream || exit 1

gcc src/urcstream2hub.c -o urcstream2hub -l tai || exit 1

gcc src/ucspi-client2server.c -o ucspi-client2server || exit 1

gcc src/ucspi-server2client.c -o ucspi-server2client || exit 1

gcc src/ucspi-socks4aclient.c -o ucspi-socks4aclient || exit 1


gcc src/check-taia.c -o check-taia -l tai -l nacl || exit 1

if ! $(./check-taia >/dev/null) ; then
  gcc src/urccache-static.c -o urccache -l nacl || exit 1
else
  gcc src/urccache.c -o urccache -l tai -l nacl /usr/lib/randombytes.o || exit 1
  printf '' | ./urccache `pwd`/src/
  if [ $? != 1 ] ; then gcc src/urccache-static.c -o urccache -l nacl || exit 1 ; fi
fi

if ! $(which cython 2>&1 >/dev/null); then
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
gcc -O2 -c build/urcd.c -I $HEADERS -o build/urcd.o || exit 1
gcc -O1 -o urcd build/urcd.o -l python2.6           || exit 1

cython --embed src/urc2sd.pyx -o build/urc2sd.c         || exit 1
gcc -O2 -c build/urc2sd.c -I $HEADERS -o build/urc2sd.o || exit 1
gcc -O1 -o urc2sd build/urc2sd.o -l python2.6           || exit 1

#cython --embed src/urcrecv.pyx -o build/urcrecv.c         || exit 1
#gcc -O2 -c build/urcrecv.c -I $HEADERS -o build/urcrecv.o || exit 1
#gcc -O1 -o urcrecv build/urcrecv.o -l python2.6           || exit 1

#cython --embed src/urcsend.pyx -o build/urcsend.c         || exit 1
#gcc -O2 -c build/urcsend.c -I $HEADERS -o build/urcsend.o || exit 1
#gcc -O1 -o urcsend build/urcsend.o -l python2.6           || exit 1

#cython --embed src/urcstream.pyx -o build/urcstream.c         || exit 1
#gcc -O2 -c build/urcstream.c -I $HEADERS -o build/urcstream.o || exit 1
#gcc -O1 -o urcstream build/urcstream.o -l python2.6           || exit 1

rm -rf build || exit 1
