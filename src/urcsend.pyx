#!/usr/bin/env python
import socket
import signal
import pwd
import sys
import os

fd = int(os.getenv('CURVECPCLIENT',7))

def sock_close(sn,sf):
  try:
    os.remove(str(os.getpid()))
  except:
    pass
  if sn:
    sys.exit(0)

signal.signal(1 ,sock_close)
signal.signal(2 ,sock_close)
signal.signal(15,sock_close)

uid, gid = pwd.getpwnam('urcd')[2:4]
os.chdir(sys.argv[1])
os.chroot(os.getcwd())
os.setgid(gid)
os.setuid(uid)
root = os.getcwd()
del uid, gid

sock=socket.socket(1,2)
sock_close(0,0)
sock.bind(str(os.getpid()))

while 1:

  buffer, path = sock.recvfrom(1024)
  if not path or buffer[len(buffer)-1:] != '\n': continue

  try:
    if not os.write(fd,buffer):
      sock_close(15,0)
  except:
    sock_close(15,0)
