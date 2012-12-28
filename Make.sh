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
  chmod +x urcd         || exit 1
  exit 0
fi

[ -z $HEADERS ] && exit 1

mkdir -p build || exit 1

cython --embed src/urcd.pyx -o build/urcd.c         || exit 1
gcc -O2 -c build/urcd.c -I $HEADERS -o build/urcd.o || exit 1
gcc -O1 -o urcd build/urcd.o -l python2.6           || exit 1

rm -rf build || exit 1
