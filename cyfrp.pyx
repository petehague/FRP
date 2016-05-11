# cython: profile=True

from scipy import ndimage
import numpy as np
import os
from osgeo import gdal
import time as t

callCount = 0

#Geometric settings for sampling
minNcount = 8
minNfrac = 0.25
minKsize = 5
maxKsize = 21
b21saturationVal = 450 #???

#############################
#FUNCTION DEFINITIONS
#############################
#OMIT SCANLINE NEIGHBORS FROM SAMPLING
def zeroFootprint(kSize):
    fpZeroLine = (kSize-1)/2
    fpZeroColStart = fpZeroLine-1
    fpZeroColEnd = fpZeroColStart+3
    fp = np.ones((kSize,kSize),dtype = 'int_')
    fp[fpZeroLine,fpZeroColStart:fpZeroColEnd] = 0
    fp[fpZeroLine,fpZeroLine] = 1

    return fp

#RETURN MEAN OF NON-BACKGROUND FIRE NEIGHBORS
cdef float meanFilt(kernel, int kSize, int minKsize, int maxKsize, int halfSize, int minN, int centerpos):
    cdef float bgMean = -4
    cdef int nghbrCnt

    cdef float centerVal = kernel[centerpos]
    kernel[centerpos] = -5

    if (((kSize == minKsize) | (centerVal == -4)) & (centerVal not in (range(-2,0)))):
        nghbrs = kernel[np.where(kernel > 0)]
        nghbrCnt = len(nghbrs)

        if (nghbrCnt > minN):
             bgMean = np.mean(nghbrs)

    return bgMean

#RETURN MEAN ABSOLUTE DEVIATION OF NON-BACKGROUND FIRE NEIGHBORS
cdef float MADfilt(kernel, int kSize, int minKsize, int maxKsize, int halfSize, int minN, int centerpos):
    cdef float bgMAD = -4
    cdef int nghbrCnt

    cdef float centerVal = kernel[centerpos]
    kernel[centerpos] = -5

    if (((kSize == minKsize) | (centerVal == -4)) & (centerVal not in (range(-2,0)))):
        nghbrs = kernel[np.where(kernel > 0)]
        nghbrCnt = len(nghbrs)

        if (nghbrCnt > minN):
            bgMean = np.mean(nghbrs)
            meanDists = np.abs(nghbrs - bgMean)
            bgMAD = np.mean(meanDists)

    return bgMAD

#RETURN NUMBER OF NON-BACKGROUND FIRE, NON-CLOUD, NON-WATER NEIGHBORS
def nValidFilt(kernel,kSize,minKsize,maxKsize, halfSize, minN, centerpos): #USE BG mask files
    nghbrCnt = -4

    cdef float centerVal = kernel[centerpos]
    kernel[centerpos] = -5

    if (((kSize == minKsize) | (centerVal == -4)) & (centerVal not in (range(-3,0)))):
        nghbrs = kernel[np.where(kernel > 0)]
        nghbrCnt = len(nghbrs)

    return nghbrCnt

#RETURN NUMBER OF NEIGHBORS REJECTED AS BACKGROUND
def nRejectBGfireFilt(kernel,kSize,minKsize,maxKsize, halfSize, minN, centerpos):
    nRejectBGfire = -4

    cdef float centerVal = kernel[centerpos]

    if (((kSize == minKsize) | (centerVal == -4))):
        nRejectBGfire = len(kernel[np.where(kernel == -3)])

    return nRejectBGfire

#RETURN NUMBER OF NEIGHBORS REJECTED AS WATER
def nRejectWaterFilt(kernel,kSize,minKsize,maxKsize, halfSize, minN, centerpos):
    nRejectWater = -4

    cdef float centerVal = kernel[centerpos]

    if (((kSize == minKsize) | (centerVal == -4))):
        nRejectWater= len(kernel[np.where(kernel == -1)])

    return nRejectWater

#RETURN NUMBER OF 'UNMASKED WATER' NEIGHBORS
def nUnmaskedWaterFilt(kernel,kSize,minKsize,maxKsize, halfSize, minN, centerpos):
    nUnmaskedWater = -4

    cdef float centerVal = kernel[centerpos]

    if (((kSize == minKsize) | (centerVal == -4)) & (centerVal not in (range(-3,0)))):
        nUnmaskedWater= len(kernel[np.where(kernel == -6)])

    return nUnmaskedWater

#RUNS FILTERS ON PROGRESSIVELY LARGER KERNEL SIZES, COMBINES RESULTS FROM SMALLEST KSIZE
def runFilt(band,filtFunc,minKsize,maxKsize,footprintType):
    filtBand = band
    kSize = minKsize
    bandFilts = {}

    while kSize <=  maxKsize:
        filtName = 'bandFilt'+str(kSize)
        if footprintType == 0:
          filtBand = ndimage.generic_filter(filtBand, filtFunc, footprint=zeroFootprint(kSize), extra_arguments= (kSize,minKsize,maxKsize,(kSize-1)/2,min(minNcount, minNfrac*kSize*kSize), (kSize+1)*(kSize-1)/2 - 1)) 
        else:
          filtBand = ndimage.generic_filter(filtBand, filtFunc, size = kSize, extra_arguments= (kSize,minKsize,maxKsize,(kSize-1)/2,min(minNcount, minNfrac*kSize*kSize), (kSize+1)*(kSize-1)/2 - 1  ))
        bandFilts[filtName] = filtBand
        kSize += 2

    bandFilt = bandFilts['bandFilt'+str(minKsize)]
    kSize = minKsize + 2

    while kSize <= maxKsize:
        bandFilt[np.where(bandFilt == -4)] = bandFilts['bandFilt'+str(kSize)][np.where(bandFilt == -4)]
        kSize += 2

    return bandFilt

#DETERMINES IF CENTER PIXEL IS ADJACENT TO A FILTERED WATER PIXEL
def adjWater(kernel):
    nghbors = kernel[range(0,4)+range(5,9)]
    waterNghbors = kernel[np.where(nghbors == 1)]
    nWaterNghbr = len(waterNghbors)
    return nWaterNghbr

#############################
#Main function
#############################

def run(datapath,procid):    
    #start = t.clock()
       
    #OPEN INPUT BANDS
    filList = os.listdir('.')
    filNam = 'MOD021KM.A2004178.2120.005.'
    bands = ['BAND1','BAND2','BAND7','BAND21','BAND22','BAND31','BAND32','LANDMASK','SolarZenith','SolarAzimuth','SensorZenith','SensorAzimuth','LAT','LON']
    
    allArrays = {}
    for b in bands:
        fullFilName = datapath + "/" + filNam + b + '.tif'
        ds = gdal.Open(fullFilName)
        data = np.array(ds.GetRasterBand(1).ReadAsArray())
        data = data[1472:1546,566:656] #BOUNDARY FIRE AREA
        if b == 'BAND21' or b == 'BAND22' or b == 'BAND31' or b == 'BAND32':
    #        data = np.int_(np.rint(data))
            data = data
        if b == 'BAND1' or b == 'BAND2' or b == 'BAND7':
            b = b + 'x1k'
            data = np.int_(np.rint(data*1000))
    
        allArrays[b] = data
    
    [nRows,nCols] = np.shape(allArrays['BAND21'])
    
    
    #DAY/NIGHT FLAG
    dayFlag = np.zeros((nRows,nCols),dtype=np.int)
    dayFlag[np.where(allArrays['SolarZenith'] < 8500)] = 1
    
    waterFlag = -1
    cloudFlag = -2
    
    #CREATE WATER MASK
    waterMask = np.zeros((nRows,nCols),dtype=np.int)
    waterMask[np.where(allArrays['LANDMASK']!=1)] = waterFlag
    
    #CREATE CLOUD MASK (SET DATATYPE)
    cloudMask =np.zeros((nRows,nCols),dtype=np.int)
    cloudMask[((allArrays['BAND1x1k']+allArrays['BAND2x1k'])>900)] = cloudFlag
    cloudMask[(allArrays['BAND32']<265)] = cloudFlag
    cloudMask[((allArrays['BAND1x1k']+allArrays['BAND2x1k'])>700)&(allArrays['BAND32']<285)] = cloudFlag
    
    #MASK CLOUDS AND WATER FROM INPUT BANDS
    b21CloudWaterMasked = np.copy(allArrays['BAND21'])
    b21CloudWaterMasked[np.where(waterMask == waterFlag)] = waterFlag
    b21CloudWaterMasked[np.where(cloudMask == cloudFlag)] = cloudFlag
    
    b22CloudWaterMasked = np.copy(allArrays['BAND22'])
    b22CloudWaterMasked[np.where(waterMask == waterFlag)] = waterFlag
    b22CloudWaterMasked[np.where(cloudMask == cloudFlag)] = cloudFlag
    
    b31CloudWaterMasked = np.copy(allArrays['BAND31'])
    b31CloudWaterMasked [np.where(waterMask == waterFlag)] = waterFlag
    b31CloudWaterMasked [np.where(cloudMask == cloudFlag)] = cloudFlag
    
    deltaT = np.abs(allArrays['BAND21'] - allArrays['BAND31'])
    deltaTCloudWaterMasked = np.copy(deltaT)
    deltaTCloudWaterMasked[np.where(waterMask == waterFlag)] = waterFlag
    deltaTCloudWaterMasked[np.where(cloudMask == cloudFlag)] = cloudFlag
    
    #CREATE A MASK FOR BACKGROUND SAMPLING
    bgFlag = -3
    bgMask = np.zeros((nRows,nCols),dtype=np.int)
    
    with np.errstate(invalid='ignore'):
        bgMask[np.where((dayFlag == 1) & (allArrays['BAND21'] >325) & (deltaT >20))] = bgFlag
        bgMask[np.where((dayFlag == 0) & (deltaT >310)& (deltaT >10))] = bgFlag
    
        b21bgMask = np.copy(b21CloudWaterMasked)
        b21bgMask[np.where(bgMask == bgFlag)] = bgFlag
    
        b22bgMask = np.copy(b22CloudWaterMasked)
        b22bgMask[np.where(bgMask == bgFlag)] = bgFlag
    
        b31bgMask = np.copy(b31CloudWaterMasked)
        b31bgMask[np.where(bgMask == bgFlag)] = bgFlag
    
        deltaTbgMask = np.copy(deltaTCloudWaterMasked)
        deltaTbgMask[np.where(bgMask == bgFlag)] = bgFlag
     
    ####POTENTIAL FIRE TEST
    potFire = np.zeros((nRows,nCols),dtype=np.int)
    with np.errstate(invalid='ignore'):
        potFire[(dayFlag == 1)&(allArrays['BAND21']>310)&(deltaT>10)&(allArrays['BAND2x1k']<300)] = 1
        potFire[(dayFlag == 0)&(allArrays['BAND21']>305)&(deltaT>10)] = 1
    
    # ABSOLUTE THRESHOLD TEST (Kaufman et al. 1998) FOR REMOVING SUNGLINT
    absValTest = np.zeros((nRows,nCols),dtype=np.int)
    with np.errstate(invalid='ignore'):
        absValTest[(dayFlag == 1) & (allArrays['BAND21']>360)] = 1
        absValTest[(dayFlag == 0) & (allArrays['BAND21']>305)] = 1
    
    #########################################
    #CONTEXT TESTS
    #########################################
    
    ####CONTEXT FIRE TEST 2:
    deltaTmeanFilt = runFilt(deltaTbgMask,meanFilt,minKsize,maxKsize,0)
    
    ####deltaT MAD Filtering
    deltaTMADFilt = runFilt(deltaTbgMask,MADfilt,minKsize,maxKsize,0)
    deltaTMADfire = np.zeros((nRows,nCols),dtype=np.int)
    with np.errstate(invalid='ignore'):
        deltaTMADfire[deltaT>(deltaTmeanFilt + (3.5*deltaTMADFilt))] = 1
    
    ####CONTEXT FIRE TEST 3
    deltaTfire = np.zeros((nRows,nCols),dtype=np.int)
    with np.errstate(invalid='ignore'):
        deltaTfire[np.where(deltaT > (deltaTmeanFilt + 6))] = 1
    
    ####CONTEXT FIRE TEST 4
    b21meanFilt = runFilt(b21bgMask,meanFilt,minKsize,maxKsize,0)
    b21minusBG = np.copy(b21CloudWaterMasked) - np.copy(b21meanFilt)
    
    ##TEST FOR SATURATION IN BAND 21
    if (np.nanmax(b21CloudWaterMasked) > b21saturationVal):
    
        b22meanFilt = runFilt(b22bgMask,meanFilt,minKsize,maxKsize,0)
        b22minusBG = np.copy(b22CloudWaterMasked)  - np.copy(b22meanFilt)
    
        with np.errstate(invalid='ignore'):
            b21minusBG[(b21CloudWaterMasked >= b21saturationVal)] = b22minusBG[(b21CloudWaterMasked >= b21saturationVal)]
    
    B21fire = np.zeros((nRows,nCols),dtype=np.int)
    b21MADfilt = runFilt(b21bgMask,MADfilt,minKsize,maxKsize,0)
    with np.errstate(invalid='ignore'):
        B21fire[(b21CloudWaterMasked > (b21meanFilt + (3*b21MADfilt)))] = 1
    
    ####CONTEXT  FIRE TEST 5
    b31meanFilt = runFilt(b31bgMask,meanFilt,minKsize,maxKsize,0)
    b31MADfilt = runFilt(b31bgMask,MADfilt,minKsize,maxKsize,0)
    
    B31fire = np.zeros((nRows,nCols),dtype=np.int)
    B31fire[(b31CloudWaterMasked > (b31meanFilt + b31MADfilt - 4))] = 1
    
    ###CONTEXT FIRE TEST 6
    rejB21bgFires = np.copy(b21CloudWaterMasked)
    with np.errstate(invalid='ignore'):
        rejB21bgFires[(bgMask != bgFlag)] = bgFlag #PROCESS BG PIXELS
    
    b21rejMADfilt = runFilt(rejB21bgFires,MADfilt,minKsize,maxKsize,0)
    
    B21rejFire = np.zeros((nRows,nCols),dtype=np.int)
    with np.errstate(invalid='ignore'):
        B21rejFire[(b21rejMADfilt>5)] = 1
    
    #COMBINE TESTS TO CREATE "TENTATIVE FIRES"
    fireLocTentative = deltaTMADfire*deltaTfire*B21fire
    
    fireLocB31andB21rejFire = np.zeros((nRows,nCols),dtype=np.int)
    with np.errstate(invalid='ignore'):
        fireLocB31andB21rejFire[np.where((B21rejFire == 1)|(B31fire == 1))]= 1
    fireLocTentativeDay = potFire*fireLocTentative*fireLocB31andB21rejFire
    
    dayFires = np.zeros((nRows,nCols),dtype=np.int)
    with np.errstate(invalid='ignore'):
        dayFires[(dayFlag == 1)&((absValTest == 1)|(fireLocTentativeDay ==1))] = 1
    
    #NIGHTTIME DEFINITE FIRES (NO FURTHER TESTS)
    nightFires = np.zeros((nRows,nCols),dtype=np.int)
    with np.errstate(invalid='ignore'):
        nightFires[((dayFlag == 0)&((fireLocTentative == 1)|absValTest == 1))] = 1
    
    ###########################################
    #####ADDITIONAL DAYTIME TESTS ON TENTATIVE FIRES
    ##############################################
    
    #SUNGLINT REJECTION
    relAzimuth = allArrays['SensorAzimuth']-allArrays['SolarAzimuth']
    cosThetaG = (np.cos(allArrays['SensorZenith'])*np.cos(allArrays['SolarZenith']))- (np.sin(allArrays['SensorZenith'])*np.sin(allArrays['SolarZenith'])*np.cos(relAzimuth))
    thetaG = np.arccos(cosThetaG)
    thetaG = (thetaG/3.141592)*180
    
    #SUNGLINT TEST 8
    sgTest8 = np.zeros((nRows,nCols),dtype=np.int)
    with np.errstate(invalid='ignore'):
        sgTest8[np.where(thetaG < 2)] = 1
    
    #SUNGLINT TEST 9
    sgTest9 = np.zeros((nRows,nCols),dtype=np.int)
    with np.errstate(invalid='ignore'):
        sgTest9[np.where((thetaG<8)&(allArrays['BAND1x1k']>100)&(allArrays['BAND2x1k']>200)&(allArrays['BAND7x1k']>120))] = 1
    
    #SUNGLINT TEST 10
    waterLoc = np.zeros((nRows,nCols),dtype=np.int)
    with np.errstate(invalid='ignore'):
        waterLoc[np.where(waterMask == waterFlag)] = 1
    nWaterAdj = ndimage.generic_filter(waterLoc, adjWater, size = 3)
    nRejectedWater = runFilt(waterMask,nRejectWaterFilt,minKsize,maxKsize,1)
    with np.errstate(invalid='ignore'):
        nRejectedWater[np.where(nRejectedWater<0)] = 0
    
    sgTest10 = np.zeros((nRows,nCols),dtype=np.int)
    with np.errstate(invalid='ignore'):
        sgTest10[np.where((thetaG<12) & ((nWaterAdj+nRejectedWater)>0))] = 1
    
    sgAll = np.zeros((nRows,nCols),dtype=np.int)
    with np.errstate(invalid='ignore'):
        sgAll[(sgTest8 == 1) | (sgTest9 == 1) | (sgTest10 == 1)] = 1
    
    #DESERT BOUNDARY REJECTION
    
    nValid = runFilt(b21bgMask,nValidFilt,minKsize,maxKsize,0)
    
    nRejectedBG = runFilt(bgMask,nRejectBGfireFilt,minKsize,maxKsize,1)
    with np.errstate(invalid='ignore'):
        nRejectedBG[np.where(nRejectedBG<0)] = 0
    
    #DESERT BOUNDARY TEST 11
    dbTest11 = np.zeros((nRows,nCols),dtype=np.int)
    with np.errstate(invalid='ignore'):
        dbTest11[np.where(nRejectedBG>(0.1*nValid))] = 1
    
    #DB TEST 12
    dbTest12 = np.zeros((nRows,nCols),dtype=np.int)
    with np.errstate(invalid='ignore'):
        dbTest12[(nRejectedBG>=4)] = 1
    
    #DB TEST 13
    dbTest13 = np.zeros((nRows,nCols),dtype=np.int)
    with np.errstate(invalid='ignore'):
        dbTest13[np.where(allArrays['BAND2x1k']>150)] = 1
    
    #DB TEST 14
    b21rejBG = np.copy(b21CloudWaterMasked)
    b21rejBG[np.where(bgMask != bgFlag)] = bgFlag #Evalate pixels rejected as BG
    b21rejMeanFilt = runFilt(b21rejBG,meanFilt,minKsize,maxKsize,0)
    dbTest14 = np.zeros((nRows,nCols),dtype=np.int)
    with np.errstate(invalid='ignore'):
        dbTest14[(b21rejMeanFilt<345)&(b21rejMeanFilt != -4)] = 1
    
    #DB TEST 15
    dbTest15 = np.zeros((nRows,nCols),dtype=np.int)
    with np.errstate(invalid='ignore'):
        dbTest15[(b21rejMADfilt<3)&(b21rejMeanFilt != -4)] = 1
    
    #DB TEST 16
    dbTest16 = np.zeros((nRows,nCols),dtype=np.int)
    with np.errstate(invalid='ignore'):
        dbTest16[(b21CloudWaterMasked<(b21rejMeanFilt+(6*b21rejMADfilt)))&(b21rejMADfilt != -4)&(b21rejMeanFilt != -4)] = 1
    
    #REJECT ANYTHING THAT FULFILLS ALL DESERT BOUNDARY CRITERIA
    dbAll = dbTest11*dbTest12*dbTest13*dbTest14*dbTest15*dbTest16
    
    #COASTAL FALSE ALARM REJECTION
    with np.errstate(invalid='ignore'):
        ndvi = (allArrays['BAND2x1k']+allArrays['BAND1x1k'])/(allArrays['BAND2x1k']+allArrays['BAND1x1k'])
    unmaskedWater = np.zeros((nRows,nCols),dtype=np.int)
    uwFlag = -6
    with np.errstate(invalid='ignore'):
        unmaskedWater[((ndvi<0) & (allArrays['BAND7x1k']<50)&(allArrays['BAND2x1k']<150))] = -6
        unmaskedWater[(bgMask == bgFlag)] = bgFlag
    Nuw = runFilt(unmaskedWater,nUnmaskedWaterFilt,minKsize,maxKsize,1)
    rejUnmaskedWater = np.zeros((nRows,nCols),dtype=np.int)
    with np.errstate(invalid='ignore'):
        rejUnmaskedWater[(absValTest == 0) & (Nuw>0)] = 1
    
    #COMBINE ALL MASKS
    allFires = dayFires+nightFires #ALL POTENTIAL FIRES
    with np.errstate(invalid='ignore'): #REJECT SUNGLINT, DESERT BOUNDARY, COASTAL FALSE ALARMS
        allFires[(sgAll == 1) | (dbAll == 1) | (rejUnmaskedWater == 1)] = 0
    
    ###############
    #CALCULATE FRP
    ###############
    b21firesAllMask = allFires*allArrays['BAND21']
    b21bgAllMask = allFires*b21meanFilt
    
    b21maskEXP = b21firesAllMask.astype(float)**8
    b21bgEXP = b21bgAllMask.astype(float)**8
    
    #frpMW = 4.34 * (10**(-19)) * (b21maskEXP-b21bgEXP)  
    frpMW = 4.34e-19 * (b21maskEXP-b21bgEXP)  

    ##################
    ##AREA CALCULATION
    ##################
    ##S = (I-hp)/H
    ##
    ##where:
    ##
    ##I is the zero-based pixel index
    ##hp is 1/2 the total number of pixels (zero-based)
    ##    (for MODIS each scan is 1354 "1km" pixels, 1353 zero-based, so hp = 676.5)
    ##H is the sensor altitude divided by the pixel size
    ##    (for MODIS altitude is approximately 700km, so for "1km" pixels, H = 700/1)
    
    I = np.indices((nRows,nCols))[1]
    hp = 676.6
    H = 700
    
    S = (I-hp)/H
    
    ##Compute the zenith angle:
    Z = np.arcsin(1.111*np.sin(S))
    
    ##Compute the Along-track pixel size:
    Pn = 1 #Pixel size in km at nadir
    Pt = Pn*9*np.sin(Z-S)/np.sin(S)
    
    ##Compute the Along-scan pixel size:
    Ps = Pt/np.cos(Z)
    
    areaKmSq = Pt * Ps
    
    frpMwKmSq = frpMW/areaKmSq
    
    with np.errstate(invalid='ignore'):
        inds=np.where((frpMwKmSq>0)&(frpMwKmSq<1000)) #>1000 FRP ARE NOISE
    FRPlats = allArrays['LAT'][inds]
    FRPlons =allArrays['LON'][inds]
    FrpInds = frpMwKmSq[inds]
    exportCSV = np.column_stack([FRPlons,FRPlats,FrpInds])
    np.savetxt(filNam+'frp_{}.csv'.format(procid), exportCSV, delimiter=",")
    
    #end = t.clock()
    #print 'Runtime = {} seconds'.format(end-start)

run("data",0)
