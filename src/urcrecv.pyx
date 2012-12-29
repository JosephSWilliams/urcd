#!/usr/bin/env python
import socket
import sys
import os

os.chdir(sys.argv[1])
os.chroot(os.getcwd())

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

  for path in os.listdir(os.getcwd()):
    try:
      sock.sendto(buffer,path)
    except:
      pass
