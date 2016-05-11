# Installation instructions

Ensure that you have Cython, GDAL, numpy and scipy available. Type 

    make

and then 

    ./doprof.py

##Use on ALICE

before making the code, load the following modules

    module load python/2.7.9
    module load gdal

Once the Cython module is ready, you can use

    qsub frp_alice.sub

to do a test run - 16 jobs running the test code 100 times each
