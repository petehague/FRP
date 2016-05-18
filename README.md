This code is designed to be used on the ALICE cluster at the University of Leicester

##Use on ALICE

Log into ALICE (remember to use the -X option on ssh) and load the following modules

    module load python/2.7.9
    module load gdal
    module load R
    
Make the code

    make

Then submit a job

    qsub frp_alice.sub

Once this has finished, run the post processing script 

    R
    source("postproc.r")

# Serial profiling

Ensure that you have Cython, GDAL, numpy and scipy available. Type 

    make

and then 

    ./doprof.py
