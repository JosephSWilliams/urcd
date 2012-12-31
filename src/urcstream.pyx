#!/usr/bin/env python
import socket
import select
import signal
import sys
import os

user = str(os.getpid())

wr = 1
if int(os.getenv('TCPCLIENT',0)):
  wr += 6
rd = wr - 1

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
sock.setblocking(0)
sd=sock.fileno()

client_POLLIN=select.poll()
client_POLLIN.register(rd,3)

server_POLLIN=select.poll()
server_POLLIN.register(sd,3)

def client_poll():
  return len( client_POLLIN.poll(256-
    (256*len( server_POLLIN.poll(0)))
  ))

def server_poll():
  return len( server_POLLIN.poll(256-
    (256*len( client_POLLIN.poll(0)))
  ))

while 1:
  if client_poll():
    buffer = str()
    while 1:
      byte = os.read(rd,1)
      if not byte or len(buffer)>1024:
        sock_close(15,0)
      buffer+=byte
      if byte == '\n':
        break
    for path in os.listdir(os.getcwd()):
      try:
        if path != user:
          sock.sendto(buffer,path)
      except:
        pass

  while server_poll():
    buffer, path = sock.recvfrom(1024)
    if not path:
      continue
    try:
      if not os.write(wr,buffer):
        sock_close(15,0)
    except:
      sock_close(15,0)
