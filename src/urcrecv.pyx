#!/usr/bin/env python
import socket
import time
import pwd
import sys
import os

LIMIT = 1

uid = pwd.getpwnam('urcd')[2]
os.chdir(sys.argv[1])
os.chroot(os.getcwd())
os.setuid(uid)
root = os.getcwd()
del uid

sock=socket.socket(1,2)
sock.setblocking(0)

while 1:

  buffer = str()
  while 1:
    byte = os.read(0,1)
    if not byte or len(buffer)>1024:
      sys.exit(0)
    buffer+=byte
    if byte == '\n':
      break

  time.sleep(LIMIT)

  for path in os.listdir(root):
    try:
      sock.sendto(buffer,path)
    except:
      pass
