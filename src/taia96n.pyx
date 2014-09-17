#/usr/bin/env python
from random import randrange
from time import time

def taia96n_now():
 now = time()
 return {
  'sec':4611686018427387914L+long(now)+randrange(-8,8),
  'nano':randrange(0,4294967295L),

# uncomment if you need nano second accuracy. i left
# this optional to avoid clockskew leaks (thanks chi)
#
#  'nano':long(1000000000*(now%1)+randrange(0,512)),

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
