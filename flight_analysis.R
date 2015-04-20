
setwd('D://SeedScientific')
data <- read.csv('data/raw/2013Jan_T_ONTIME.csv')
data_airports <- read.csv('data/raw/airports.csv')


#######################################################################
#### Map of delay statistics 
#######################################################################

library(sp) 

# Get aggregated delay statistics by airport
prop_delay <- aggregate(DEP_DEL15 ~ ORIGIN, data = data, function(x) mean(x, na.rm=TRUE))
mean_delay <- aggregate(DEP_DELAY ~ ORIGIN, data = data, function(x) mean(x, na.rm=TRUE))

delay_by_airport <- merge(prop_delay, mean_delay, by = "ORIGIN")
delay_by_airport <- merge(data_airports, delay_by_airport,
                              by.x = "iata", by.y = "ORIGIN")


# Spatial data frame of airports
sp_airports <- cbind(delay_by_airport$long, delay_by_airport$lat)
colnames(sp_airports) <- c("long", "lat")
delay_by_airport_spdf <- SpatialPointsDataFrame(coords = sp_airports,
                                                data = delay_by_airport,
                                                proj4string = CRS("+proj=utm +zone=17 +datum=WGS84"))


# Select only airports on continental USA, and normalize for plotting parameters
selectRow <- delay_by_airport_spdf$long > -130 & delay_by_airport_spdf$lat > 20
delay_by_airport_spdf <- delay_by_airport_spdf[selectRow, ]

delay_by_airport_spdf$DEP_DEL15 <- delay_by_airport_spdf$DEP_DEL15 / max(delay_by_airport_spdf$DEP_DEL15)

max_delay <- max(delay_by_airport_spdf$DEP_DELAY)
delay_by_airport_spdf$DEP_DELAY <- sapply(delay_by_airport_spdf$DEP_DELAY, function(x) max(x,0))
delay_by_airport_spdf$DEP_DELAY <- delay_by_airport_spdf$DEP_DELAY / max(delay_by_airport_spdf$DEP_DELAY)


# Plot proportion of delays (size of dot) and mean delays (color)
ramp <- colorRamp(c("blue", "red"), space = "rgb")
rampPalette <- colorRampPalette(c("blue", "red"))
cols <- ramp( (delay_by_airport_spdf$DEP_DELAY) ) / 256

library(maptools)
load("./data/raw/statesth.RData")
plot(statesth)
points(delay_by_airport_spdf, pch=16,
     cex = 3*delay_by_airport_spdf$DEP_DEL15,
     col = apply(cols, 1, function(x) rgb(x[1], x[2], x[3])) )
library(plotrix)
color.legend(-65,25,-63,50, legend = c(0,8,16,24,32), gradient='y',
             rect.col = rampPalette(100), align='rb')




#######################################################################
#### Flights to and from JFK
#######################################################################

airport_code <- 'JFK'
selectRows <- data$DEST == airport_code & data$DISTANCE > 100
toDest <- data[selectRows,]
fromOrig <- data[data$ORIGIN == airport_code, ]
origin <- aggregate(DISTANCE ~ ORIGIN, data = toDest, function(x) x[1])
destination <- aggregate(DISTANCE ~ DEST, data = fromOrig, function(x) x[1])

## Plot delayed arrivals into JFK, by day
fromOrig$FL_DAY <- as.integer(substr(as.character(fromOrig$FL_DATE), 9, 10))
boxplot(DEP_DELAY ~ FL_DAY, data = fromOrig[fromOrig$DEP_DELAY < 500,], 
        xlab = 'Day of January 2013', ylab = 'Departure Delay (minutes)')


#######################################################################
## Heat map of mean delay, by airport and date flown
#######################################################################

delay_stats <- aggregate(ARR_DELAY ~ ORIGIN + FL_DAY, data = toDest, function(x) mean(x, na.rm=T))

# Get indices for matrix
delay_stats$ORIGIN_IDX <- sapply(delay_stats$ORIGIN, 
                                 function(x) which(origin == as.character(x)))

# Create matrix
ndays <- 31
nairports <- dim(origin)[1]
delay_mtx <- matrix(rep(0, ndays * nairports), ncol = ndays)
for (i in 1:dim(delay_stats)[1]) {
  delay_mtx[delay_stats$ORIGIN_IDX[i], delay_stats$FL_DAY[i]] <- delay_stats$ARR_DELAY[i]
}
rownames(delay_mtx) <- origin$ORIGIN

# Plot heatmap
heatmap(delay_mtx, scale = "col", margins = c(2.5,3), xlab='Day of Jan 2013')


#######################################################################
#### Effect of weather
#######################################################################

# Get daily weather data for JFK (Station code 'GHCND:USW00094789')
data_GHCN <- read.csv('data/raw/GHCN_Daily_NYC.csv')
cols <- c(which(names(data_GHCN) %in% c("STATION_NAME", "DATE", "PRCP", "TMAX", "TMIN", "AWND", "WSF2")),
          seq(37,117,5))
data_GHCN <- data_GHCN[data_GHCN$STATION == 'GHCND:USW00094789', cols]

for (i in 8:(dim(data_GHCN)[2])) { data_GHCN[, i] <- as.integer(data_GHCN[, i] == 1) }
data_GHCN$DAY <- as.integer(substr(as.character(data_GHCN$DATE), 7,8))


# Type of delay: DEP_DELAY, ARR_DELAY, WEATHER_DELAY, NAS_DELAY, etc.
delay_type <- 'DEP_DELAY'
df <- fromOrig[, which(names(fromOrig) %in% c('FL_DATE', delay_type))]
names(df)[which(names(df)==delay_type)] <- 'DELAY'

delay_stats <- aggregate(DELAY ~ FL_DATE, data = df, function(x) mean(x, na.rm=T))
delay_stats$FL_DAY <- as.integer(substr(as.character(delay_stats$FL_DATE), 9, 10))

delay_stats <- merge(delay_stats, data_GHCN, by.x = 'FL_DAY', by.y = 'DAY')


# plot correlations between weather features and mean delay time
plot(delay_stats[, which(names(delay_stats) %in% c('DELAY', 'PRCP', 'TMAX', 'TMIN', 'AWND', 'WSF2'))])


# Using linear regression ...
clf <- lm( DELAY ~ ., data = delay_stats[, c(3, 6:7, 9, 12:13, 20:22, 24)] )
summary(clf)


