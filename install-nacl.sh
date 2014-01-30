#!/bin/sh
# Workaround script for creating shared objects on 64-bit
# architectures with NaCl. Much thanks to Ivo Smits for
# doing a lot of the work. Thanks to SeekingFor, some
# strange anonymous type person, for OpenBSD support.

if which wget 2>/dev/null 1>&2; then
  retr=wget
elif which curl 2>/dev/null 1>&2; then
  retr="curl -O"
elif which ftp 2>/dev/null 1>&2; then
  retr=ftp
else
  echo "could not find any appropiate way to download sources, no wget, curl or ftp in PATH";
  exit 1;
fi
rm -rf nacl-20110221
[ -f nacl-20110221.tar.bz2 ] || $retr http://hyperelliptic.org/nacl/nacl-20110221.tar.bz2
bunzip2 < nacl-20110221.tar.bz2 | tar -xf -

# Use my patched copy of curvecpserver.c
# sets env $CURVECPCLIENTPUBKEY from a curvecpclient
# clientlongtermpk for programs to check client authentication.
# I hope we'll see this in the main distribution. ucspi-tcp
# style environment variables with *.cdb rules would be nice :-)
# (I replaced all the \tabs with 2 spaces, eww tab)
cat src/curvecpserver.c > nacl-20110221/curvecp/curvecpserver.c

# Use my patched copy of socket_bind.c
# if AF_UNSPEC fails then try using AF_INET
cat src/socket_bind.c > nacl-20110221/curvecp/socket_bind.c

cd nacl-20110221

# ./do will compile an alternative MAC implementation
# that works with shared objects.
rm -r crypto_onetimeauth/poly1305/amd64

# android patch
echo 'gcc' >> okcompilers/c

# patch the library for making shared objects on 64 bit
# architectures by compiling with PIC.
if ! sed -i "s/$/ -fPIC/" okcompilers/c 2>/dev/null; then
  sed "s/$/ -fPIC/" okcompilers/c > okcompilers/c{new}
  mv okcompilers/c{new} okcompilers/c
fi
echo "Starting to compile and benchmark NaCl so it will use the best available implementations for your specific hardware. This might take some time."
./do

gcc okcompilers/abiname.c -o abiname
ABINAME="$(./abiname "" | cut -b 2-)"
BUILDDIR="build/$(hostname | sed 's/\..*//' | tr -cd '[a-z][A-Z][0-9]')"

# install nacl/build in meaningful directories
mkdir -p /usr/include/nacl
cp -i "${BUILDDIR}/bin/"* /usr/bin/
cp -i "${BUILDDIR}/lib/${ABINAME}/"* /usr/lib/
cp -i "${BUILDDIR}/include/${ABINAME}/"* /usr/include/nacl/
