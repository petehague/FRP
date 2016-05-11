from distutils.core import setup
from Cython.Build import cythonize

setup( name = "FRPi", ext_modules = cythonize("cyfrp.pyx") )
