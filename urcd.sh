#!/bin/sh

if [ $(id -u) != 0 ]; then
 echo 'fatal error: root privileges required' 1>&2
 exit 1
fi

path="`pwd`/socket/"
mkdir -p "$path"
chown urcd "$path"
echo "$path" > env/URCHUB

if ! pidof urchub 1>/dev/null ; then
 ./urchub ./urccache "$path" &
fi

if ! pidof urchubstream 1>/dev/null ; then
 addr=(db/urchub/tor/*)
 addr=`printf "%s\n" "${addr[RANDOM % ${#addr[@]}]}"`
 port=`cat $addr/port`
 addr=`basename $addr`
 tcpclient -H -R 127.0.0.1 9050 ./ucspi-socks4aclient $addr $port ./urchubstream "$path"
fi

exec tcpserver -H -R -l `cat env/addr` `cat env/addr` `cat env/port` ./urcd `cat env/path`
