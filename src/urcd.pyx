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

nick      = str()
user      = str(os.getpid())
serv      = open('env/serv','rb').read().split('\n')[0]
motd      = open('env/motd','rb').read().split('\n')
channels  = collections.deque([],64)

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

rd = sys.stdin.fileno()
if os.access('stdin',os.X_OK):
  p = subprocess.Popen(['./stdin'],stdout=subprocess.PIPE)
  rd = p.stdout.fileno()
  del p

wr = sys.stdout.fileno()
if os.access('stdout',os.X_OK):
  p = subprocess.Popen(['./stdout'],stdin=subprocess.PIPE)
  wr = p.stdin.fileno()
  del p

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
      if byte == '\n':
        break
      if byte != '\r':
        buffer+=byte

    # workarounds for shoddy clients
    buffer = re.sub(' $','',buffer) # chatzilla sucks
    buffer = re.sub('^((NICK)|(nick)) :','NICK ',buffer) # mIRC sucks

    # /NICK
    if re.search('^NICK \w+$',buffer.upper()):

      if not nick:
        nick = buffer.split(' ')[1]
        os.write(wr,
          ':'+serv+' 001 '+nick+' :'+serv+'\n'
          ':'+serv+' 002 '+nick+' :'+nick+'!'+user+'@'+serv+'\n'
          ':'+serv+' 003 '+nick+' :'+serv+'\n'
          ':'+serv+' 004 '+nick+' '+serv+' 0.0 + :+\n'
          ':'+serv+' 005 '+nick+' NETWORK='+serv+' :\n'
          ':'+nick+'!'+user+'@'+serv+' MODE '+nick+' +i\n'
        )

        os.write(wr,':'+serv+' 375 '+nick+' :- '+serv+' MOTD -\n')
        for msg in motd:
          os.write(wr,':'+serv+' 372 '+nick+' :- '+msg+'\n')
        os.write(wr,':'+serv+' 376 '+nick+' :EOF MOTD\n')

        del motd

        continue

      os.write(wr,':'+nick+'!'+user+'@'+serv+' NICK ')
      nick = buffer.split(' ')[1]
      os.write(wr,nick+'\n')
      continue

    if not nick:
      continue

    # /PRIVMSG, /NOTICE, /TOPIC, /PART
    if re.search('^((PRIVMSG)|(NOTICE)|(TOPIC)|(PART)) #?\w+ :.*$',buffer.upper()):

      cmd = buffer.split(' ',1)[0].upper()
      dst = buffer.split(' ',2)[1]
      msg = buffer.split(':',1)[1]

      if cmd == 'PART' and dst in channels:
        os.write(wr,':'+nick+'!'+user+'@'+serv+' '+cmd+' '+dst+' :'+msg+'\n')
        channels.remove(dst)
        continue

      for path in os.listdir(os.getcwd()):
        try:
          if path != user:
            sock.sendto(':'+nick+'!'+user+'@'+serv+' '+cmd+' '+dst+' :'+msg+'\n',path)
        except:
          pass

      if cmd == 'TOPIC':
        os.write(wr,':'+nick+'!'+user+'@'+serv+' '+cmd+' '+dst+' :'+msg+'\n')

      continue

    # /PING
    if re.search('^PING :?[\w.]+$',buffer.upper()):

      dst = buffer.split(' ',1)[1]

      os.write(wr,'PONG '+dst+'\n')
      continue

    # /MODE #channel [<arg>,...]
    if re.search('^MODE #\w+( [-+a-zA-Z]+)?$',buffer.upper()):

      dst = buffer.split(' ')[1]

      os.write(wr,':'+serv+' 324 '+nick+' '+dst+' +n\n')
      os.write(wr,':'+serv+' 329 '+nick+' '+dst+' '+str(int(time.time()))+'\n')

      continue

    # /MODE nick
    if re.search('^MODE \w+$',buffer.upper()):

      dst = buffer.split(' ')[1]

      os.write(wr,':'+serv+' 221 '+dst+' :+i\n')
      continue

    # /MODE nick <arg>
    # chatzilla sucks again (:?)
    if re.search('^MODE \w+ :?[-+][a-zA-Z]$',buffer.upper()):

      dst = buffer.split(' ')[1]

      os.write(wr,':'+nick+'!'+user+'@'+serv+' MODE '+nick+' +i\n')
      continue

    # /AWAY
    if re.search('^AWAY ?$',buffer.upper()):
      os.write(wr,':'+serv+' 305 '+nick+' :WB, :-)\n')
      continue

    # /AWAY <msg>
    if re.search('^AWAY .+$',buffer.upper()):
      os.write(wr,':'+serv+' 306 '+nick+' :HB, :-)\n')
      continue

    # /WHO
    if re.search('^WHO .+',buffer.upper()):
      cmd = buffer.split(' ')[1]
      os.write(wr,':'+serv+' 315 '+nick+' '+cmd+' :EOF WHO\n')
      continue

    # /INVITE
    if re.search('^INVITE \w+ #\w+$',buffer.upper()):

      dst = buffer.split(' ')[1]
      msg = buffer.split(' ')[2]

      os.write(wr,':'+serv+' 341 '+nick+' '+dst+' '+msg+'\n')

      for path in os.listdir(os.getcwd()):
        try:
          if path != user:
            sock.sendto(':'+nick+'!'+user+'@'+serv+' INVITE '+dst+' :'+msg+'\n',path)
        except:
          pass
      continue

    # /JOIN
    if re.search('^JOIN [#\w,]+$',buffer.upper()):

      dst = buffer.split(' ',1)[1].lower()

      for dst in dst.split(','):
        if dst in channels:
          continue
        channels.append(dst)
        os.write(wr,
          ':'+nick+'!'+user+'@'+serv+' JOIN :'+dst+'\n'
          ':'+serv+' 353 '+nick+' = '+dst+' :'+nick+'\n'
          ':'+serv+' 366 '+nick+' '+dst+' :EOF NAMES\n'
        )
      continue

    # /PART
    if re.search('^PART [#\w,]+$',buffer.upper()):

      dst = buffer.split(' ')[1]

      for dst in dst.split(','):
        if dst in channels:
          os.write(wr,':'+nick+'!'+user+'@'+serv+' PART '+dst+' :\n')
          channels.remove(dst)
      continue

    if re.search('^QUIT ',buffer.upper()):
      break

    # /USER
    if re.search('^USER .*$',buffer.upper()):
      continue

    else:
      buffer = str({str():buffer})[6:][:len(str({str():buffer})[6:])-2]
      buffer = buffer.replace("\\'","'")
      buffer = buffer.replace('\\\\','\\')
      os.write(wr,'ERROR :UNKNOWN COMMAND:'+buffer+'\n')
      continue

  while server_poll():

    buffer = os.read(sd,1024)
    if not buffer:
      break

    # escape evil buffer :-)
    buffer = str({str():buffer})[6:][:len(str({str():buffer})[6:])-4]+'\n'
    buffer = buffer.replace("\\'","'")
    buffer = buffer.replace('\\\\','\\')

    if re.search('^:\w+!\w+@[\w.]+ ((PRIVMSG)|(NOTICE)|(TOPIC)|(INVITE)) #?\w+ :.*$',buffer.upper()):

      dst = buffer.split(' ',3)[2].lower()

      if dst == nick or dst in channels:
        os.write(wr,buffer)
      continue

sock_close(0,0)
