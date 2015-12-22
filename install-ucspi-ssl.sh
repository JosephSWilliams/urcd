#!/bin/sh

### is this really necessary? ###
mkdir -p /package
chmod 1755 /package
cd /package

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

$retr http://www.fehcom.de/ipnet/ucspi-ssl/ucspi-ssl-0.95b.tgz
tar -xf ucspi-ssl-0.95b.tgz
cd host/superscript.com/net/ucspi-ssl-0.95b

### compile and install ###
package/install
