#!/usr/bin/env python
# urc2server_rfc1459 v0.1
# dirty code, you have been warned
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
from hashlib import sha1

if not os.path.exists('env/LINKNAME') or not os.path.exists('env/LINKPASS'):
  exit(525)

LINKNAME = open('env/LINKNAME','rb').read().split('\n')[0]
LINKPASS = open('env/LINKPASS','rb').read().split('\n')[0]
RE = 'a-zA-Z0-9^(\)\-_{\}[\]|.'
re_SPLIT = re.compile(' +',re.IGNORECASE).split
re_LINK_NICK = re.compile('^NICK ['+RE+']+ :.*$', re.IGNORECASE).search
re_LINK_KILL = re.compile('^KILL ['+RE+']+ :.*$', re.IGNORECASE).search
re_LINK_PRIVMSG_NOTICE_TOPIC = re.compile('^:['+RE+']+!urc2serverRFC1459@' + LINKNAME + ' ((PRIVMSG)|(NOTICE)|(TOPIC)) [&#]['+RE+']+ :.*$',re.IGNORECASE).search
re_LINK_PRIVMSG_PRIVATE = re.compile('^:['+RE+']+!urc2serverRFC1459@' + LINKNAME + ' ((PRIVMSG)|(NOTICE)|(TOPIC)) ['+RE+']+ :.*$',re.IGNORECASE).search
re_LINK_PART = re.compile('^:['+RE+']+!urc2serverRFC1459@' + LINKNAME + ' PART [&#]['+RE+']+( :)?',re.IGNORECASE).search
re_LINK_QUIT = re.compile('^:['+RE+']+!urc2serverRFC1459@' + LINKNAME + ' QUIT( :)?',re.IGNORECASE).search
#re_LINK_PING = re.compile('^PING :?.+$',re.IGNORECASE).search
re_LINK_JOIN = re.compile('^:['+RE+']+!urc2serverRFC1459@' + LINKNAME + ' JOIN [&#]['+RE+']+$',re.IGNORECASE).search
re_LINK_KICK = re.compile('^:.+ KICK [&#]['+RE+']+ ['+RE+']+',re.IGNORECASE).search
re_BUFFER_CTCP_DCC = re.compile('\x01(?!ACTION )',re.IGNORECASE).sub
re_BUFFER_COLOUR = re.compile('(\x03[0-9][0-9]?((?<=[0-9]),[0-9]?[0-9]?)?)|[\x02\x03\x0f\x1d\x1f]',re.IGNORECASE).sub
re_URC_PRIVMSG_NOTICE_TOPIC = re.compile('^:['+RE+']+![~'+RE+']+@['+RE+']+ ((PRIVMSG)|(NOTICE)|(TOPIC)) [#&]['+RE+']+ :.*$',re.IGNORECASE).search
re_URC_PRIVMSG_PRIVATE = re.compile('^:['+RE+']+![~'+RE+']+@['+RE+']+ ((PRIVMSG)|(NOTICE)|(TOPIC)) ['+RE+']+ :.*$',re.IGNORECASE).search
re_URC_JOIN = re.compile('^:['+RE+']+![~'+RE+']+@['+RE+']+ JOIN :[&#]['+RE+']+.*$', re.IGNORECASE).search
re_URC_PART = re.compile('^:['+RE+']+![~'+RE+'.]+@['+RE+'.]+ PART [&#]['+RE+']+.*$',re.IGNORECASE).search
re_URC_QUIT = re.compile('^:['+RE+']+![~'+RE+'.]+@['+RE+'.]+ QUIT :.*$',re.IGNORECASE).search
re_LINK_INTERNAL = re.compile('^:'+LINKNAME+' ',re.IGNORECASE).sub

LIMIT = float(open('env/LIMIT','rb').read().split('\n')[0]) if os.path.exists('env/LIMIT') else 1
COLOUR = int(open('env/COLOUR','rb').read().split('\n')[0]) if os.path.exists('env/COLOUR') else 0
UNICODE = int(open('env/UNICODE','rb').read().split('\n')[0]) if os.path.exists('env/UNICODE') else 0
DEBUG = int(open('env/DEBUG','rb').read().split('\n')[0]) if os.path.exists('env/DEBUG') else 0 
PRESENCE = int(open('env/PRESENCE','rb').read().split('\n')[0]) if os.path.exists('env/PRESENCE') else 0 


user = str(os.getpid())
def sock_close(sn,sf):
  try:
    os.remove(str(os.getpid()))
  except:
    pass
  if sn: sys.exit(0)

signal.signal(signal.SIGHUP,sock_close)
signal.signal(signal.SIGINT,sock_close)
signal.signal(signal.SIGTERM,sock_close)
signal.signal(signal.SIGCHLD,sock_close)

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
  try:
    return os.read(fd,buffer_len)
  except:
    sock_close(15,0)

def try_write(fd,buffer):
  try:
    os.write(fd,buffer)
    os.write(2,'[out] ' + buffer)
  except:
    sock_close(15,0)

def sock_write(buffer):
  #os.write(2,'[sockwrite] ' + buffer)
  buffer = buffer[:-1] + ' ' + str(int(time.time()))
  check = sha1(buffer).hexdigest()[:10]
  buffer = buffer + ' ' + check + ' urc-integ\n'
  for path in os.listdir(root):
    try:
      if path != user: sock.sendto(buffer,path)
    except:
      pass

try_write(wr,
  'PASS ' + LINKPASS + '\n'
  'SERVER urc2serverLocal 1\n'
)


nicks=dict()
tmpNicks=dict()
localnicks=list()
channels=list()
lastCheck = time.time()
inactiveInterval = 3 * 60 * 60
while 1:
  now = time.time()
  if now - lastCheck > 60:
    #os.write(2,'checking for inactivity..\n')
    tmpNicks=dict()
    for nick in nicks:
      if now - nicks[nick][1] > inactiveInterval:
        try_write(wr, ':' + nicks[nick][0] + ' QUIT :Inactivity (3 hours)\n')
        if DEBUG: try_write(wr, ':urc2server PRIVMSG #status :nick removed because of inactivity: ' + nicks[nick][0] + '\n')
      else:
        tmpNicks[nick] = nicks[nick]
    nicks = tmpNicks
    lastCheck = now
  poll(-1)

  if client_revents(0):

    buffer = str()
    while 1:
      byte = try_read(rd,1)
      if byte == '': sock_close(15,0)
      if byte == '\n': break
      if byte != '\r' and len(buffer)<768: buffer += byte

    os.write(2,'[in] ' + buffer + '\n')
    buffer=re_LINK_INTERNAL('', buffer)
    if buffer[0] != ':':
      if re.search('^PING .*$', buffer):
        try_write(wr, 'PONG' + buffer[4:] + '\n')
      elif re.search('^SERVER .*$', buffer):
        channels.append('#status')
        try_write(wr,
          'NICK urc2server :1\n'
          ':urc2server USER serverlink urc2server urc2server :real name\n'
          ':urc2server JOIN #status\n'
          ':urc2server PRIVMSG #status :Link established\n'
          'NICK dummy :1\n'
          ':dummy USER dummy urc2server urc2server :real name\n'
        )
      elif re_LINK_NICK(buffer):
        nick = buffer.split(' ')[1]
        if not nick.lower() in localnicks:
          localnicks.append(nick.lower())
          if DEBUG: try_write(wr,':urc2server PRIVMSG #status :local nick ' + nick.lower() + ' added: ' + buffer + '\n')
        else:
          try_write(wr,':urc2server PRIVMSG #status :local nick ' + nick.lower() + ' is already in localnicks. wtf?: ' + buffer + '\n')
      elif re_LINK_KILL(buffer):
        nick = buffer.split(' ')[1]
        if nick.lower() in nicks:
          del nicks[nick.lower()]
        if nick.lower() in localnicks:
          localnicks.remove(nick.lower())
        try_write(wr,':urc2server PRIVMSG #status :nick killed: ' + buffer + '\n') 
      elif not re.search('^PASS .*$', buffer):
        try_write(wr,':urc2server PRIVMSG #status :unknown command from irc server: ' + buffer + '\n')
      continue

    buffer = buffer.split(' ', 1)[0] + '!urc2serverRFC1459@' + LINKNAME + ' ' + buffer.split(' ', 1)[1]
    #os.write(2,'[got] ' + buffer+'\n')
    if re_LINK_PRIVMSG_NOTICE_TOPIC(buffer):
      #os.write(2, '  last message is PRIVMSG_NOTICE_TOPIC\n')
      #if buffer[1:].split('!',1)[0] == nick: continue
      sock_write(buffer+'\n')

    elif re_LINK_PART(buffer):
      pass
      #if len(buffer.split(' :'))<2: buffer += ' :'
      if PRESENCE: sock_write(buffer + '\n')

    elif re_LINK_QUIT(buffer):
      nick = buffer.split('!', 1)[0][1:]
      if nick.lower() in localnicks:
        try:
          if DEBUG: try_write(wr,':urc2server PRIVMSG #status :local nick ' + nick + ' removed\n')
          localnicks.remove(nick.lower())
        except Exception as e:
          try_write(wr,':urc2server PRIVMSG #status :exception while removing local nick ' + nick + ': ' + e + '\n')
      else:
        try_write(wr,':urc2server PRIVMSG #status :nick not in localnicks. wtf? ' + buffer + '\n')
      #if len(buffer.split(' :'))<2: buffer += ' :'
      if PRESENCE: sock_write(buffer + '\n')

    elif re_LINK_JOIN(buffer):
      chan = buffer.split(" ")[2]
      if chan not in channels:
        try_write(wr, ':dummy JOIN ' + chan + '\n')
        channels.append(chan)
      if PRESENCE: sock_write(buffer.split(' JOIN ', 1)[0] + ' JOIN :' + buffer.split(' JOIN ', 1)[1] + '\n')

    elif re_LINK_KICK(buffer):
      #if len(buffer.split(' :'))<2: buffer += ' :'
      sock_write(buffer+'\n')

    elif re_LINK_PRIVMSG_PRIVATE(buffer):
      sock_write(buffer+'\n')

    #elif re.search('^:['+RE+']+![~'+RE+'.]+@['+RE+'.]+ INVITE '+re.escape(nick).upper()+' :#['+RE+']+$',buffer.upper()):
    #  dst = buffer[1:].split(':',1)[1].lower()
    #  if not dst in channels: try_write(wr,'JOIN '+dst+'\n')


  while server_revents(0):

    time.sleep(LIMIT)

    buffer = try_read(sd,1024).split('\n',1)[0]
    if not buffer: continue
    #os.write(2, 'socket-in: ' + buffer + '\n')
    parts = buffer.split(' ')
    if parts[-1] == 'urc-integ':
      try:
        timestamp, check = int(parts[-3]), parts[-2]
        length = len(parts[-3]) + len(parts[-2]) + len(parts[-1]) + 3
        buffer = buffer[:-length]
        if parts[1] == 'PRIVMSG':
          if sha1(buffer + ' ' + parts[-3]).hexdigest()[:10] == check:
            status = ' \x0309[v]\x0f'
          else:
            status = ' \x0305[check failed]\x0f'
          if buffer[-1] == '\x01':
            buffer = buffer[:-1] + status + '\x01'
          else:
            buffer += status
          del status
        del length, timestamp, check
      except Exception as e:
        pass

    elif len(parts[-1]) == 10:
      try:
        timestamp, check = int(parts[-2]), parts[-1]
        length = len(parts[-2])+len(parts[-1]) + 2
        buffer = buffer[:-length]
        if parts[1] == 'PRIVMSG':
          if sha1(buffer + ' ' + parts[-2]).hexdigest()[:10] == check:
            status = ' \x0309[v]\x0f'
          else:
            status = ' \x0305[check failed]\x0f'
          if buffer[-1] == '\x01':
            buffer = buffer[:-1] + status + '\x01'
          else:
            buffer += status
          del status
        del length, timestamp, check
      except Exception as e:
        pass
    del parts

    buffer = re_BUFFER_CTCP_DCC('',buffer) + '\x01' if '\x01ACTION ' in buffer.upper() else buffer.replace('\x01','')
    if not COLOUR: buffer = re_BUFFER_COLOUR('',buffer)
    if not UNICODE:
      buffer = codecs.ascii_encode(unicodedata.normalize('NFKD',unicode(buffer,'utf-8','replace')),'ignore')[0]
      buffer = ''.join(byte for byte in buffer if 127 > ord(byte) > 31 or byte in ['\x01','\x02','\x03','\x0f','\x1d','\x1f'])
    buffer += '\n'
    #os.write(2, 'socket-done: ' + buffer)

    #os.write(2, '[sock_read] ' + buffer)
    if re_URC_PRIVMSG_NOTICE_TOPIC(buffer) or re_URC_PRIVMSG_PRIVATE(buffer):
      dst = re_SPLIT(buffer,3)[2].lower()
      if re_URC_PRIVMSG_PRIVATE(buffer) and dst.lower() not in localnicks: continue
      nick = buffer.split('!', 1)[0][1:]
      while nick in localnicks: nick = nick + "_"
      host = buffer.split(' ', 1)[0].split('@', 1)[1]
      if nick.lower() not in nicks:
        try_write(wr, 'NICK ' + nick + ' :1\n')
        try_write(wr, ':' + nick + ' USER remote ' + host + ' noIdea :real name\n')
        nicks[nick.lower()] = list()
        nicks[nick.lower()].append(nick)
        nicks[nick.lower()].append(time.time())
        if DEBUG: try_write(wr,':urc2server PRIVMSG #status :nick added: ' + nick + '!remote@' + host + '\n')
      else:
        nicks[nick.lower()][1] = time.time();
        if DEBUG: try_write(wr,':urc2server PRIVMSG #status :nick activity refreshed: ' + nick.lower() + '\n')
      if dst[0] in ['#','&']: try_write(wr, ':' + nick + ' JOIN ' + dst + ' :1\n')
      try_write(wr, ':' + nick + ' ' + buffer.split(' ', 1)[1])
    elif re_URC_PART(buffer):
      nick = buffer.split('!', 1)[0][1:]
      if nick.lower() in nicks:
        dst = buffer.split(' ')[2]
        if DEBUG: try_write(wr,':urc2server PRIVMSG #status :' + nick + ' parted from channel ' + dst + '\n')
        try_write(wr, ':' + nick + ' ' + buffer.split(' ', 1)[1])
    elif re_URC_QUIT(buffer):
      nick = buffer.split('!', 1)[0][1:]
      if nick.lower() in nicks:
        if DEBUG: try_write(wr,':urc2server PRIVMSG #status :' + nick + ' quit\n')
        try_write(wr, ':' + nick + ' ' + buffer.split(' ', 1)[1])
        del nicks[nick.lower()]
    elif re_URC_JOIN(buffer):
      nick = buffer.split('!', 1)[0][1:]
      dst = buffer.split(' ')[2][1:]
      if not nick.lower() in nicks:
        while nick in localnicks: nick = nick + "_"
        host = buffer.split(' ', 1)[0].split('@', 1)[1]
        try_write(wr, 'NICK ' + nick + ' :1\n')
        try_write(wr, ':' + nick + ' USER remote ' + host + ' noIdea :real name\n')
        nicks[nick.lower()] = list()
        nicks[nick.lower()].append(nick)
        nicks[nick.lower()].append(time.time())
        if DEBUG: try_write(wr,':urc2server PRIVMSG #status :' + nick.lower() + ' added\n')
      if DEBUG: try_write(wr,':urc2server PRIVMSG #status :' + nick + ' joined ' + dst + '\n')
      try_write(wr, ':' + nick + ' ' + buffer.split(' ', 1)[1])

