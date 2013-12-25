#!/bin/sh
wget http://cr.yp.to/ucspi-tcp/ucspi-tcp-0.88.tar.gz
gunzip ucspi-tcp-0.88.tar
tar -xf ucspi-tcp-0.88.tar
cd ucspi-tcp-0.88/
sed -i 's/^gcc/gcc -include errno.h/' conf-cc
make
make setup check
