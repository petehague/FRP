#!/usr/bin/env python

import cyfrp
import sys
import time as t


print "Start at {}".format(t.strftime("%H:%M:%S"))
for i in range(100):
  cyfrp.run("data",sys.argv[1])
print "Finish at {}".format(t.strftime("%H:%M:%S"))
