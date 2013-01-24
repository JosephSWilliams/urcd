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

NICKLEN    = 32
TOPICLEN   = 512
CHANLIMIT  = 64
CHANNELLEN = 64

nick           = str()
user           = str(os.getpid())
RE             = 'a-zA-Z0-9^(\)\-_{\}[\]|'
serv           = open('env/serv','rb').read().split('\n')[0]
motd           = open('env/motd','rb').read().split('\n')
channels       = collections.deque([],CHANLIMIT)
channel_struct = dict()

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

uid = pwd.getpwnam('urcd')[2]
os.chdir(sys.argv[1])
os.chroot(os.getcwd())
os.setuid(uid)
root = os.getcwd()
del uid

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
      if not byte or len(buffer)>=768:
        sock_close(15,0)
      if byte == '\n':
        break
      if byte != '\r':
        buffer+=byte

    # workarounds for shoddy clients
    buffer = re.sub(' $','',buffer) # chatzilla sucks
    buffer = re.sub('^((NICK)|(nick)) :','NICK ',buffer) # mIRC sucks

    # /NICK
    if re.search('^NICK ['+RE+']+$',buffer.upper()):

      if not nick:
        nick = buffer.split(' ')[1].lower()

        if len(nick)>NICKLEN:
          os.write(wr,'ERROR : EMSGSIZE:NICKLEN='+str(NICKLEN)+'\n')
          continue

        os.write(wr,
          ':'+serv+' 001 '+nick+' :'+serv+'\n'
          ':'+serv+' 002 '+nick+' :'+nick+'!'+user+'@'+serv+'\n'
          ':'+serv+' 003 '+nick+' :'+serv+'\n'
          ':'+serv+' 004 '+nick+' '+serv+' 0.0 + :+\n'
          ':'+serv+' 005 '+nick+' NETWORK='+serv+' CHANLIMIT='+str(CHANLIMIT)+' NICKLEN='+str(NICKLEN)+' TOPICLEN='+str(TOPICLEN)+' CHANNELLEN='+str(CHANNELLEN)+':\n'
          ':'+serv+' 254 '+nick+' '+str(CHANLIMIT)+' :CHANNEL(S)\n'
          ':'+nick+'!'+user+'@'+serv+' MODE '+nick+' +i\n'
        )

        os.write(wr,':'+serv+' 375 '+nick+' :- '+serv+' MOTD -\n')
        for msg in motd:
          os.write(wr,':'+serv+' 372 '+nick+' :- '+msg+'\n')
        os.write(wr,':'+serv+' 376 '+nick+' :EOF MOTD\n')

        del motd

        continue

      src  = nick
      nick = buffer.split(' ')[1].lower()

      if len(nick)>NICKLEN:
        os.write(wr,'ERROR : EMSGSIZE:NICKLEN='+str(NICKLEN)+'\n')
        continue

      os.write(wr,':'+src+'!'+user+'@'+serv+' NICK '+nick+'\n')

      for dst in channel_struct.keys():
        if dst in channels:
          channel_struct[dst]['names'].remove(src)
          if not nick in channel_struct[dst]['names']:
            channel_struct[dst]['names'].append(nick)

      continue

    if not nick:
      continue

    # /PRIVMSG, /NOTICE, /TOPIC, /PART
    if re.search('^((PRIVMSG)|(NOTICE)|(TOPIC)|(PART)) #?['+RE+']+ :.*$',buffer.upper()):

      cmd = buffer.split(' ',1)[0].upper()
      dst = buffer.split(' ',2)[1]
      msg = buffer.split(':',1)[1]

      if dst[0] == '#':
        if len(dst)>CHANNELLEN:
          os.write(wr,'ERROR : EMSGSIZE:CHANNELLEN='+str(CHANNELLEN)+'\n')
          continue

      elif len(dst)>NICKLEN:
        os.write(wr,'ERROR : EMSGSIZE:NICKLEN='+str(NICKLEN)+'\n')
        continue

      if cmd == 'TOPIC':

        if len(msg)>TOPICLEN:
          os.write(wr,'ERROR : EMSGSIZE:TOPICLEN='+str(TOPICLEN)+'\n')
          continue

        os.write(wr,':'+nick+'!'+user+'@'+serv+' '+cmd+' '+dst+' :'+msg+'\n')

        if dst[0] == '#':

          if not dst in channel_struct.keys():
            channel_struct[dst] = dict(
              topic             = msg,
              names             = collections.deque([],CHANLIMIT),
            )

          else:
            channel_struct[dst]['topic'] = msg

      if cmd == 'PART' and dst in channels:
        os.write(wr,':'+nick+'!'+user+'@'+serv+' '+cmd+' '+dst+' :'+msg+'\n')
        channels.remove(dst)
        channel_struct[dst]['names'].remove(nick)
        continue

      for path in os.listdir(root):
        try:
          if path != user:
            sock.sendto(':'+nick+'!'+user+'@'+serv+' '+cmd+' '+dst+' :'+msg+'\n',path)
        except:
          pass

      continue

    # /PING
    if re.search('^PING :?.+$',buffer.upper()):

      dst = buffer.split(' ',1)[1]

      os.write(wr,'PONG '+dst+'\n')
      continue

    # /MODE #channel [<arg>,...]
    if re.search('^MODE #['+RE+']+( [-+a-zA-Z]+)?$',buffer.upper()):

      dst = buffer.split(' ')[1]

      os.write(wr,':'+serv+' 324 '+nick+' '+dst+' +n\n')
      os.write(wr,':'+serv+' 329 '+nick+' '+dst+' '+str(int(time.time()))+'\n')

      continue

    # /MODE nick
    if re.search('^MODE ['+RE+']+$',buffer.upper()):

      dst = buffer.split(' ')[1]

      os.write(wr,':'+serv+' 221 '+dst+' :+i\n')
      continue

    # /MODE nick <arg>
    # chatzilla sucks again (:?)
    if re.search('^MODE ['+RE+']+ :?[-+][a-zA-Z]$',buffer.upper()):

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
    if re.search('WHO .+',buffer.upper()):

      dst = buffer.split(' ',2)[1].lower()

      if dst in channel_struct.keys():
        for src in channel_struct[dst]['names']:
          os.write(wr,':'+serv+' 352 '+nick+' '+dst+' '+src+' '+serv+' '+src+' '+src+' H :0 '+src+'\n')
      os.write(wr,':'+serv+' 315 '+nick+' '+dst+' :EOF WHO\n')
      continue

    # /INVITE
    if re.search('^INVITE ['+RE+']+ #['+RE+']+$',buffer.upper()):

      dst = buffer.split(' ')[1]
      msg = buffer.split(' ')[2]

      if len(dst)>NICKLEN:
        os.write(wr,'ERROR : EMSGSIZE:NICKLEN='+str(NICKLEN)+'\n')
        continue

      elif len(msg)>CHANNELLEN:
        os.write(wr,'ERROR : EMSGSIZE:CHANNELLEN='+str(CHANNELLEN)+'\n')
        continue

      os.write(wr,':'+serv+' 341 '+nick+' '+dst+' '+msg+'\n')

      for path in os.listdir(root):
        try:
          if path != user:
            sock.sendto(':'+nick+'!'+user+'@'+serv+' INVITE '+dst+' :'+msg+'\n',path)
        except:
          pass
      continue

    # /JOIN
    if re.search('^JOIN [#'+RE+',]+$',buffer.upper()):

      dst = buffer.split(' ',1)[1].lower()

      for dst in dst.split(','):

        if len(channels)>CHANLIMIT:
          os.write(wr,'ERROR : EMSGSIZE:CHANLIMIT='+str(CHANLIMIT)+'\n')
          continue

        if len(dst)>CHANNELLEN:
          os.write(wr,'ERROR : EMSGSIZE:CHANNELLEN='+str(CHANNELLEN)+'\n')
          continue

        if dst in channels:
          continue

        channels.append(dst)

        if not dst in channel_struct.keys():
          channel_struct[dst] = dict(
            topic             = None,
            names             = collections.deque([],CHANLIMIT),
          )

        if nick in channel_struct[dst]['names']:
          channel_struct[dst]['names'].remove(nick)

        if channel_struct[dst]['topic']:
          os.write(wr,':'+serv+' 332 '+nick+' '+dst+' :'+channel_struct[dst]['topic']+'\n')

        os.write(wr,':'+nick+'!'+user+'@'+serv+' JOIN :'+dst+'\n')

        os.write(wr,':'+serv+' 353 '+nick+' = '+dst+' :'+nick+' ')
        for src in channel_struct[dst]['names']:
          os.write(wr,src+' ')
        os.write(wr,'\n')

        os.write(wr,':'+serv+' 366 '+nick+' '+dst+' :EOF NAMES\n')

        if len(channel_struct[dst]['names'])==CHANLIMIT:
          os.write(wr,':'+channel_struct[dst]['names'][0]+'!'+channel_struct[dst]['names'][0]+'@'+serv+' PART '+dst+'\n')

        channel_struct[dst]['names'].append(nick)

      continue

    # /PART
    if re.search('^PART #['+RE+',]+$',buffer.upper()):

      dst = buffer.split(' ')[1]

      for dst in dst.split(','):
        if dst in channels:
          os.write(wr,':'+nick+'!'+user+'@'+serv+' PART '+dst+' :\n')
          channels.remove(dst)
          channel_struct[dst]['names'].remove(nick)
      continue

    # /LIST
    if re.search('^LIST',buffer.upper()):

      os.write(wr,':'+serv+' 321 '+nick+' channel :users name\n')

      for dst in channel_struct.keys():

        if len(channel_struct[dst]['names']):

          os.write(wr,':'+serv+' 322 '+nick+' '+dst+' '+str(len(channel_struct[dst]['names']))+' :[+n] ')
          if channel_struct[dst]['topic']:
            os.write(wr,channel_struct[dst]['topic'])
          os.write(wr,'\n')

      os.write(wr,':'+serv+' 323 '+nick+' :EOF LIST\n')
      continue

    # /QUIT
    if re.search('^QUIT ',buffer.upper()):
      break

    # /USER
    if re.search('^USER .*$',buffer.upper()):
      continue

    else:
      buffer = str({str():buffer})[6:][:len(str({str():buffer})[6:])-2]
      buffer = buffer.replace("\\'","'")
      buffer = buffer.replace('\\\\','\\')
      os.write(wr,':'+serv+' NOTICE '+nick+' :ERROR: '+buffer+'\n')

  while server_poll():

    buffer = os.read(sd,1024)
    if not buffer:
      break

    buffer = codecs.ascii_encode(unicodedata.normalize('NFKD',unicode(buffer,'utf-8','replace')),'ignore')[0]
    buffer = re.sub('[\x02\x0f]','',buffer)
    buffer = re.sub('\x01(ACTION )?','*',buffer) # contains potential irssi bias
    buffer = re.sub('\x03[0-9][0-9]?(,[0-9][0-9]?)?','',buffer)
    buffer = str({str():buffer})[6:][:len(str({str():buffer})[6:])-4]+'\n'
    buffer = buffer.replace("\\'","'")
    buffer = buffer.replace('\\\\','\\')

    # PRIVMSG, NOTICE, TOPIC, INVITE, PART
    if re.search('^:['+RE+']+!['+RE+'.]+@['+RE+'.]+ ((PRIVMSG)|(NOTICE)|(TOPIC)|(INVITE)|(PART)) #?['+RE+']+ :.*$',buffer.upper()):

      src = buffer.split(':',2)[1].split('!',1)[0].lower()

      if len(src)>NICKLEN:
        continue

      cmd = buffer.split(' ',3)[1].upper()
      dst = buffer.split(' ',3)[2].lower()

      if dst[0] == '#':

        if len(dst)>CHANNELLEN:
          continue

        if not dst in channel_struct.keys():

          if len(channel_struct.keys())>=CHANLIMIT:

            for dst in channel_struct.keys():

              if not dst in channels:
                del channel_struct[dst]
                break

            dst = buffer.split(' ',3)[2].lower()

          channel_struct[dst] = dict(
            topic             = None,
            names             = collections.deque([],CHANLIMIT),
          )

        if cmd == 'TOPIC':

          msg = buffer.split(':',2)[2].split('\n',1)[0]

          if len(msg)>TOPICLEN:
            continue

          channel_struct[dst]['topic'] = msg

        if cmd == 'PART':

          if src != nick and src in channel_struct[dst]['names']:
            channel_struct[dst]['names'].remove(src)
            os.write(wr,buffer)
          continue

        if src != nick and not src in channel_struct[dst]['names']:

          if dst in channels:

            os.write(wr,buffer.split(' ',1)[0]+' JOIN :'+dst+'\n')

            if len(channel_struct[dst]['names'])==CHANLIMIT:

              if nick != channel_struct[dst]['names'][0]:
                os.write(wr,':'+channel_struct[dst]['names'][0]+'!'+channel_struct[dst]['names'][0]+'@'+serv+' PART '+dst+'\n')
              else:
                channel_struct[dst]['names'].append(nick)

          channel_struct[dst]['names'].append(src)

      elif cmd == 'PART':
        continue

      if dst == nick or dst in channels:
        os.write(wr,buffer)

    # JOIN
    elif re.search('^:['+RE+']+!['+RE+'.]+@['+RE+'.]+ JOIN :#['+RE+']+$',buffer.upper()):

      src = buffer.split(':',2)[1].split('!',1)[0].lower()

      if len(src)>NICKLEN:
        continue

      dst = buffer.split(':')[2].split('\n',1)[0].lower()

      if len(dst)>CHANNELLEN:
        continue

      if not dst in channel_struct.keys():

        if len(channel_struct.keys())>=CHANLIMIT:

          for dst in channel_struct.keys():

            if not dst in channels:
              del channel_struct[dst]
              break

          dst = buffer.split(':')[2].split('\n',1)[0].lower()

        channel_struct[dst] = dict(
          topic             = None,
          names             = collections.deque([],CHANLIMIT),
        )

      if src != nick and not src in channel_struct[dst]['names']:

        if dst in channels:

          os.write(wr,buffer)

          if len(channel_struct[dst]['names'])==CHANLIMIT:

            if nick != channel_struct[dst]['names'][0]:
              os.write(wr,':'+channel_struct[dst]['names'][0]+'!'+channel_struct[dst]['names'][0]+'@'+serv+' PART '+dst+'\n')
            else:
              channel_struct[dst]['names'].append(nick)

        channel_struct[dst]['names'].append(src)

    # QUIT
    elif re.search('^:['+RE+']+!['+RE+'.]+@['+RE+'.]+ QUIT :.*$',buffer.upper()):

      src = buffer.split(':',2)[1].split('!',1)[0].lower()

      if src == nick:
        continue

      if len(src)>NICKLEN:
        continue

      cmd = '\x01'

      for dst in channel_struct.keys():

        if src in channel_struct[dst]['names']:
          channel_struct[dst]['names'].remove(src)

          if cmd == '\x01' and dst in channels:
            os.write(wr,buffer)
            cmd = '\x00'

    # KICK
    elif re.search('^:['+RE+']+!['+RE+'.]+@['+RE+'.]+ KICK #['+RE+']+ ['+RE+']+ :.*$',buffer.upper()):

      src = buffer.split(' ',4)[3].lower()

      if len(src)>NICKLEN:
        continue

      dst = buffer.split(' ',3)[2].lower()

      if len(dst)>CHANNELLEN:
        continue

      if not dst in channel_struct.keys():

        if len(channel_struct.keys())>=CHANLIMIT:

          for dst in channel_struct.keys():

            if not dst in channels:
              del channel_struct[dst]
              break

          dst = buffer.split(' ',3)[2].lower()

        channel_struct[dst] = dict(
          topic             = None,
          names             = collections.deque([],CHANLIMIT),
        )

      if src != nick:

        for dst in channel_struct.keys():

          if src in channel_struct[dst]['names']:
            channel_struct[dst]['names'].remove(src)

        dst = buffer.split(' ',3)[2].lower()

        if dst in channels:
          os.write(wr,buffer)

sock_close(0,0)
