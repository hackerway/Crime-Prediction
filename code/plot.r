setwd('/Users/thomasbedor/Google Drive/School 13/Pattern Recognition/Crime Project/code')
d <- read.csv('pd911_lat_long.csv')
d <- sapply(d, as.numeric)
#plot(d[,2], d[,1])
quantile(d[,1],c(.1,.9))
idx <- sample(1:dim(d)[1], dim(d)[1]/4)

d <- d[idx,]

df <- data.frame(x=d[,2],y=d[,1])
k <- with(df,MASS:::kde2d(x,y))


filled.contour(k)
via ggplot (geom_density2d() calls kde2d())
library(ggplot2)
ggplot(df,aes(x=x,y=y))+geom_density2d()


library(hexbin)
smoothScatter(d[,2],d[,1], xlab='longitude', ylab='latitude')

library(RgoogleMaps)

help(GetMap)

lat <- d[,1]
lon <- d[,2]
center = c(mean(lat), mean(lon));
zoom <- min(MaxZoom(range(c(47.51,47.7)), range(c(-122.4,-122.26))));

#plot(density(lat))


MyMap <- GetMap(center=center, zoom=zoom, RETURNIMAGE=TRUE)
PlotOnStaticMap(MyMap,lat=lat,lon=lon,FUN=points, cex =.1)

mjd <- sapply(mjd, as.numeric)
plot(density(mjd))

mjd <- read.csv('mjdDistro.csv')
plot(density(mjd))

# heat map

setwd('/Users/thomasbedor/Google Drive/School 13/Pattern Recognition/Crime Project/code')
d <- read.csv('pd911_main.csv')
d <- d[,-c(1,2,3)]
#names <- read.csv('results/names.csv')
names <- c('Disturbances','Arrest','Mental Health','Burglary','Liquor Violations','Traffic Related Calls','Suspicious Circumstances','False Alarms','Trespass','Hazards','Miscellaneous Misdemeanors','Car Prowl','Shoplifting','Reckless Burning','Prostitution','Accident Investigation','Property Damage','Other Property','Auto Thefts','Narcotics Complaints','Prowler','Threats Harassment','Bike','Property  Missing Found','Person Down Injury','Nuisance Mischief','Assaults','Harbor Calls','Persons  Lost Found Missing','Robbery','Weapons Calls','Lewd Conduct','Animal Complaints','Drive By No Injury','Fraud Calls','Failure To Register Sex Offender','Other Vice','Homicide','Vice Calls','Nuisance Mischief ')

cor_mat <- matrix(nrow = length(d), ncol = length(d))
for (i in 1:length(d)){
	cor_mat[i,] <- cor(d[,i], d)
	
}

for (i in 1:40){
	for (j in 1:40){
		if (i>=j){
			cor_mat[i,j]=0
			
		}
		
	}
	
	
}

colnames(cor_mat) = names
rownames(cor_mat ) = names
cor_mat2 = matrix(cor_mat, ncol=1)
cor_mat2[which(cor_mat2>.99999999)] = 0
tops = order(cor_mat2, decreasing=TRUE)[c(1:5)]
cor_mat2[42] == cor_mat[1,2]
