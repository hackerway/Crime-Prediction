#pts = read.csv('/Users/thomasbedor/Google Drive/School 13/Pattern Recognition/Crime Project/code/test.csv ')
pts = read.csv('test.csv')
oreg <- map('state', region=('oregon'))



idx = sample(1:dim(pts)[1], 1000)

pts_samp <- pts[idx,]

x <- pts_samp[,1]
x <- pts_samp[,2]

px <- runif(5000, min = min(x), max = max(x))
py <- runif(5000, min = min(y), max = max(y))

p<- list(data.frame(px,py))
z <- rnorm(1000)


kriged <- kriging(x,y,z, polygons=p, pixels=300)
kriged <- kriging
image(kriged, xlim=extendrange(x), ylim=extendrange(y))


# Krige random data for a specified area using a list of polygons
library(maps)
usa <- map("usa", "main", plot = FALSE)
p <- list(data.frame(usa$x, usa$y))

# Create some random data
x <- runif(50, min(p[[1]][,1]), max(p[[1]][,1]))
y <- runif(50, min(p[[1]][,2]), max(p[[1]][,2]))
z <- rnorm(50)


