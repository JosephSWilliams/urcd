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

RE = 'a-zA-Z0-9^(\)\-_{\}[\]|'
re_SPLIT = re.compile(' +',re.IGNORECASE).split
re_CLIENT_PRIVMSG_NOTICE_TOPIC = re.compile('^:['+RE+']+![~'+RE+'.]+@['+RE+'.]+ ((PRIVMSG)|(NOTICE)|(TOPIC)) [#&!+]['+RE+']+ :.*$',re.IGNORECASE).search
re_CLIENT_PART = re.compile('^:['+RE+']+![~'+RE+'.]+@['+RE+'.]+ PART [#&!+]['+RE+']+( :)?',re.IGNORECASE).search
re_CLIENT_QUIT = re.compile('^:['+RE+']+![~'+RE+'.]+@['+RE+'.]+ QUIT( :)?',re.IGNORECASE).search
re_CLIENT_PING = re.compile('^PING :?.+$',re.IGNORECASE).search
re_CLIENT_JOIN = re.compile('^:['+RE+']+![~'+RE+'.]+@['+RE+'.]+ JOIN :[#&!+]['+RE+']+$',re.IGNORECASE).search
re_CLIENT_KICK = re.compile('^:.+ KICK [#&!+]['+RE+']+ ['+RE+']+',re.IGNORECASE).search
re_CLIENT_CHANMODE = re.compile('^:['+RE+']+![~'+RE+'.]+@['+RE+'.]+ MODE [#&!+]['+RE+']+ [-+][be] ['+RE+']+![~'+RE+'.]+@['+RE+'.]+ ?',re.IGNORECASE).search
re_CLIENT_BAN_EXCEPT = re.compile('^:['+RE+'!@~.]+ ((367)|(348)) ['+RE+']+ [#&!+]['+RE+']+ \S+ ',re.IGNORECASE).search
re_BUFFER_CTCP_DCC = re.compile('\x01(?!ACTION )',re.IGNORECASE).sub
re_BUFFER_COLOUR = re.compile('(\x03[0-9][0-9]?((?<=[0-9]),[0-9]?[0-9]?)?)|[\x02\x03\x0f\x1d\x1f]',re.IGNORECASE).sub
re_SERVER_PRIVMSG_NOTICE_TOPIC = re.compile('^:['+RE+']+![~'+RE+'.]+@['+RE+'.]+ ((PRIVMSG)|(NOTICE)|(TOPIC)) [#&!+]['+RE+']+ :.*$',re.IGNORECASE).search

LIMIT = float(open('env/LIMIT','rb').read().split('\n')[0]) if os.path.exists('env/LIMIT') else 1
INVITE = int(open('env/INVITE','rb').read().split('\n')[0]) if os.path.exists('env/INVITE') else 0
COLOUR = int(open('env/COLOUR','rb').read().split('\n')[0]) if os.path.exists('env/COLOUR') else 0
UNICODE = int(open('env/UNICODE','rb').read().split('\n')[0]) if os.path.exists('env/UNICODE') else 0
TIMEOUT = int(open('env/TIMEOUT','rb').read().split('\n')[0]) if os.path.exists('env/TIMEOUT') else 128
CHANLIMIT = int(open('env/CHANLIMIT','rb').read().split('\n')[0]) if os.path.exists('env/CHANLIMIT') else 16

BAN = dict()
EXCEPT = dict()
seen = time.time()
ping = time.time()
user = str(os.getpid())
nick = open('nick','rb').read().split('\n')[0]

channels = collections.deque([],CHANLIMIT)
for dst in open('channels','rb').read().lower().split('\n'):
  if dst: channels.append(dst)

auto_cmd = list()
for cmd in open('auto_cmd','rb').read().split('\n'):
  if cmd: auto_cmd.append(cmd)

def sock_close(sn,sf):
  try: os.remove(str(os.getpid()))
  except: pass
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

if os.access('stdout',1):
  p = subprocess.Popen(['./stdout'],stdin=subprocess.PIPE,stdout=subprocess.PIPE)
  pipefd = ( p.stdout.fileno(), p.stdin.fileno() )
  del p
else: pipefd = os.pipe()

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
poll.register(pipefd[0],select.POLLIN)
poll.register(sd,select.POLLIN)
poll=poll.poll

client_revents=select.poll()
client_revents.register(rd,select.POLLIN|select.POLLPRI)
client_revents=client_revents.poll

pipe_revents=select.poll()
pipe_revents.register(pipefd[0],select.POLLIN)
pipe_revents=pipe_revents.poll

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

try_write(1,'USER '+nick+' '+nick+' '+nick+' :'+nick+'\nNICK '+nick+'\n')

def INIT():
  if client_revents(8192): return
  global INIT, auto_cmd, channels
  INIT = 0
  for cmd in auto_cmd:
    time.sleep(LIMIT)
    try_write(1,cmd+'\n')
  for dst in channels:
    time.sleep(LIMIT)
    try_write(1,'JOIN '+dst+'\n')
  channels = collections.deque([],CHANLIMIT)
  del auto_cmd

while 1:

  if poll(TIMEOUT<<10) and not INIT: time.sleep(LIMIT)
  now = time.time()

  if not client_revents(0):
    if now - seen >= TIMEOUT: sock_close(15,0)
    if now - ping >= TIMEOUT >> 4:
      try_write(1,'PING :LAG\n')
      ping = now

  else:
    buffer, seen, ping = str(), now, now
    while 1:
      byte = try_read(rd,1)
      if byte == '': sock_close(15,0)
      if byte == '\n': break
      if byte != '\r' and len(buffer)<768: buffer += byte

    if re_CLIENT_PRIVMSG_NOTICE_TOPIC(buffer):
      if buffer[1:].split('!',1)[0] == nick: continue
      sock_write(buffer+'\n')

    elif re_CLIENT_PART(buffer):
      if len(buffer.split(' :'))<2: buffer += ' :'
      sock_write(buffer+'\n')

    elif re_CLIENT_QUIT(buffer):
      if len(buffer.split(' :'))<2: buffer += ' :'
      sock_write(buffer+'\n')

    elif re_CLIENT_PING(buffer): try_write(1,'PONG '+re_SPLIT(buffer,1)[1]+'\n')

    elif re_CLIENT_JOIN(buffer):
      sock_write(buffer+'\n')
      dst = buffer.split(':')[2].lower()
      if not dst in channels:
        if len(channels) - 1 < CHANLIMIT:
          BAN[dst], EXCEPT[dst] = list(), list()
          channels.append(dst)
          try_write(1,'MODE '+dst+' b\n')
          time.sleep(LIMIT)
          try_write(1,'MODE '+dst+' e\n')
        else: try_write(1,'PART '+dst+' :CHANLIMIT\n')

    elif re.search('^:'+re.escape(nick).upper()+'!.+ NICK ',buffer.upper()):
      nick = re_SPLIT(buffer)[2]

    elif re.search('^:.+ 433 .+ '+re.escape(nick),buffer):
      nick+='_'
      try_write(1,'NICK '+nick+'\n')

    elif re_CLIENT_KICK(buffer):
      if len(buffer.split(' :'))<2: buffer += ' :'
      sock_write(buffer+'\n')
      if re_SPLIT(buffer,4)[3].lower() == nick.lower():
        try_write(1,'JOIN '+re_SPLIT(buffer,4)[2]+'\n')
        del EXCEPT[dst], BAN[dst]
        channels.remove(dst)

    elif INVITE and len(channels) < CHANLIMIT and re.search('^:['+RE+']+![~'+RE+'.]+@['+RE+'.]+ INVITE '+re.escape(nick).upper()+' :[#&!+]['+RE+']+$',buffer.upper()):
      dst = buffer[1:].split(':',1)[1].lower()
      if not dst in channels: try_write(1,'JOIN '+dst+'\n')

    elif re_CLIENT_CHANMODE(buffer):
      try:
        src, cmd, dst = re_SPLIT(buffer,5)[2:5]
        dst = re.compile(re.escape(dst).replace('\\*','.*'),re.IGNORECASE).search
        src = src.lower()
        if cmd[1] == 'b':
          BAN[src].append(dst) if cmd[0] == '+' and not dst in BAN[src] else BAN[src].remove(dst)
        elif cmd[1] == 'e':
          EXCEPT[src].append(dst) if cmd[0] == '+' and not dst in EXCEPT[src] else EXCEPT[src].remove(dst)
      except: pass

    elif re_CLIENT_BAN_EXCEPT(buffer):
      try:
        cmd, src, dst, msg = re_SPLIT(buffer,5)[1:5]
        msg = re.compile(re.escape(msg).replace('\\*','.*'),re.IGNORECASE).search
        dst = dst.lower()
        if cmd == '367':
          if not msg in BAN[dst]: BAN[dst].append(msg)
        elif cmd == '348':
          if not msg in EXCEPT[dst]: EXCEPT.append(msg)
      except: pass

  if INIT:
    INIT()
    continue

  if server_revents(0):
    buffer = try_read(sd,1024).split('\n',1)[0]
    if not buffer: continue
    try_write(pipefd[1],buffer+'\n')

  if pipe_revents(0):

    buffer = str()
    while 1:
      byte = try_read(pipefd[0],1)
      if byte == '': sock_close(15,0)
      if byte == '\n': break
      if byte != '\r' and len(buffer)<768: buffer += byte

    buffer = re_BUFFER_CTCP_DCC('',buffer) + '\x01' if '\x01ACTION ' in buffer.upper() else buffer.replace('\x01','')
    if not COLOUR: buffer = re_BUFFER_COLOUR('',buffer)
    if not UNICODE:
      buffer = codecs.ascii_encode(unicodedata.normalize('NFKD',unicode(buffer,'utf-8','replace')),'ignore')[0]
      buffer = ''.join(byte for byte in buffer if 127 > ord(byte) > 31 or byte in ['\x01','\x02','\x03','\x0f','\x1d','\x1f'])
    buffer += '\n'

    if re_SERVER_PRIVMSG_NOTICE_TOPIC(buffer):
      dst = re_SPLIT(buffer,3)[2].lower()
      if dst in channels:
        cmd, src = 1, re_SPLIT(buffer[1:],1)[0]
        for cmd in EXCEPT[dst]:
          if cmd(src):
            cmd = 0
            break
        if cmd:
          for cmd in BAN[dst]:
            if cmd(src):
              cmd = 0
              break
          if cmd == 0: continue
        cmd = re_SPLIT(buffer,3)[1].upper()
        src = buffer[1:].split('!',1)[0] + '> ' if cmd != 'TOPIC' else str()
        msg = buffer.split(':',2)[2]
        buffer = cmd + ' ' + dst + ' :' + src + msg + '\n'
        try_write(1,buffer)
