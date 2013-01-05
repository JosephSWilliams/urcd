#!/usr/bin/env python
import collections
import subprocess
import select
import socket
import signal
import time
import sys
import re
import os

user = str(os.getpid())
RE   = 'a-zA-Z0-9^(\)-_{\}[\]|'
nick = open('nick','rb').read().split('\n')[0]

channels = collections.deque([],64)
for dst in open('channels','rb').read().split('\n'):
  if dst:
    channels.append(dst.lower())

auto_cmd = collections.deque([],64)
for cmd in open('auto_cmd','rb').read().split('\n'):
  if cmd:
    auto_cmd.append(cmd)

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

rd = 0
if os.access('stdin',1):
  p = subprocess.Popen(['./stdin'],stdout=subprocess.PIPE)
  rd = p.stdout.fileno()
  del p

wr = 1
if os.access('stdout',1):
  p = subprocess.Popen(['./stdout'],stdin=subprocess.PIPE)
  wr = p.stdin.fileno()
  del p

os.chdir(sys.argv[1])
os.chroot(os.getcwd())
root = os.getcwd()

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

def EOF():
  global EOF

  for cmd in auto_cmd:
    time.sleep(1)
    os.write(wr,cmd+'\n')

  for dst in channels:
    time.sleep(1)
    os.write(wr,'JOIN '+dst+'\n')

  del EOF
  EOF = 0

os.write(wr,'USER '+nick+' '+nick+' '+nick+' :'+nick+'\n')
os.write(wr,'NICK '+nick+'\n')

while 1:
  if client_poll():

    buffer = str()
    while 1:
      byte = os.read(rd,1)
      if not byte or len(buffer)>1024:
        sock_close(15,0)
      if byte == '\n':
        break
      if byte != '\r':
        buffer+=byte

    if re.search('^:['+RE+']+!['+RE+']+@['+RE+'.]+ ((PRIVMSG)|(NOTICE)|(TOPIC)) #['+RE+']+ :.*$',buffer.upper()):
      for path in os.listdir(root):
        try:
          if path != user:
            sock.sendto(buffer+'\n',path)
        except:
          pass
      continue

    # PING
    if re.search('^PING :?.+$',buffer.upper()):
      dst = buffer.split(' ',1)[1]
      os.write(wr,'PONG '+dst+'\n')
      continue

    # :nick!user@serv JOIN :#channel
    if re.search('^:'+re.escape(nick)+'!.+ JOIN :#['+RE+']+$',buffer.upper()):
      dst = buffer.split(':')[2].lower()
      if not dst in channels:
        channels.append(dst)
      continue

    # :nick!* NICK nick_
    if re.search('^:'+re.escape(nick)+'!.+ NICK ',buffer.upper()):
      nick = buffer.split(' ')[2]
      continue

    if re.search('^:.+ 433 .+ '+re.escape(nick),buffer):
      nick+='_'
      os.write(wr,'NICK '+nick+'\n')
      continue

    # :oper!user@serv KICK #channel nick :msg
    if re.search('^:.+ KICK ',buffer.upper()) and buffer.split(' ')[3] == nick:
      dst = buffer.split(' ')[2].lower()
      os.write(wr,'JOIN '+dst+'\n')
      channels.remove(dst)
      continue

    # :nick!user@serv INVITE nick :#channel
    if re.search('^:['+RE+']+!['+RE+']+@['+RE+'.]+ INVITE '+re.escape(nick)+' :#['+RE+']+$',buffer.upper()):
      dst = buffer.split(':',2)[2]
      if not dst in channels:
        os.write(wr,'JOIN '+dst+'\n')
      continue

    EOF() if EOF else EOF

  while server_poll():

    buffer = os.read(sd,1024)
    if not buffer:
      break

    # escape evil buffer :-)
    buffer = re.sub('[\x02\x0f]','',buffer)
    buffer = re.sub('\x01(ACTION )?','*',buffer)
    buffer = re.sub('\x03[0-9][0-9]?(,[0-9][0-9]?)?','',buffer)
    buffer = str({str():buffer})[6:][:len(str({str():buffer})[6:])-4]
    buffer = buffer.replace("\\'","'")
    buffer = buffer.replace('\\\\','\\')

    if re.search('^:['+RE+']+!['+RE+']+@['+RE+'.]+ ((PRIVMSG)|(NOTICE)|(TOPIC)) #['+RE+']+ :.*$',buffer.upper()):

      dst = buffer.split(' ',3)[2].lower()

      if dst in channels:

        src    = buffer[1:].split('!',1)[0] + '> '
        cmd    = buffer.split(' ',3)[1].upper()
        msg    = buffer.split(':',2)[2]
        buffer = cmd + ' ' + dst + ' :' + src + msg + '\n'

        if len(buffer)<=1024:
          os.write(wr,buffer)

sock_close(0,0)
