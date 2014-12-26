#!/usr/bin/env python
# Usage: tcpclient $urchub_addr $urchub_port python urcbot.py

import liburc
import sys
import os
import re

RE = 'a-zA-Z0-9^(\)\-_{\}[\]|\\\\'
re_PRIVMSG = re.compile('^:['+RE+']+![~:#'+RE+'.]+@[~:#'+RE+'.]+ PRIVMSG [#&!+]?['+RE+']+ :.*$',re.IGNORECASE).search

while 1:
 buff = os.read(6,2+12+4+8)
 if len(buff) < 2+12+4+8: break
 while len(buff[2+12+4+8:]) != ord(buff[0])*256 + ord(buff[1]):
  b = os.read(6,ord(buff[0])*256 + ord(buff[1]) - len(buff[2+12+4+8:]))
  if not b: sys.exit(0)
  buff += b
 buff = buff[2+12+4+8:]

 if re_PRIVMSG(buff):
  src = buff[1:].split('!',1)[0]
  dst = buff.split(' ',3)[2]
  msg = buff.split(' :',1)[1]
  if msg.lower()[:5] == '!ping':
   buff = liburc.urchub_fmt(':bot!bot@bot PRIVMSG '+dst+' :pong\n')
   os.write(7,buff)
