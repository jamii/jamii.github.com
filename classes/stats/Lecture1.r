library(foreign)

d <- as.data.frame(read.spss("~/classes/stats/IQscores.sav"))
summary(d)

plot(density(d$IQ))

hist(d$IQ, breaks=10)

Mode <- function(x) {
  ux <- unique(x)
  nx <- tabulate(match(x, ux))
  maxid <- which(nx == max(nx))
  if(length(maxid) > 1) {
    warning("There are multiple modes, only the first value is returned, other modes are at: ",paste(ux[maxid[2:length(maxid)]],collapse=", "))
  }
  ux[maxid[1]]
}

c(mean(d$IQ), Mode(d$IQ), median(d$IQ))

d$predicted <- 100

c(
    sum(d$predicted != IQ$IQ), 
    sum(abs(d$predicted - IQ$IQ)), 
    sum((d$predicted - IQ$IQ) ** 2)
)

c(
    sum(Mode(d$IQ) != d$IQ),
    sum(abs(median(d$IQ) - d$IQ)),
    sum((mean(d$IQ) - d$IQ) ** 2)
)
