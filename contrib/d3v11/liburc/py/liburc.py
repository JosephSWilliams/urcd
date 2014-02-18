#/usr/bin/env python
from random import randrange as RR
from array import array
from time import time

def randombytes(n):
 ### WARNING: good entropy not guaranteed ###
 return array('B',[RR(0,256) for i in xrange(0,n)]).tostring()

def taia96n_now():
 now = time()
 return {
  'sec':4611686018427387914L+long(now),
  'nano':long(1000000000*(now%1)+500),
}

def tai_pack(s): return str(
 chr(s['sec']>>56&255) +
 chr(s['sec']>>48&255) +
 chr(s['sec']>>40&255) +
 chr(s['sec']>>32&255) +
 chr(s['sec']>>24&255) +
 chr(s['sec']>>16&255) +
 chr(s['sec']>>8&255) +
 chr(s['sec']&255)
)

def taia96n_pack(s): return str(
 tai_pack(s)+
 chr(s['nano']>>24&255)+
 chr(s['nano']>>16&255)+
 chr(s['nano']>>8&255)+
 chr(s['nano']&255)
)

def urchub(urcline): return str(
 chr(len(urcline)/256)+
 chr(len(urcline)%256)+
 taia96n_pack(taia96n_now())+
 '\x00\x00\x00\x00'+
 randombytes(8)+
 urcline
)
