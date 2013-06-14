#!/usr/bin/env python
import unicodedata
import collections
import subprocess
import codecs
import select
import socket
import signal
import shelve
import time
import pwd
import sys
import re
import os

RE = 'a-zA-Z0-9^(\)\-_{\}[\]|'
re_SPLIT = re.compile(' +:?',re.IGNORECASE).split
re_CHATZILLA = re.compile(' $',re.IGNORECASE).sub
re_MIRC = re.compile('^NICK :',re.IGNORECASE).sub
re_CLIENT_PING_PONG = re.compile('^P[IO]NG :?.+$',re.IGNORECASE).search
re_CLIENT_NICK = re.compile('^NICK ['+RE+']+$',re.IGNORECASE).search
re_CLIENT_PRIVMSG_NOTICE_TOPIC_PART = re.compile('^((PRIVMSG)|(NOTICE)|(TOPIC)|(PART)) [#&!+]?['+RE+']+ :.*$',re.IGNORECASE).search
re_CLIENT_MODE_CHANNEL_ARG = re.compile('^MODE [#&!+]['+RE+']+( [-+a-zA-Z]+)?$',re.IGNORECASE).search
re_CLIENT_MODE_NICK = re.compile('^MODE ['+RE+']+$',re.IGNORECASE).search
re_CLIENT_MODE_NICK_ARG = re.compile('^MODE ['+RE+']+ :?[-+][a-zA-Z]$',re.IGNORECASE).search
re_CLIENT_AWAY_OFF = re.compile('^AWAY ?$',re.IGNORECASE).search
re_CLIENT_AWAY_ON = re.compile('^AWAY .+$',re.IGNORECASE).search
re_CLIENT_WHO = re.compile('^WHO .+',re.IGNORECASE).search
re_CLIENT_INVITE = re.compile('^INVITE ['+RE+']+ [#&!+]['+RE+']+$',re.IGNORECASE).search
re_CLIENT_JOIN = re.compile('^JOIN :?([#&!+]['+RE+']+,?)+ ?',re.IGNORECASE).search
re_CLIENT_PART = re.compile('^PART ([#&!+]['+RE+']+,?)+ ?',re.IGNORECASE).search
re_CLIENT_LIST = re.compile('^LIST',re.IGNORECASE).search
re_CLIENT_QUIT = re.compile('^QUIT ',re.IGNORECASE).search
re_CLIENT_USER = re.compile('^USER ',re.IGNORECASE).search
re_BUFFER_CTCP_DCC = re.compile('\x01(?!ACTION )',re.IGNORECASE).sub
re_BUFFER_COLOUR = re.compile('(\x03[0-9][0-9]?((?<=[0-9]),[0-9]?[0-9]?)?)|[\x02\x03\x0f\x1d\x1f]',re.IGNORECASE).sub
re_SERVER_PRIVMSG_NOTICE_TOPIC_INVITE_PART = re.compile('^:['+RE+']+![~'+RE+'.]+@['+RE+'.]+ ((PRIVMSG)|(NOTICE)|(TOPIC)|(INVITE)|(PART)) [#&!+]?['+RE+']+ :.*$',re.IGNORECASE).search
re_SERVER_JOIN = re.compile('^:['+RE+']+![~'+RE+'.]+@['+RE+'.]+ JOIN :[#&!+]['+RE+']+$',re.IGNORECASE).search
re_SERVER_QUIT = re.compile('^:['+RE+']+![~'+RE+'.]+@['+RE+'.]+ QUIT :.*$',re.IGNORECASE).search
re_SERVER_KICK = re.compile('^:['+RE+']+![~'+RE+'.]+@['+RE+'.]+ KICK [#&!+]['+RE+']+ ['+RE+']+ :.*$',re.IGNORECASE).search

PING = int(open('env/PING','rb').read().split('\n')[0]) if os.path.exists('env/PING') else 0
URCDB = open('env/URCDB','rb').read().split('\n')[0] if os.path.exists('env/URCDB') else str()
FLOOD = int(open('env/FLOOD','rb').read().split('\n')[0]) if os.path.exists('env/FLOOD') else 0
LIMIT = float(open('env/LIMIT','rb').read().split('\n')[0]) if os.path.exists('env/LIMIT') else 1
COLOUR = int(open('env/COLOUR','rb').read().split('\n')[0]) if os.path.exists('env/COLOUR') else 0
UNICODE = int(open('env/UNICODE','rb').read().split('\n')[0]) if os.path.exists('env/UNICODE') else 0
NICKLEN = int(open('env/NICKLEN','rb').read().split('\n')[0]) if os.path.exists('env/NICKLEN') else 32
TIMEOUT = int(open('env/TIMEOUT','rb').read().split('\n')[0]) if os.path.exists('env/TIMEOUT') else 128
PRESENCE = int(open('env/PRESENCE','rb').read().split('\n')[0]) if os.path.exists('env/PRESENCE') else 0
TOPICLEN = int(open('env/TOPICLEN','rb').read().split('\n')[0]) if os.path.exists('env/TOPICLEN') else 512
CHANLIMIT = int(open('env/CHANLIMIT','rb').read().split('\n')[0]) if os.path.exists('env/CHANLIMIT') else 64
CHANNELLEN = int(open('env/CHANNELLEN','rb').read().split('\n')[0]) if os.path.exists('env/CHANNELLEN') else 64

PONG = int()
nick = str()
Nick = str()
flood = int()
seen = time.time()
ping = time.time()
user = str(os.getpid())
channel_struct = dict()
flood_expiry = time.time()
WAIT = PING << 10 if PING else 16384
channels = collections.deque([],CHANLIMIT)
motd = open('env/motd','rb').read().split('\n')
serv = open('env/serv','rb').read().split('\n')[0]

if URCDB:
  try: db = shelve.open(URCDB)
  except:
    os.remove(URCDB)
    db = shelve.open(URCDB)
  try: channel_struct = db['channel_struct']
  except: channel_struct = dict()
  while len(channel_struct) > CHANLIMIT: del channel_struct[channel_struct.keys()[0]]

for dst in channel_struct.keys():
  channel_struct[dst]['names'] = collections.deque(list(channel_struct[dst]['names']),CHANLIMIT)
  if channel_struct[dst]['topic']: channel_struct[dst]['topic'] = channel_struct[dst]['topic'][:TOPICLEN]

def sock_close(sn,sf):
  try: os.remove(str(os.getpid()))
  except: pass
  if sn:
    if URCDB:
      for dst in channels:
        if dst in channel_struct.keys() and nick in channel_struct[dst]['names']: channel_struct[dst]['names'].remove(nick)
      db['channel_struct'] = channel_struct
      db.close()
    sys.exit(0)

signal.signal(signal.SIGHUP,sock_close)
signal.signal(signal.SIGINT,sock_close)
signal.signal(signal.SIGTERM,sock_close)
signal.signal(signal.SIGCHLD,sock_close)

if os.access('stdin',1):
  p = subprocess.Popen(['./stdin'],stdout=subprocess.PIPE)
  rd = p.stdout.fileno()
  del p
else: rd = 0

if os.access('stdout',1):
  p = subprocess.Popen(['./stdout'],stdin=subprocess.PIPE)
  wr = p.stdin.fileno()
  del p
else: wr = 1

uid, gid = pwd.getpwnam('urcd')[2:4]
os.chdir(sys.argv[1])
os.chroot(os.getcwd())
os.setgid(gid)
os.setuid(uid)
root = os.getcwd()
del uid, gid

sock=socket.socket(socket.AF_UNIX,socket.SOCK_DGRAM)
sock_close(0,0)
sock.bind(str(os.getpid()))
sock.setblocking(0)
sd=sock.fileno()

poll=select.poll()
poll.register(rd,select.POLLIN|select.POLLPRI)
poll.register(sd,select.POLLIN)
poll=poll.poll

client_revents=select.poll()
client_revents.register(rd,select.POLLIN|select.POLLPRI)
client_revents=client_revents.poll

server_revents=select.poll()
server_revents.register(sd,select.POLLIN)
server_revents=server_revents.poll

def try_read(fd,buffer_len):
  try: return os.read(fd,buffer_len)
  except: sock_close(15,0)

def try_write(fd,buffer):
  try: return os.write(fd,buffer)
  except: sock_close(15,0)

def sock_write(buffer):
  for path in os.listdir(root):
    try:
      if path != user: sock.sendto(buffer,path)
    except: pass

while 1:

  poll(WAIT)
  now = time.time()

  if not client_revents(0):
    if now - seen >= TIMEOUT:
      if PRESENCE: sock_write(':'+Nick+'!'+Nick+'@'+serv+' QUIT :ETIMEDOUT\n')
      sock_close(15,0)
    if now - ping >= WAIT >> 10:
      if (PING and not PONG) or (not nick): sock_close(15,0)
      try_write(wr,'PING :'+user+'\n')
      ping = now

  else:
    time.sleep(LIMIT)
    buffer, seen, ping = str(), now, now

    while 1:
      byte = try_read(rd,1)
      if byte == '':
        if PRESENCE and Nick: sock_write(':'+Nick+'!'+Nick+'@'+serv+' QUIT :EOF\n')
        sock_close(15,0)
      if byte == '\n': break
      if byte != '\r' and len(buffer)<768: buffer += byte

    buffer = re_CHATZILLA('',buffer)
    buffer = re_MIRC('NICK ',buffer)

    if re_CLIENT_NICK(buffer):

      if not nick:
        Nick = buffer.split(' ',1)[1]
        nick = Nick.lower()

        if len(nick)>NICKLEN:
          try_write(wr,'ERROR : EMSGSIZE:NICKLEN='+str(NICKLEN)+'\n')
          continue

        try_write(wr,
          ':'+serv+' 001 '+Nick+' :'+serv+'\n'
          ':'+serv+' 002 '+Nick+' :'+Nick+'!'+user+'@'+serv+'\n'
          ':'+serv+' 003 '+Nick+' :'+serv+'\n'
          ':'+serv+' 004 '+Nick+' '+serv+' 0.0 + :+\n'
          ':'+serv+' 005 '+Nick+' NETWORK='+serv+' CHANTYPES=#&!+ CASEMAPPING=ascii CHANLIMIT='+str(CHANLIMIT)+' NICKLEN='+str(NICKLEN)+' TOPICLEN='+str(TOPICLEN)+' CHANNELLEN='+str(CHANNELLEN)+' COLOUR='+str(COLOUR)+' UNICODE='+str(UNICODE)+' PRESENCE='+str(PRESENCE)+':\n'
          ':'+serv+' 254 '+Nick+' '+str(CHANLIMIT)+' :CHANNEL(S)\n'
          ':'+Nick+'!'+user+'@'+serv+' MODE '+Nick
        )
        try_write(wr,' +\n') if PRESENCE else try_write(wr,' +i\n')
        try_write(wr,':'+serv+' 375 '+Nick+' :- '+serv+' MOTD -\n')
        for msg in motd: try_write(wr,':'+serv+' 372 '+Nick+' :- '+msg+'\n')
        try_write(wr,':'+serv+' 376 '+Nick+' :EOF MOTD\n')
        del motd
        continue

      src  = nick
      Nick = buffer.split(' ',1)[1]
      nick = Nick.lower()

      if len(nick)>NICKLEN:
        try_write(wr,'ERROR : EMSGSIZE:NICKLEN='+str(NICKLEN)+'\n')
        continue

      for dst in channel_struct.keys():
        if dst in channels:
          channel_struct[dst]['names'].remove(src)
          if nick in channel_struct[dst]['names']:
            if src != nick: try_write(wr,':'+Nick+'!'+user+'@'+serv+' KICK '+dst+' '+Nick+' :NICK\n')
          else: channel_struct[dst]['names'].append(nick)

      try_write(wr,':'+src+'!'+user+'@'+serv+' NICK '+Nick+'\n')

    elif re_CLIENT_USER(buffer): try_write(wr,'PING :'+user+'\n')

    elif re_CLIENT_PING_PONG(buffer):
      cmd, msg = re_SPLIT(buffer,2)[:2]
      if cmd.upper() == 'PING': try_write(wr,':'+serv+' PONG '+serv+' :'+msg+'\n')
      elif msg.upper() == user.upper(): PONG = 1

    elif not nick: pass

    elif re_CLIENT_PRIVMSG_NOTICE_TOPIC_PART(buffer):      

      if FLOOD:
        if now - flood_expiry >= FLOOD: flood = 0
        flood, flood_expiry = flood + 1, now
        if flood >= FLOOD: continue

      cmd, dst, msg = re_SPLIT(buffer,2)
      cmd = cmd.upper()
      dst = dst.lower()

      if dst[0] in ['#','&','!','+']:
        if len(dst)>CHANNELLEN:
          try_write(wr,'ERROR : EMSGSIZE:CHANNELLEN='+str(CHANNELLEN)+'\n')
          continue

      elif len(dst)>NICKLEN:
        try_write(wr,'ERROR : EMSGSIZE:NICKLEN='+str(NICKLEN)+'\n')
        continue

      if cmd == 'TOPIC':

        if len(msg)>TOPICLEN:
          try_write(wr,'ERROR : EMSGSIZE:TOPICLEN='+str(TOPICLEN)+'\n')
          continue

        try_write(wr,':'+Nick+'!'+user+'@'+serv+' '+cmd+' '+dst+' :'+msg+'\n')

        if dst[0] in ['#','&','!','+']:
          if not dst in channel_struct.keys(): channel_struct[dst] = dict(
            names = collections.deque([],CHANLIMIT),
            topic = msg,
          )
          else: channel_struct[dst]['topic'] = msg

      if cmd == 'PART':
        if dst in channels:
          try_write(wr,':'+Nick+'!'+user+'@'+serv+' '+cmd+' '+dst+' :'+msg+'\n')
          channels.remove(dst)
          channel_struct[dst]['names'].remove(nick)
        else: pass # return error to client?
        if not PRESENCE: continue

      sock_write(':'+Nick+'!'+Nick+'@'+serv+' '+cmd+' '+dst+' :'+msg+'\n')

    elif re_CLIENT_MODE_CHANNEL_ARG(buffer):
      dst = re_SPLIT(buffer,2)[1]
      try_write(wr,':'+serv+' 324 '+Nick+' '+dst+' +n\n')
      try_write(wr,':'+serv+' 329 '+Nick+' '+dst+' '+str(int(time.time()))+'\n')

    elif re_CLIENT_MODE_NICK(buffer):
      if PRESENCE: try_write(wr,':'+serv+' 221 '+re_SPLIT(buffer,2)[1]+' :+\n')
      else: try_write(wr,':'+serv+' 221 '+re_SPLIT(buffer,2)[1]+' :+i\n')

    elif re_CLIENT_MODE_NICK_ARG(buffer):
      if PRESENCE: try_write(wr,':'+Nick+'!'+user+'@'+serv+' MODE '+Nick+' +\n')
      else: try_write(wr,':'+Nick+'!'+user+'@'+serv+' MODE '+Nick+' +i\n')

    elif re_CLIENT_AWAY_OFF(buffer):
      try_write(wr,':'+serv+' 305 '+Nick+' :WB, :-)\n')

    elif re_CLIENT_AWAY_ON(buffer):
      try_write(wr,':'+serv+' 306 '+Nick+' :HB, :-)\n')

    elif re_CLIENT_WHO(buffer):
      dst = re_SPLIT(buffer,2)[1].lower()
      if dst in channel_struct.keys():
        for src in channel_struct[dst]['names']:
          try_write(wr,':'+serv+' 352 '+Nick+' '+dst+' '+src+' '+serv+' '+src+' '+src+' H :0 '+src+'\n')
      try_write(wr,':'+serv+' 315 '+Nick+' '+dst+' :EOF WHO\n')

    elif re_CLIENT_INVITE(buffer):

      dst, msg = re_SPLIT(buffer,2)[1:3]

      if len(dst)>NICKLEN:
        try_write(wr,'ERROR : EMSGSIZE:NICKLEN='+str(NICKLEN)+'\n')
        continue

      elif len(msg)>CHANNELLEN:
        try_write(wr,'ERROR : EMSGSIZE:CHANNELLEN='+str(CHANNELLEN)+'\n')
        continue

      try_write(wr,':'+serv+' 341 '+Nick+' '+dst+' '+msg+'\n')
      sock_write(':'+Nick+'!'+Nick+'@'+serv+' INVITE '+dst+' :'+msg+'\n')

    elif re_CLIENT_JOIN(buffer):

      for dst in re_SPLIT(buffer,2)[1].lower().split(','):

        if len(channels)>CHANLIMIT:
          try_write(wr,'ERROR : EMSGSIZE:CHANLIMIT='+str(CHANLIMIT)+'\n')
          continue

        if len(dst)>CHANNELLEN:
          try_write(wr,'ERROR : EMSGSIZE:CHANNELLEN='+str(CHANNELLEN)+'\n')
          continue

        if dst in channels: continue

        channels.append(dst)

        if not dst in channel_struct.keys(): channel_struct[dst] = dict(
          names = collections.deque([],CHANLIMIT),
          topic = None,
        )
        else:
          if nick in channel_struct[dst]['names']: channel_struct[dst]['names'].remove(nick)
          if channel_struct[dst]['topic']:
            try_write(wr,':'+serv+' 332 '+Nick+' '+dst+' :'+channel_struct[dst]['topic']+'\n')

        try_write(wr,':'+Nick+'!'+user+'@'+serv+' JOIN :'+dst+'\n')
        try_write(wr,':'+serv+' 353 '+Nick+' = '+dst+' :'+Nick+' ')
        for src in channel_struct[dst]['names']: try_write(wr,src+' ')
        try_write(wr,'\n')
        try_write(wr,':'+serv+' 366 '+Nick+' '+dst+' :EOF NAMES\n')

        if len(channel_struct[dst]['names'])==CHANLIMIT:
          try_write(wr,':'+channel_struct[dst]['names'][0]+'!'+channel_struct[dst]['names'][0]+'@'+serv+' PART '+dst+'\n')

        channel_struct[dst]['names'].append(nick)
        if PRESENCE: sock_write(':'+Nick+'!'+Nick+'@'+serv+' JOIN :'+dst+'\n')

    elif re_CLIENT_PART(buffer):
      for dst in re_SPLIT(buffer,2)[1].lower().split(','):
        if dst in channels:
          try_write(wr,':'+Nick+'!'+user+'@'+serv+' PART '+dst+' :\n')
          if PRESENCE: sock_write(':'+Nick+'!'+Nick+'@'+serv+' PART '+dst+' :\n')
          channels.remove(dst)
          channel_struct[dst]['names'].remove(nick)
        else: pass # return error to client ?

    elif re_CLIENT_LIST(buffer):

      try_write(wr,':'+serv+' 321 '+Nick+' channel :users name\n')

      for dst in channel_struct.keys():
        if len(channel_struct[dst]['names']):
          try_write(wr,':'+serv+' 322 '+Nick+' '+dst+' '+str(len(channel_struct[dst]['names']))+' :[+n] ')
          if channel_struct[dst]['topic']: try_write(wr,channel_struct[dst]['topic'])
          try_write(wr,'\n')

      try_write(wr,':'+serv+' 323 '+Nick+' :EOF LIST\n')

    elif re_CLIENT_QUIT(buffer):
      if PRESENCE: sock_write(':'+Nick+'!'+Nick+'@'+serv+' QUIT :'+re_SPLIT(buffer,1)[1]+'\n')
      sock_close(15,0)

    else:
      buffer = str({str():buffer})[6:-2].replace("\\'","'").replace('\\\\','\\')
      try_write(wr,':'+serv+' NOTICE '+Nick+' :ERROR: '+buffer+'\n')

  while server_revents(0):

    buffer = try_read(sd,1024).split('\n',1)[0]
    if not buffer: continue

    buffer = re_BUFFER_CTCP_DCC('',buffer) + '\x01' if '\x01ACTION ' in buffer.upper() else buffer.replace('\x01','')
    if not COLOUR: buffer = re_BUFFER_COLOUR('',buffer)
    if not UNICODE:
      buffer = codecs.ascii_encode(unicodedata.normalize('NFKD',unicode(buffer,'utf-8','replace')),'ignore')[0]
      buffer = ''.join(byte for byte in buffer if 127 > ord(byte) > 31 or byte in ['\x01','\x02','\x03','\x0f','\x1d','\x1f'])
    buffer += '\n'

    if re_SERVER_PRIVMSG_NOTICE_TOPIC_INVITE_PART(buffer):

      src = buffer.split(':',2)[1].split('!',1)[0].lower()
      if len(src)>NICKLEN: continue

      cmd, dst = re_SPLIT(buffer.lower(),3)[1:3]

      if dst[0] in ['#','&','!','+']:

        if len(dst)>CHANNELLEN: continue

        if not dst in channel_struct.keys():

          if len(channel_struct.keys())>=CHANLIMIT:

            for dst in channel_struct.keys():
              if not dst in channels:
                del channel_struct[dst]
                break

            dst = re_SPLIT(buffer,3)[2].lower()

          channel_struct[dst] = dict(
            names = collections.deque([],CHANLIMIT),
            topic = None,
          )

        if cmd == 'topic':
          msg = buffer.split(':',2)[2].split('\n',1)[0]
          if len(msg)>TOPICLEN: continue
          channel_struct[dst]['topic'] = msg

        if cmd == 'part':
          if src != nick:
            if src in channel_struct[dst]['names']:
              channel_struct[dst]['names'].remove(src)
              if dst in channels: try_write(wr,buffer)
          continue

        if src != nick and not src in channel_struct[dst]['names']:

          if dst in channels:

            try_write(wr,re_SPLIT(buffer,1)[0]+' JOIN :'+dst+'\n')

            if len(channel_struct[dst]['names'])==CHANLIMIT:

              if nick != channel_struct[dst]['names'][0]:
                try_write(wr,':'+channel_struct[dst]['names'][0]+'!'+channel_struct[dst]['names'][0]+'@'+serv+' PART '+dst+'\n')
              else:
                try_write(wr,':'+channel_struct[dst]['names'][1]+'!'+channel_struct[dst]['names'][1]+'@'+serv+' PART '+dst+'\n')
                channel_struct[dst]['names'].append(nick)

          channel_struct[dst]['names'].append(src)

      elif cmd == 'part': continue

      if dst == nick or dst in channels: try_write(wr,buffer)

    elif re_SERVER_JOIN(buffer):

      src = buffer.split(':',2)[1].split('!',1)[0].lower()
      if len(src)>NICKLEN: continue

      dst = buffer.split(':')[2].split('\n',1)[0].lower()
      if len(dst)>CHANNELLEN: continue

      if not dst in channel_struct.keys():

        if len(channel_struct.keys())>=CHANLIMIT:

          for dst in channel_struct.keys():
            if not dst in channels:
              del channel_struct[dst]
              break

          dst = buffer.split(':')[2].split('\n',1)[0].lower()

        channel_struct[dst] = dict(
          names = collections.deque([],CHANLIMIT),
          topic = None,
        )

      if src != nick and not src in channel_struct[dst]['names']:

        if dst in channels:

          try_write(wr,buffer)

          if len(channel_struct[dst]['names'])==CHANLIMIT:

            if nick != channel_struct[dst]['names'][0]:
              try_write(wr,':'+channel_struct[dst]['names'][0]+'!'+channel_struct[dst]['names'][0]+'@'+serv+' PART '+dst+'\n')
            else:
              try_write(wr,':'+channel_struct[dst]['names'][1]+'!'+channel_struct[dst]['names'][1]+'@'+serv+' PART '+dst+'\n')
              channel_struct[dst]['names'].append(nick)

        channel_struct[dst]['names'].append(src)

    elif re_SERVER_QUIT(buffer):

      src = buffer.split(':',2)[1].split('!',1)[0].lower()
      if src == nick: continue
      if len(src)>NICKLEN: continue

      cmd = '\x01'
      for dst in channel_struct.keys():

        if src in channel_struct[dst]['names']:

          channel_struct[dst]['names'].remove(src)

          if cmd == '\x01' and dst in channels:
            try_write(wr,buffer)
            cmd = '\x00'

    elif re_SERVER_KICK(buffer):

      dst, src = re_SPLIT(buffer.lower(),4)[2:4]

      if len(src)>NICKLEN: continue
      if len(dst)>CHANNELLEN: continue

      if not dst in channel_struct.keys():

        if len(channel_struct.keys())>=CHANLIMIT:

          for dst in channel_struct.keys():
            if not dst in channels:
              del channel_struct[dst]
              break

          dst = re_SPLIT(buffer,3)[2].lower()

        channel_struct[dst] = dict(
          names = collections.deque([],CHANLIMIT),
          topic = None,
        )

      if src != nick:
        dst = re_SPLIT(buffer,3)[2].lower()
        if src in channel_struct[dst]['names']:
          channel_struct[dst]['names'].remove(src)
          if dst in channels: try_write(wr,buffer)
