#!/bin/sh

### is this really necessary? ###
mkdir -p /package
chmod 1755 /package
cd /package

### download and unpack daemontools ###
wget http://cr.yp.to/daemontools/daemontools-0.76.tar.gz
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
fi

### we want this directory ###
mkdir -p /services/
