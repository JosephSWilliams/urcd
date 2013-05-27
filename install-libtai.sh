#!/bin/sh
# Workaround script for creating shared objects on 64-bit
# architectures with libtai.

wget http://cr.yp.to/libtai/libtai-0.60.tar.gz -O- | tar xzf -

cd libtai-0.60

sed 's/$/ -fPIC/' conf-* -i

make

cp libtai.a /usr/lib/libtai.a
cp *.h /usr/include/
cp leapsecs.dat /etc/leapsecs.dat
