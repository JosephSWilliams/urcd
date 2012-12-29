#!/usr/bin/env python
import socket
import signal
import sys
import os

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

os.chdir(sys.argv[1])
os.chroot(os.getcwd())

sock=socket.socket(1,2)
sock_close(0,0)
sock.bind(str(os.getpid()))

while 1:

  buffer, path = sock.recvfrom(1024)
  if not path:
    continue

  try:
    if not os.write(7,buffer):
      break
  except:
    break

sock_close(0,0)
