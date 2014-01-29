#!/usr/bin/env python
from errno import EAGAIN
import unicodedata
import collections
import subprocess
import codecs
import select
import socket
import signal
import shelve
import fcntl
import time
import pwd
import sys
import re
import os

RE = 'a-zA-Z0-9^(\)\-_{\}[\]|'
re_USER = re.compile('!\S+@',re.IGNORECASE).sub
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

### (deprecated) see http://anonet2.biz/URC#urc-integ ###
#re_URC_INTEG = re.compile(' \d{10,10} [a-fA-F0-9]{10,10} urc-integ$',re.IGNORECASE).sub

### strange values will likely yield strange results ###
PING = int(open('env/PING','rb').read().split('\n')[0]) if os.path.exists('env/PING') else 16
URCDB = open('env/URCDB','rb').read().split('\n')[0] if os.path.exists('env/URCDB') else str()
FLOOD = int(open('env/FLOOD','rb').read().split('\n')[0]) if os.path.exists('env/FLOOD') else 8
LIMIT = float(open('env/LIMIT','rb').read().split('\n')[0]) if os.path.exists('env/LIMIT') else 1
URCHUB = open('env/URCHUB','rb').read().split('\n')[0] if os.path.exists('env/URCHUB') else str()
COLOUR = int(open('env/COLOUR','rb').read().split('\n')[0]) if os.path.exists('env/COLOUR') else 0
UNICODE = int(open('env/UNICODE','rb').read().split('\n')[0]) if os.path.exists('env/UNICODE') else 0
NICKLEN = int(open('env/NICKLEN','rb').read().split('\n')[0]) if os.path.exists('env/NICKLEN') else 32
TIMEOUT = int(open('env/TIMEOUT','rb').read().split('\n')[0]) if os.path.exists('env/TIMEOUT') else 128
PRESENCE = int(open('env/PRESENCE','rb').read().split('\n')[0]) if os.path.exists('env/PRESENCE') else 0
URCSIGNDB = open('env/URCSIGNDB','rb').read().split('\n')[0] if os.path.exists('env/URCSIGNDB') else str()
TOPICLEN = int(open('env/TOPICLEN','rb').read().split('\n')[0]) if os.path.exists('env/TOPICLEN') else 512
CHANLIMIT = int(open('env/CHANLIMIT','rb').read().split('\n')[0]) if os.path.exists('env/CHANLIMIT') else 64
CHANNELLEN = int(open('env/CHANNELLEN','rb').read().split('\n')[0]) if os.path.exists('env/CHANNELLEN') else 64
URCSECRETBOXDIR = open('env/URCSECRETBOXDIR','rb').read().split('\n')[0] if os.path.exists('env/URCSECRETBOXDIR') else str()
URCSIGNSECKEYDIR = open('env/URCSIGNSECKEYDIR','rb').read().split('\n')[0] if os.path.exists('env/URCSIGNSECKEYDIR') else str()
URCSIGNPUBKEYDIR = open('env/URCSIGNPUBKEYDIR','rb').read().split('\n')[0] if os.path.exists('env/URCSIGNPUBKEYDIR') else str()
URCSIGNSECKEY = open('env/URCSIGNSECKEY','rb').read().split('\n')[0].decode('hex') if os.path.exists('env/URCSIGNSECKEY') else str()

nick = str()
Nick = str()
now = time.time()
user = str(os.getpid())
channel_struct = dict() ### operations assume nick is in channel_struct[dst]['names'] if dst in channels ###
channels = collections.deque([],CHANLIMIT)
bytes = [(chr(i),i) for i in xrange(0,256)]
motd = open('env/motd','rb').read().split('\n')
serv = open('env/serv','rb').read().split('\n')[0]
PONG, PINGWAIT, POLLWAIT = int(), PING, PING << 10
active_clients = collections.deque(['']*CHANLIMIT*CHANLIMIT,CHANLIMIT*CHANLIMIT)
flood, seen, ping, sync, flood_expiry = FLOOD, now, now, now, now

if URCDB:
  try: db = shelve.open(URCDB)
  except:
    os.remove(URCDB)
    db = shelve.open(URCDB)
  try: active_clients = collections.deque(list(db['active_clients']),CHANLIMIT*CHANLIMIT)
  except: pass
  try: channel_struct = db['channel_struct']
  except: channel_struct = dict()
  while len(channel_struct) > CHANLIMIT: del channel_struct[channel_struct.keys()[0]]

if URCSECRETBOXDIR or URCSIGNDB or URCSIGNSECKEY or URCSIGNSECKEYDIR or URCSIGNPUBKEYDIR:
  from nacltaia import *

  ### NaCl's crypto_sign / crypto_sign_open API sucks ###
  def _crypto_sign(m,sk):
    s = crypto_sign(m,sk)
    return s[:32]+s[-32:]

  def _crypto_sign_open(m,s,pk):
    return 1 if crypto_sign_open(s[:32]+m+s[32:],pk) != 0 else 0

if URCSECRETBOXDIR:
  urcsecretboxdb = dict()
  for dst in os.listdir(URCSECRETBOXDIR):
    urcsecretboxdb[dst.lower()] = open(URCSECRETBOXDIR+'/'+dst,'rb').read(64).decode('hex')

if URCSIGNPUBKEYDIR:
  urcsignpubkeydb = dict()
  for dst in os.listdir(URCSIGNPUBKEYDIR):
    dst = dst.lower()
    urcsignpubkeydb[dst] = dict()
    for src in os.listdir(URCSIGNPUBKEYDIR+'/'+dst):
      urcsignpubkeydb[dst][src.lower()] = open(URCSIGNPUBKEYDIR+'/'+dst+'/'+src,'rb').read(64).decode('hex')

if URCSIGNSECKEYDIR:
  urcsignseckeydb = dict()
  for dst in os.listdir(URCSIGNSECKEYDIR):
    urcsignseckeydb[dst.lower()] = open(URCSIGNSECKEYDIR+'/'+dst,'rb').read(128).decode('hex')

if URCSIGNDB:
  urcsigndb = dict()
  for src in os.listdir(URCSIGNDB):
    urcsigndb[src.lower()] = open(URCSIGNDB+'/'+src,'rb').read(64).decode('hex')

for dst in channel_struct.keys():
  channel_struct[dst]['names'] = collections.deque(list(channel_struct[dst]['names']),CHANLIMIT)
  if channel_struct[dst]['topic']: channel_struct[dst]['topic'] = channel_struct[dst]['topic'][:TOPICLEN]
  for src in channel_struct[dst]['names']: active_clients.append(src)

def sock_close(sn,sf):
  try: os.remove(str(os.getpid()))
  except: pass
  if sn:
    if URCDB:
      for dst in channels:
        if dst in channel_struct.keys() and nick in channel_struct[dst]['names']:
          channel_struct[dst]['names'].remove(nick)
      db['channel_struct'] = channel_struct
      db['active_clients'] = active_clients
      db.close()
    sys.exit(0)

signal.signal(signal.SIGHUP,sock_close)
signal.signal(signal.SIGINT,sock_close)
signal.signal(signal.SIGTERM,sock_close)
signal.signal(signal.SIGCHLD,sock_close)

if os.access('stdin',os.X_OK):
  p = subprocess.Popen(['./stdin'],stdout=subprocess.PIPE)
  rd = p.stdout.fileno()
  del p
else: rd = 0

if os.access('stdout',os.X_OK):
  p = subprocess.Popen(['./stdout'],stdin=subprocess.PIPE)
  wr = p.stdin.fileno()
  del p
else: wr = 1

### nacl-20110221's randombytes() not compatible with chroot ###
devurandomfd = os.open("/dev/urandom",os.O_RDONLY)
def randombytes(n): return try_read(devurandomfd,n)

uid, gid = pwd.getpwnam('urcd')[2:4]
os.chdir(URCHUB) if URCHUB else os.chdir(sys.argv[1])
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

### python doesn't have a way of testing pollfd.revents ###
client_revents=select.poll()
client_revents.register(rd,select.POLLIN|select.POLLPRI)
client_revents=client_revents.poll

server_revents=select.poll()
server_revents.register(sd,select.POLLIN)
server_revents=server_revents.poll

fcntl.fcntl(rd,fcntl.F_SETFL,fcntl.fcntl(wr,fcntl.F_GETFL)|os.O_NONBLOCK)
fcntl.fcntl(wr,fcntl.F_SETFL,fcntl.fcntl(wr,fcntl.F_GETFL)|os.O_NONBLOCK)

def try_read(fd,buflen):
  try: return os.read(fd,buflen)
  except OSError as ex:
    if ex.errno != EAGAIN: sock_close(15,0)
  return str()

def try_write(fd,buffer):
  while buffer:
    try: buffer = buffer[os.write(fd,buffer):]
    except OSError as ex:
      if ex.errno != EAGAIN: sock_close(15,0)
    if buffer:
      if time.time() - now >= TIMEOUT: sock_close(15,0)
      time.sleep(1)


def taia96n_now(): return { ### version of taia96n_now is randomized by +/- 4 seconds ###
  'sec':4611686018427387914L+long(now+[-1,-2,-3,-4,1,2,3,4][ord(randombytes(1))%8]),
  'nano':long(1000000000*(now%1)+500)
}

def tai_pack(s): return chr(s['sec']>>56&255)+chr(s['sec']>>48&255)+chr(s['sec']>>40&255)+chr(s['sec']>>32&255)+chr(s['sec']>>24&255)+chr(s['sec']>>16&255)+chr(s['sec']>>8&255)+chr(s['sec']&255)

def taia96n_pack(s): return tai_pack(s)+chr(s['nano']>>24&255)+chr(s['nano']>>16&255)+chr(s['nano']>>8&255)+chr(s['nano']&255)

def sock_write(*argv): ### (buffer, dst, ...) ###
  buffer = argv[0]
  buflen = len(buffer)
  dst = argv[1].lower() if len(argv) > 1 else str()

  if URCSIGNSECKEYDIR and dst and dst in urcsignseckeydb.keys(): signseckey = urcsignseckeydb[dst]
  elif URCSIGNSECKEY: signseckey = URCSIGNSECKEY
  else: signseckey = str()

  if URCSECRETBOXDIR and dst and dst in urcsecretboxdb.keys(): seckey = urcsecretboxdb[dst]
  else: seckey = str()

  ### URCSIGNSECRETBOX ###
  if seckey and signseckey:
    buflen += 64 + 16
    nonce = taia96n_pack(taia96n_now())+'\x03\x00\x00\x00'+randombytes(8)
    buffer = chr(buflen>>8)+chr(buflen%256)+nonce+buffer
    buffer += _crypto_sign(buffer,signseckey)
    buffer = buffer[:2+12+4+8]+crypto_secretbox(buffer[2+12+4+8:],nonce,seckey)

  ### URCSECRETBOX ###
  elif seckey:
    buflen += 16
    nonce = taia96n_pack(taia96n_now())+'\x02\x00\x00\x00'+randombytes(8)
    buffer = chr(buflen>>8)+chr(buflen%256)+nonce+crypto_secretbox(buffer,nonce,seckey)

  ### URCSIGN ###
  elif signseckey:
    buflen += 64
    buffer = chr(buflen>>8)+chr(buflen%256)+taia96n_pack(taia96n_now())+'\x01\x00\x00\x00'+randombytes(8)+buffer
    buffer += _crypto_sign(buffer,signseckey)

  ### URCHUB ###
  else: buffer = chr(buflen>>8)+chr(buflen%256)+taia96n_pack(taia96n_now())+'\x00\x00\x00\x00'+randombytes(8)+buffer

  try: sock.sendto(buffer,'hub')
  except: pass

while 1:

  poll(POLLWAIT)

  for i in xrange(0,int(time.time() - now)):
    if active_clients: active_clients.append('')

  now = time.time()

  while flood and now - flood_expiry >= FLOOD:
    flood_expiry += FLOOD
    flood -= 1

  if now - sync >= TIMEOUT:
    for dst in channel_struct.keys():
      names = list(channel_struct[dst]['names'])
      for src in names:
        if src != nick and not src in active_clients:
          if dst in channels: try_write(wr,':'+src+'!URCD@'+serv+' QUIT :IDLE\n')
          for dst in channel_struct.keys():
            if src in channel_struct[dst]['names']: channel_struct[dst]['names'].remove(src)
      del names
    if URCDB: db.sync()
    sync = now

  if not client_revents(0):
    if now - seen >= TIMEOUT:
      if PRESENCE: sock_write(':'+Nick+'!'+Nick+'@'+serv+' QUIT :ETIMEDOUT\n',dst)
      sock_close(15,0)
    if now - ping >= PINGWAIT:
      if (PING and not PONG) or (not nick): sock_close(15,0)
      try_write(wr,'PING :'+user+'\n')
      ping = now

  else:
    time.sleep(LIMIT)
    buffer, seen, ping = str(), now, now

    while 1: ### python really sucks at this ###
      if now - seen >= TIMEOUT:
        if PRESENCE and Nick: sock_write(':'+Nick+'!'+Nick+'@'+serv+' QUIT :EOF\n',dst)
        sock_close(15,0)
      byte = try_read(rd,1)
      if byte == '':
        if client_revents(0): sock_close(15,0)
        time.sleep(1)
      if byte == '\n': break
      if byte != '\r' and len(buffer)<768: buffer += byte
    buffer = re_CHATZILLA('',re_MIRC('NICK ',buffer)) ### workaround ChatZilla and mIRC ###

    if re_CLIENT_NICK(buffer):
      if not nick:
        Nick = buffer.split(' ',1)[1]
        nick = Nick.lower()
        if len(nick)>NICKLEN:
          try_write(wr,':'+serv+' 432 '+Nick+' :ERR_ERRONEUSNICKNAME\n')
          Nick, nick = str(), str()
          continue
        msg = ' +' if PRESENCE else ' +i'
        try_write(wr,
          ':'+serv+' 001 '+Nick+' :'+serv+'\n'
          ':'+serv+' 002 '+Nick+' :'+Nick+'!'+user+'@'+serv+'\n'
          ':'+serv+' 003 '+Nick+' :'+serv+'\n'
          ':'+serv+' 004 '+Nick+' '+serv+' 0.0 + :+\n'
          ':'+serv+' 005 '+Nick+' NETWORK='+serv+' CHANTYPES=#&!+ CASEMAPPING=ascii CHANLIMIT='+str(CHANLIMIT)+' NICKLEN='+str(NICKLEN)+' TOPICLEN='+str(TOPICLEN)+' CHANNELLEN='+str(CHANNELLEN)+' COLOUR='+str(COLOUR)+' UNICODE='+str(UNICODE)+' PRESENCE='+str(PRESENCE)+':\n'
          ':'+serv+' 254 '+Nick+' '+str(CHANLIMIT)+' :CHANNEL(S)\n'
          ':'+Nick+'!'+user+'@'+serv+' MODE '+Nick+msg+'\n'
          ':'+serv+' 375 '+Nick+' :- '+serv+' MOTD -\n'
        )
        for msg in motd: try_write(wr,':'+serv+' 372 '+Nick+' :- '+msg+'\n')
        try_write(wr,':'+serv+' 376 '+Nick+' :RPL_ENDOFMOTD\n')
        del motd
        continue
      src = Nick ### some versions of AndChat do not support CASEMAPPING ###
      Nick = buffer.split(' ',1)[1]
      nick = Nick.lower()
      if len(nick)>NICKLEN:
        try_write(wr,':'+serv+' 432 '+Nick+' :ERR_ERRONEUSNICKNAME\n')
        Nick, nick = src, src.lower()
        continue
      for dst in channel_struct.keys():
        if dst in channels:
          channel_struct[dst]['names'].remove(src.lower())
          if nick in channel_struct[dst]['names']:
            if src.lower() != nick:
              try_write(wr,':'+Nick+'!'+user+'@'+serv+' KICK '+dst+' '+Nick+' :NICK\n')
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
        flood += 1
        if flood >= FLOOD:
          try_write(wr,':'+serv+' NOTICE '+Nick+' :RPL_SPAM\n')
          continue
      cmd, dst, msg = re_SPLIT(buffer,2)
      cmd = cmd.upper()
      dst = dst.lower()
      if dst[0] in ['#','&','!','+']:
        if len(dst)>CHANNELLEN:
          try_write(wr,':'+serv+' 403 '+Nick+' :ERR_NOSUCHCHANNEL\n')
          continue
      elif len(dst)>NICKLEN:
        try_write(wr,':'+serv+' 401 '+Nick+' :ERR_NOSUCHNICK\n')
        continue
      if cmd == 'TOPIC':
        try_write(wr,':'+Nick+'!'+user+'@'+serv+' '+cmd+' '+dst+' :'+msg[:TOPICLEN]+'\n')
        if dst in channel_struct.keys(): channel_struct[dst]['topic'] = msg[:TOPICLEN]
      if cmd == 'PART':
        if dst in channels:
          try_write(wr,':'+Nick+'!'+user+'@'+serv+' '+cmd+' '+dst+' :'+msg+'\n')
          channels.remove(dst)
          channel_struct[dst]['names'].remove(nick)
        else: try_write(wr,':'+serv+' 442 '+Nick+' '+dst+' :ERR_NOTONCHANNEL\n')
        if not PRESENCE: continue
      sock_write(':'+Nick+'!'+Nick+'@'+serv+' '+cmd+' '+dst+' :'+msg+'\n',dst)

    elif re_CLIENT_MODE_CHANNEL_ARG(buffer):
      dst = re_SPLIT(buffer,2)[1]
      if URCSECRETBOXDIR and dst.lower() in urcsecretboxdb.keys():
        try_write(wr,':'+serv+' 324 '+Nick+' '+dst+' +kns\n')
      else: try_write(wr,':'+serv+' 324 '+Nick+' '+dst+' +n\n')
      try_write(wr,':'+serv+' 329 '+Nick+' '+dst+' '+str(int(now))+'\n')

    elif re_CLIENT_MODE_NICK(buffer):
      if PRESENCE: try_write(wr,':'+serv+' 221 '+re_SPLIT(buffer,2)[1]+' :+\n')
      else: try_write(wr,':'+serv+' 221 '+re_SPLIT(buffer,2)[1]+' :+i\n')

    elif re_CLIENT_MODE_NICK_ARG(buffer):
      if PRESENCE: try_write(wr,':'+Nick+'!'+user+'@'+serv+' MODE '+Nick+' +\n')
      else: try_write(wr,':'+Nick+'!'+user+'@'+serv+' MODE '+Nick+' +i\n')

    ### IRC does not provide AWAY broadcast ###
    elif re_CLIENT_AWAY_OFF(buffer):
      try_write(wr,':'+serv+' 305 '+Nick+' :RPL_UNAWAY\n')

    elif re_CLIENT_AWAY_ON(buffer):
      try_write(wr,':'+serv+' 306 '+Nick+' :RPL_AWAY\n')

    elif re_CLIENT_WHO(buffer):
      dst = re_SPLIT(buffer,2)[1].lower()
      if dst in channel_struct.keys():
        for src in channel_struct[dst]['names']:
          try_write(wr,':'+serv+' 352 '+Nick+' '+dst+' '+src+' '+serv+' '+src+' '+src+' H :0 '+src+'\n')
      try_write(wr,':'+serv+' 315 '+Nick+' '+dst+' :RPL_ENDOFWHO\n')

    elif re_CLIENT_INVITE(buffer):
      dst, msg = re_SPLIT(buffer,2)[1:3]
      if len(dst)>NICKLEN:
        try_write(wr,':'+serv+' 401 '+Nick+' :ERR_NOSUCHNICK\n')
        continue
      elif len(msg)>CHANNELLEN:
        try_write(wr,':'+serv+' 403 '+Nick+' :ERR_NOSUCHCHANNEL\n')
        continue
      try_write(wr,':'+serv+' 341 '+Nick+' '+dst+' '+msg+'\n')
      sock_write(':'+Nick+'!'+Nick+'@'+serv+' INVITE '+dst+' :'+msg+'\n',dst)

    elif re_CLIENT_JOIN(buffer):
      for dst in re_SPLIT(buffer,2)[1].lower().split(','):
        if len(channels)>CHANLIMIT:
          try_write(wr,':'+serv+' 405 '+Nick+' :ERR_TOOMANYCHANNELS\n')
          continue
        if len(dst)>CHANNELLEN:
          try_write(wr,':'+serv+' 403 '+Nick+' :ERR_NOSUCHCHANNEL\n')
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
        try_write(wr,
          ':'+Nick+'!'+user+'@'+serv+' JOIN :'+dst+'\n'
          ':'+serv+' 353 '+Nick+' = '+dst+' :'+Nick+' '
        )
        for src in channel_struct[dst]['names']: try_write(wr,src+' ')
        try_write(wr,'\n:'+serv+' 366 '+Nick+' '+dst+' :RPL_ENDOFNAMES\n')
        if len(channel_struct[dst]['names'])>=CHANLIMIT:
          try_write(wr,':'+channel_struct[dst]['names'][0]+'!URCD@'+serv+' PART '+dst+'\n')
        channel_struct[dst]['names'].append(nick)
        if PRESENCE: sock_write(':'+Nick+'!'+Nick+'@'+serv+' JOIN :'+dst+'\n',dst)

    elif re_CLIENT_PART(buffer):
      for dst in re_SPLIT(buffer,2)[1].lower().split(','):
        if dst in channels:
          try_write(wr,':'+Nick+'!'+user+'@'+serv+' PART '+dst+' :\n')
          if PRESENCE: sock_write(':'+Nick+'!'+Nick+'@'+serv+' PART '+dst+' :\n',dst)
          channels.remove(dst)
          channel_struct[dst]['names'].remove(nick)
        else: try_write(wr,':'+serv+' 442 '+Nick+' '+dst+' :ERR_NOTONCHANNEL\n')

    elif re_CLIENT_LIST(buffer):
      try_write(wr,':'+serv+' 321 '+Nick+' CHANNELS :USERS NAMES\n')
      for dst in channel_struct.keys():
        if channel_struct[dst]['names']:
          try_write(wr,':'+serv+' 322 '+Nick+' '+dst+' '+str(len(channel_struct[dst]['names']))+' :[+n] ')
          if channel_struct[dst]['topic']: try_write(wr,channel_struct[dst]['topic'])
          try_write(wr,'\n')
      try_write(wr,':'+serv+' 323 '+Nick+' :RPL_LISTEND\n')

    elif re_CLIENT_QUIT(buffer):
      if PRESENCE: sock_write(':'+Nick+'!'+Nick+'@'+serv+' QUIT :'+re_SPLIT(buffer,1)[1]+'\n',dst)
      sock_close(15,0)

    ### implement new re_CLIENT_CMD's here ###

    ### ERR_UKNOWNCOMMAND ###
    else: try_write(wr,':'+serv+' 421 '+str({str():buffer})[6:-2].replace("\\'","'").replace('\\\\','\\')+'\n')

  while server_revents(0) and not client_revents(0):

    buffer = try_read(sd,2+12+4+8+1024)

    ### URCSIGN ###
    if buffer[2+12:2+12+4] == '\x01\x00\x00\x00':
      buflen = len(buffer)
      try:
        src, cmd, dst = re_SPLIT(buffer[2+12+4+8+1:].lower(),3)[:3]
        src = src.split('!',1)[0]
      except: src, cmd, dst = buffer[2+12+4+8+1:].split('!',1)[0].lower(), str(), str()

      if URCSIGNPUBKEYDIR \
      and dst in urcsignpubkeydb.keys() \
      and src in urcsignpubkeydb[dst].keys():
        try:
          if _crypto_sign_open(buffer[:buflen-64],buffer[-64:],urcsignpubkeydb[dst][src]):
            buffer = re_USER('!VERIFIED@',buffer[2+12+4+8:].split('\n',1)[0],1)
          else: buffer = re_USER('!URCD@',buffer[2+12+4+8:].split('\n',1)[0],1)
        except: buffer = re_USER('!URCD@',buffer[2+12+4+8:].split('\n',1)[0],1)
      elif URCSIGNDB:
        try:
          if _crypto_sign_open(buffer[:buflen-64],buffer[-64:],urcsigndb[src]):
            buffer = re_USER('!VERIFIED@',buffer[2+12+4+8:].split('\n',1)[0],1)
          else: buffer = re_USER('!URCD@',buffer[2+12+4+8:].split('\n',1)[0],1)
        except: buffer = re_USER('!URCD@',buffer[2+12+4+8:].split('\n',1)[0],1)
      else: buffer = re_USER('!URCD@',buffer[2+12+4+8:].split('\n',1)[0],1)

    ### URCSECRETBOX ###
    elif buffer[2+12:2+12+4] == '\x02\x00\x00\x00':
      if not URCSECRETBOXDIR: continue
      for seckey in urcsecretboxdb.values():
        msg = crypto_secretbox_open(buffer[2+12+4+8:],buffer[2:2+12+4+8],seckey)
        if msg: break
      if not msg: continue
      buffer = re_USER('!URCD@',msg.split('\n',1)[0],1)

    ### URCSIGNSECRETBOX ###
    elif buffer[2+12:2+12+4] == '\x03\x00\x00\x00':
      if not URCSECRETBOXDIR: continue
      for seckey in urcsecretboxdb.values():
        msg = crypto_secretbox_open(buffer[2+12+4+8:],buffer[2:2+12+4+8],seckey)
        if msg: break
      if not msg: continue

      buffer = buffer[:2+12+4+8]+msg
      buflen = len(buffer)
      try:
        src, cmd, dst = re_SPLIT(buffer[2+12+4+8+1:].lower(),3)[:3]
        src = src.split('!',1)[0]
      except: src, cmd, dst = buffer[2+12+4+8+1:].split('!',1)[0].lower(), str(), str()

      if URCSIGNPUBKEYDIR \
      and dst in urcsignpubkeydb.keys() \
      and src in urcsignpubkeydb[dst].keys():
        try:
          if _crypto_sign_open(buffer[:buflen-64],buffer[-64:],urcsignpubkeydb[dst][src]):
            buffer = re_USER('!VERIFIED@',buffer[2+12+4+8:].split('\n',1)[0],1)
          else: buffer = re_USER('!URCD@',buffer[2+12+4+8:].split('\n',1)[0],1)
        except: buffer = re_USER('!URCD@',buffer[2+12+4+8:].split('\n',1)[0],1)
      elif URCSIGNDB:
        try:
          if _crypto_sign_open(buffer[:buflen-64],buffer[-64:],urcsigndb[src]):
            buffer = re_USER('!VERIFIED@',buffer[2+12+4+8:].split('\n',1)[0],1)
          else: buffer = re_USER('!URCD@',buffer[2+12+4+8:].split('\n',1)[0],1)
        except: buffer = re_USER('!URCD@',buffer[2+12+4+8:].split('\n',1)[0],1)
      else: buffer = re_USER('!URCD@',buffer[2+12+4+8:].split('\n',1)[0],1)

    ### URCHUB ###
    else: buffer = re_USER('!URCD@',buffer[2+12+4+8:].split('\n',1)[0],1)

    server_revents(ord(randombytes(1))<<4) ### may reduce some side channels ###

    #buffer = re_URC_INTEG('',buffer) ### (deprecated) see http://anonet2.biz/URC#urc-integ ###
    buffer = re_BUFFER_CTCP_DCC('',buffer) + '\x01' if '\x01ACTION ' in buffer.upper() else buffer.replace('\x01','')
    if not COLOUR: buffer = re_BUFFER_COLOUR('',buffer)
    if not UNICODE:
      buffer = codecs.ascii_encode(unicodedata.normalize('NFKD',unicode(buffer,'utf-8','replace')),'ignore')[0]
      buffer = ''.join(byte for byte in buffer if 127 > ord(byte) > 31 or byte in ['\x01','\x02','\x03','\x0f','\x1d','\x1f'])
    buffer += '\n'

    if re_SERVER_PRIVMSG_NOTICE_TOPIC_INVITE_PART(buffer):
      src = buffer.split(':',2)[1].split('!',1)[0].lower()
      if len(src)>NICKLEN: continue
      active_clients.append(src)
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
        if cmd == 'topic': channel_struct[dst]['topic'] = buffer.split(':',2)[2].split('\n',1)[0][:TOPICLEN]
        if cmd == 'part':
          if src != nick:
            if src in channel_struct[dst]['names']:
              channel_struct[dst]['names'].remove(src)
              if dst in channels: try_write(wr,buffer)
          continue
        if src != nick and not src in channel_struct[dst]['names']:
          if dst in channels:
            try_write(wr,re_SPLIT(buffer,1)[0]+' JOIN :'+dst+'\n')
            if len(channel_struct[dst]['names'])>=CHANLIMIT:
              if nick != channel_struct[dst]['names'][0]:
                try_write(wr,':'+channel_struct[dst]['names'][0]+'!URCD@'+serv+' PART '+dst+'\n')
              else:
                try_write(wr,':'+channel_struct[dst]['names'][1]+'!URCD@'+serv+' PART '+dst+'\n')
                channel_struct[dst]['names'].append(nick)
          channel_struct[dst]['names'].append(src)
      elif cmd == 'part': continue
      if dst == nick or dst in channels: try_write(wr,buffer)

    elif re_SERVER_JOIN(buffer):
      src = buffer.split(':',2)[1].split('!',1)[0].lower()
      if len(src)>NICKLEN: continue
      active_clients.append(src)
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
          if len(channel_struct[dst]['names'])>=CHANLIMIT:
            if nick != channel_struct[dst]['names'][0]:
              try_write(wr,':'+channel_struct[dst]['names'][0]+'!URCD@'+serv+' PART '+dst+'\n')
            else:
              try_write(wr,':'+channel_struct[dst]['names'][1]+'!URCD@'+serv+' PART '+dst+'\n')
              channel_struct[dst]['names'].append(nick)
        channel_struct[dst]['names'].append(src)

    elif re_SERVER_QUIT(buffer):
      src = buffer.split(':',2)[1].split('!',1)[0].lower()
      if src == nick or len(src)>NICKLEN: continue
      cmd = '\x01'
      for dst in channel_struct.keys():
        if src in channel_struct[dst]['names']:
          channel_struct[dst]['names'].remove(src)
          if cmd == '\x01' and dst in channels:
            try_write(wr,buffer)
            cmd = '\x00'
      while src in active_clients: active_clients.remove(src)

    elif re_SERVER_KICK(buffer):
      dst, src = re_SPLIT(buffer.lower(),4)[2:4]
      if len(src)>NICKLEN or len(dst)>CHANNELLEN: continue
      while src in active_clients: active_clients.remove(src)
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
