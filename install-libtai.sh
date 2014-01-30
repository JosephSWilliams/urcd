#!/bin/sh
# Workaround script for creating shared objects on 64-bit
# architectures with libtai.

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

rm -rf libtai-0.60
[ -f libtai-0.60.tar.gz ] || $retr http://cr.yp.to/libtai/libtai-0.60.tar.gz
tar xzf libtai-0.60.tar.gz

cd libtai-0.60

if ! sed -i 's/$/ -fPIC/' conf-* 2>/dev/null; then
  for item in $(ls conf-*); do
    sed 's/$/ -fPIC/' $item > $item{new}
    mv $item{new} $item
  done
fi

make

cp libtai.a /usr/lib/libtai.a
cp *.h /usr/include/
cp leapsecs.dat /etc/leapsecs.dat
