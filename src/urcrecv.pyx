#!/usr/bin/env python
import socket
import time
import pwd
import sys
import os

LIMIT = float(open('env/LIMIT','rb').read().split('\n')[0]) if os.path.exists('env/LIMIT') else 1

uid, gid = pwd.getpwnam('urcd')[2:4]
os.chdir(sys.argv[1])
os.chroot(os.getcwd())
os.setgid(gid)
os.setuid(uid)
root = os.getcwd()
del uid, gid

sock=socket.socket(1,2)
sock.setblocking(0)

nl, buffer, afternl = int(), str(), str()

while 1:

  # line protocols suck
  nl = 0
  buffer = str()
  for byte in afternl+os.read(rd,1024-len(afternl)):
    if not nl:
      buffer += byte
      if byte == '\n': nl = 1
    else: afternl += byte
  if not nl: sock_close(15,0)

  time.sleep(LIMIT)

  for path in os.listdir(root):
    try:
      sock.sendto(buffer,path)
    except:
      pass
