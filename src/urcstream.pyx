#!/usr/bin/env python
import socket
import select
import signal
import time
import pwd
import sys
import os

user  = str(os.getpid())
LIMIT = float(open('env/LIMIT','rb').read().split('\n')[0]) if os.path.exists('env/LIMIT') else 1

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
sock.setblocking(0)
sd=sock.fileno()

client_POLLIN=select.poll()
client_POLLIN.register(rd,3)

server_POLLIN=select.poll()
server_POLLIN.register(sd,3)

now = time.time()
def limit():
  if ((time.time() - now) > LIMIT):
    global now
    now = time.time()
    return 0
  return 1

def client_poll():
  return 0 if limit() else len( client_POLLIN.poll(256-
    (256*len( server_POLLIN.poll(0)))
  ))

def server_poll():
  return len( server_POLLIN.poll(256-
    (256*len( client_POLLIN.poll(0)))
  ))

while 1:
  if (client_poll() and limit()):

    buffer = str()

    while 1:
      byte = os.read(rd,1)
      if not byte: sock_close(15,0)
      elif byte == '\n':
        buffer+=byte
        break
      elif len(buffer)<1024: buffer+=byte

    for path in os.listdir(root):
      try:
        if path != user:
          sock.sendto(buffer,path)
      except:
        pass

  while server_poll():
    buffer = os.read(sd,1024)
    if buffer[len(buffer)-1:] != '\n': continue
    try:
      if not os.write(wr,buffer):
        sock_close(15,0)
    except:
      sock_close(15,0)
