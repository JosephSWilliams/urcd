#!/bin/sh

if which wget 2>/dev/null 1>&2; then
  retr=wget
elif which curl 2>/dev/null 1>&2; then
  retr="curl -O"
elif which ftp 2>/dev/null 1>&2; then
  retr="ftp"
else
  echo "could not find any appropiate way to download sources, no wget, curl or ftp in PATH";
  exit 1;
fi

$retr http://cr.yp.to/ucspi-tcp/ucspi-tcp-0.88.tar.gz
gunzip ucspi-tcp-0.88.tar
tar -xf ucspi-tcp-0.88.tar
cd ucspi-tcp-0.88/
sed -i 's/^gcc/gcc -include errno.h/' conf-cc
make
make setup check
