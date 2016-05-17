#!/usr/bin/env python

import sys

if len(sys.argv)>1:
    jobrank = int(sys.argv[1])
else:
    jobrank = 0

def procarea(x0,y0,x1,y1):
    xlist = []
    ylist = []
    for x in range(x0,x1):
        for y in range(y0,y1):
            if x/3 == x/3.0 and y/3 == y/3.0:
                xlist.append(x)
                ylist.append(y)
    return xlist,ylist

#Fixed parameters
minx = 0
miny = 0
maxx = 100
maxy = 100

blockx = 50
blocky = 50
tabsize = 5

#Inferred parameters
nblockx = (maxx-minx)/blockx
nblocky = (maxy-miny)/blocky

yi = jobrank//nblockx
xi = int(nblockx*(jobrank/float(nblockx)-yi))

ax = xi*blockx
ay = yi*blocky
bx = ax+blockx
by = ay+blocky

if xi>0:
    ax -= tabsize
if yi>0:
    ay -= tabsize

#Analyse blocks
resultx, resulty = procarea(ax,ay,bx,by)

#print resultx
