#!/bin/sh

### is this really necessary? ###
mkdir -p /package
chmod 1755 /package
cd /package

### download and unpack daemontools ###
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
$retr http://cr.yp.to/daemontools/daemontools-0.76.tar.gz
gunzip daemontools-0.76.tar
tar -xpf daemontools-0.76.tar
rm -f daemontools-0.76.tar
cd admin/daemontools-0.76

### workaround libc bug ###
sed -i 's/gcc/gcc -include errno.h/' src/conf-cc

### compile and install ###
package/install

### workaround debian/ubuntu ###
if which apt-get; then
 sed -i 's/^exit 0/\/command\/svscanboot \&\n\nexit 0/' /etc/rc.local
 ### i don't think we need a reboot to bootstrap daemontools ###
 /command/svscanboot 2>/dev/null & disown
 chmod +x /etc/rc.local
fi

### we want this directory ###
mkdir -p /services/
