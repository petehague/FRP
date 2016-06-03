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

# TODO

In order to be suitable for batch processing of large numbers of images, the following changes must be made:

1. Write a script to extract the original HDF files to a folder containing all the various images required for processing
2. In the same script, supply the boundary coordinates in coords.txt in the order **minimum-latitude** **maximum-latitude** **minimum-longitude** **maximum-longitude** seperated by spaces
3. Rewrite the submission script frp_alice.sub so that each array process invokes **process.py** with the path to one of the folders as its sole argument
