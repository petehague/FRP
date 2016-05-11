#!/usr/bin/env python

import pstats, cProfile, cyfrp
import time as t
import sys

filename = 'profiles/{}'.format(t.strftime('%y%m%d%a.%H%M%S'))

cProfile.runctx('cyfrp.run("data",0)',globals(),locals(),'{}.prof'.format(filename))
s = pstats.Stats('{}.prof'.format(filename))
s.strip_dirs().sort_stats('time').print_stats(10)

s = pstats.Stats('{}.prof'.format(filename), stream=open('{}.txt'.format(filename),'w'))
s.strip_dirs().sort_stats('time').print_stats()

