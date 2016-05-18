sink("data.csv")
cat("FRPline,FRPsample,FRPlats,FRPlons,FRPT21,FRPT31,FRPMeanT21,FRPMeanT31,FRPMeanDT,FRPMADT21,FRPMADT31,FRP_MAD_DT,FRPpower,FRP_AdjCloud,FRP_AdjWater,FRP_NumValid,FRP_confidence")
sink()
system("grep -v --no-filename \"#\" MOD* >> data.csv")

numjobs <- 16

#Fixed parameters
minLat <- 62
maxLat <- 68.6
minLon <- -162
maxLon <- -140

tabsize <- 0.1 #Level of overlap between tiles, as fraction of shortest side of tile

#Inferred parameters
ntilex <- floor(sqrt(numjobs))
ntiley <- floor(numjobs/ntilex)
tilex <- abs(maxLon-minLon)/ntilex
tiley <- abs(maxLat-minLat)/ntiley
tabsize <- tabsize * min(tilex, tiley)

data <- read.csv("data.csv", head=TRUE, comment.char="#")
plot(data$FRPlats, data$FRPlons, cex=0.1, xlim=c(62,68.6), ylim=c(-162,-140), xlab="Lat", ylab="Lon")
lats2 <- as.numeric(names(which(table(data$FRPlats)==2)))
n <- match(lats2,data$FRPlats)
points(data$FRPlats[n], data$FRPlons[n], cex=0.1, col="red")

for (i in seq(0,numjobs-1)) {
	yi = floor(i/ntilex)
	xi = floor(ntilex*(i/ntilex-yi))

	ax = minLon+xi*tilex
	ay = minLat+yi*tiley
	bx = ax+tilex
	by = ay+tiley
	if (xi>0) { ax <- ax-tabsize }
    if (yi>0) { ay <- ay-tabsize }
    print(c(xi,yi,ax,ay,bx,by))
	lines(c(ay,ay,by,by,ay),c(ax,bx,bx,ax,ax))
}

