#!/usr/bin/env python
import unicodedata
import collections
import subprocess
import codecs
import select
import socket
import signal
import time
import pwd
import sys
import re
import os

LIMIT = float(open('env/LIMIT','rb').read().split('\n')[0]) if os.path.exists('env/LIMIT') else 1
user  = str(os.getpid())
RE    = 'a-zA-Z0-9^(\)\-_{\}[\]|'
nick  = open('nick','rb').read().split('\n')[0]

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
    (256*client_poll())
  ))

def try_write(fd,buffer):
  try:
    os.write(fd,buffer)
  except:
    sock_close(15,0)

def EOF():
  global EOF

  for cmd in auto_cmd:
    time.sleep(len(auto_cmd))
    try_write(wr,cmd+'\n')

  for dst in channels:
    time.sleep(len(channels))
    try_write(wr,'JOIN '+dst+'\n')

  del EOF
  EOF = 0

try_write(wr,'USER '+nick+' '+nick+' '+nick+' :'+nick+'\n')
try_write(wr,'NICK '+nick+'\n')

while 1:
  if client_poll():

    buffer = str()
    while 1:
      byte = os.read(rd,1)
      if not byte:
        sock_close(15,0)
      if byte == '\n':
        break
      if byte != '\r' and len(buffer)<768:
        buffer+=byte

    # PRIVMSG, NOTICE, TOPIC
    if re.search('^:['+RE+']+![~'+RE+'.]+@['+RE+'.]+ ((PRIVMSG)|(NOTICE)|(TOPIC)) #['+RE+']+ :.*$',buffer.upper()):

      src = buffer[1:].split('!',1)[0]

      if src == nick:
        continue

      for path in os.listdir(root):
        try:
          if path != user:
            sock.sendto(buffer+'\n',path)
        except:
          pass

    # PART
    elif re.search('^:['+RE+']+![~'+RE+'.]+@['+RE+'.]+ PART #['+RE+']+( :)?',buffer.upper()):

      if len(buffer.split(' :'))<2:
        buffer += ' :'

      for path in os.listdir(root):
        try:
          if path != user:
            sock.sendto(buffer+'\n',path)
        except:
          pass

    # QUIT
    elif re.search('^:['+RE+']+![~'+RE+'.]+@['+RE+'.]+ QUIT( :)?',buffer.upper()):

      if len(buffer.split(' :'))<2:
        buffer += ' :'

      for path in os.listdir(root):
        try:
          if path != user:
            sock.sendto(buffer+'\n',path)
        except:
          pass

    # PING
    elif re.search('^PING :?.+$',buffer.upper()):
      dst = buffer.split(' ',1)[1]
      try_write(wr,'PONG '+dst+'\n')

    # :nick!user@serv JOIN :#channel
    elif re.search('^:['+RE+']+![~'+RE+'.]+@['+RE+'.]+ JOIN :#['+RE+']+$',buffer.upper()):

      for path in os.listdir(root):
        try:
          if path != user:
            sock.sendto(buffer+'\n',path)
        except:
          pass

      dst = buffer.split(':')[2].lower()
      if not dst in channels:
        channels.append(dst)

    # :nick!* NICK nick_
    elif re.search('^:'+re.escape(nick).upper()+'!.+ NICK ',buffer.upper()):
      nick = buffer.split(' ')[2]

    elif re.search('^:.+ 433 .+ '+re.escape(nick),buffer):
      nick+='_'
      try_write(wr,'NICK '+nick+'\n')

    # :oper!user@serv KICK #channel nick :msg
    elif re.search('^:.+ KICK #['+RE+']+ ['+RE+']+',buffer.upper()):

      if len(buffer.split(' :'))<2:
        buffer += ' :'

      for path in os.listdir(root):
        try:
          if path != user:
            sock.sendto(buffer+'\n',path)
        except:
          pass

      if buffer.split(' ')[3].lower() == nick.lower():
        dst = buffer.split(' ')[2].lower()
        try_write(wr,'JOIN '+dst+'\n')
        channels.remove(dst)

    # :nick!user@serv INVITE nick :#channel
    elif re.search('^:['+RE+']+![~'+RE+'.]+@['+RE+'.]+ INVITE '+re.escape(nick).upper()+' :#['+RE+']+$',buffer.upper()):
      dst = buffer.split(':',2)[2].lower()
      if not dst in channels:
        try_write(wr,'JOIN '+dst+'\n')

    EOF() if EOF else EOF

  while server_poll():

    buffer = os.read(sd,1024)
    if not buffer:
      break

    buffer = codecs.ascii_encode(unicodedata.normalize('NFKD',unicode(buffer,'utf-8','replace')),'ignore')[0]
    buffer = re.sub('[\x02\x0f]','',buffer)
    buffer = re.sub('\x01(ACTION )?','*',buffer) # contains potential irssi bias
    buffer = re.sub('\x03[0-9]?[0-9]?((?<=[0-9]),[0-9]?[0-9]?)?','',buffer)
    buffer = str({str():buffer})[6:][:len(str({str():buffer})[6:])-4]
    buffer = buffer.replace("\\'","'")
    buffer = buffer.replace('\\\\','\\')

    if re.search('^:['+RE+']+![~'+RE+'.]+@['+RE+'.]+ ((PRIVMSG)|(NOTICE)|(TOPIC)) #['+RE+']+ :.*$',buffer.upper()):

      dst = buffer.split(' ',3)[2].lower()

      if dst in channels:

        cmd    = buffer.split(' ',3)[1].upper()
        src    = buffer[1:].split('!',1)[0] + '> ' if cmd != 'TOPIC' else str()
        msg    = buffer.split(':',2)[2]
        buffer = cmd + ' ' + dst + ' :' + src + msg + '\n'

        try_write(wr,buffer)
