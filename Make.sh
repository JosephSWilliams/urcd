#!/bin/sh

unset HEADERS
CYTHON=`which cython 2>&1 >/dev/null`
if [ -x $CYTHON ];then
    if [ -e '/usr/include/python2.6/Python.h'       ] &&
       [ -e '/usr/include/python2.6/structmember.h' ] ;then
        HEADERS='/usr/include/python2.6/'
  elif [ -e '/usr/local/include/python2.6/Python.h'       ] &&
       [ -e '/usr/local/include/python2.6/structmember.h' ] ;then
        HEADERS='/usr/local/include/python2.6/'
    fi
fi

if [ -z $HEADERS ]; then
  cp src/urcd.pyx urcd || exit 1
  chmod +x urcd        || exit 1

  cp src/urcrecv.pyx urcrecv || exit 1
  chmod +x urcrecv           || exit 1

  cp src/urcsend.pyx urcsend || exit 1
  chmod +x urcsend           || exit 1

  cp src/urcstream.pyx urcstream || exit 1
  chmod +x urcstream             || exit 1

  exit 0
fi

[ -z $HEADERS ] && exit 1

mkdir -p build || exit 1

cython --embed src/urcd.pyx -o build/urcd.c         || exit 1
gcc -O2 -c build/urcd.c -I $HEADERS -o build/urcd.o || exit 1
gcc -O1 -o urcd build/urcd.o -l python2.6           || exit 1

cython --embed src/urcrecv.pyx -o build/urcrecv.c         || exit 1
gcc -O2 -c build/urcrecv.c -I $HEADERS -o build/urcrecv.o || exit 1
gcc -O1 -o urcrecv build/urcrecv.o -l python2.6           || exit 1

cython --embed src/urcsend.pyx -o build/urcsend.c         || exit 1
gcc -O2 -c build/urcsend.c -I $HEADERS -o build/urcsend.o || exit 1
gcc -O1 -o urcsend build/urcsend.o -l python2.6           || exit 1

cython --embed src/urcstream.pyx -o build/urcstream.c         || exit 1
gcc -O2 -c build/urcstream.c -I $HEADERS -o build/urcstream.o || exit 1
gcc -O1 -o urcstream build/urcstream.o -l python2.6           || exit 1

rm -rf build || exit 1
