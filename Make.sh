#!/bin/sh -v

if ! su urcd -c exit 0 ; then
 useradd urcd
fi

if [ -e '/usr/lib/libnacl.so' ]; then
 echo $0': fatal error: move /usr/lib/libnacl.so temporarily' 1>&2
 exit 255
fi

touch conf-cc

if ! which python-config; then
 if ! which python2.7-config; then
  echo $0': fatal error: no suitable python development files exist' 1>&2
  exit 255
 fi
 python_config=python2.7-config
else python_config=python-config
fi

PYTHON_INCLUDE=`$python_config --includes` || exit 1
PYTHON_LIBRARY=`$python_config --libs` || exit 1

# OpenBSD && NetBSD \o/
export CPATH="/usr/pkg/include:/usr/local/include:$CPATH"
export LIBRARY_PATH="/usr/pkg/lib:/usr/local/lib:$LIBRARY_PATH"

# Support libsodium fanboys
if gcc src/check-nacl.h -o /dev/null 2>/dev/null ; then
 src='src'
 nacl='nacl'
 test -e /usr/lib/randombytes.o && \
  randombytes=/usr/lib/randombytes.o
 test -e /usr/pkg/lib/randombytes.o && \
  randombytes=/usr/pkg/lib/randombytes.o
 test -e /usr/local/lib/randombytes.o && \
  randombytes=/usr/local/lib/randombytes.o
 if [ -z $randombytes ]; then
  echo $0': fatal error: randombytes.o not found' 1>&2
  exit 255
 fi
elif gcc src/check-sodium.h -o /dev/null 2>/dev/null ; then
 src='libsodium_src'
 nacl='sodium'
 rm -rf $src
 mkdir -p $src
 ### *BSD's sed doesn't have -i ###
 for i in `ls src/` ; do
  sed 's|#include <nacl/|#include <sodium/|g' src/$i > $src/$i
 done
else
  echo $0': fatal error: no suitable NaCl library exists' 1>&2
  exit 255
fi

gcc `cat conf-cc` $src/urchub.c -o urchub || exit 1
gcc `cat conf-cc` $src/urc-udpsend.c -o urc-udpsend || exit 1
gcc `cat conf-cc` $src/urc-udprecv.c -o urc-udprecv || exit 1
gcc `cat conf-cc` $src/ucspi-stream.c -o ucspi-stream || exit 1
gcc `cat conf-cc` $src/urchubstream.c -o urchubstream || exit 1
gcc `cat conf-cc` $src/cryptoserv.c -o cryptoserv -l $nacl || exit 1
gcc `cat conf-cc` $src/urcstream2hub.c -o urcstream2hub -l tai || exit 1
gcc `cat conf-cc` $src/check-taia.c -o check-taia -l tai -l $nacl || exit 1
gcc `cat conf-cc` $src/ucspi-client2server.c -o ucspi-client2server || exit 1
gcc `cat conf-cc` $src/ucspi-server2client.c -o ucspi-server2client || exit 1
gcc `cat conf-cc` $src/ucspi-socks4aclient.c -o ucspi-socks4aclient || exit 1
gcc `cat conf-cc` $src/keypair.c -o keypair -l $nacl $randombytes || exit 1
gcc `cat conf-cc` $src/sign_keypair.c -o sign_keypair -l $nacl $randombytes || exit 1

gcc -O2 -fPIC -DPIC $src/liburc.c -shared $PYTHON_INCLUDE -o liburc.so $PYTHON_LIBRARY -l tai -l $nacl || exit 1

gcc -O2 -fPIC -DPIC $src/nacltaia.c -shared $PYTHON_INCLUDE -o nacltaia.so $PYTHON_LIBRARY -l tai -l $nacl $randombytes || exit 1

if ! $(./check-taia >/dev/null) ; then
 echo $0': fatal error: (security) potential cache error 00' 1>&2
 exit 255
else
 gcc `cat conf-cc` $src/urccache.c -o urccache -l tai -l $nacl $randombytes || exit 1
 printf '' | ./urccache `pwd`/$src/
 if [ $? != 1 ] ; then
  echo $0': fatal error: (security) potential cache error 01' 1>&2
  exit 255
 fi
fi

if ! which cython 2>/dev/null ; then
 cp $src/urcd.pyx urcd || exit 1
 chmod +x urcd || exit 1
 cp $src/urc2sd.pyx urc2sd || exit 1
 chmod +x urc2sd || exit 1
 cp $src/taia96n.pyx taia96n.py || exit 1
 rm -rf libsodium_src
 exit 0 
fi

mkdir -p build || exit 1

cython --embed $src/urcd.pyx -o build/urcd.c || exit 1
gcc `cat conf-cc` -O2 -c build/urcd.c $PYTHON_INCLUDE -o build/urcd.o || exit 1
gcc `cat conf-cc` -O1 -o urcd build/urcd.o $PYTHON_LIBRARY || exit 1

cython --embed $src/urc2sd.pyx -o build/urc2sd.c || exit 1
gcc `cat conf-cc` -O2 -c build/urc2sd.c $PYTHON_INCLUDE -o build/urc2sd.o || exit 1
gcc `cat conf-cc` -O1 -o urc2sd build/urc2sd.o $PYTHON_LIBRARY || exit 1

cython $src/taia96n.pyx -o build/taia96n.c || exit 1
gcc `cat conf-cc` -O2 -shared -pthread -fPIC -fwrapv -Wall \
 -fno-strict-aliasing $PYTHON_INCLUDE build/taia96n.c -o taia96n.so || exit 1

rm -rf build libsodium_src || exit 1
