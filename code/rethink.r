p_grid <- seq(from=0, to=1, length.out=1000)
prior <- rep(1,1000)
likelihood <- dbinom(6, size=9, prob=p_grid)
posterior <- likelihood * prior
posterior <- posterior / sum(posterior)
plot(posterior, x=p_grid)

samples = sample(p_grid, prob=posterior, size=1e4, replace=TRUE)
plot(samples)
library(rethinking)
dens(samples)
sum(posterior[p_grid < 0.5])
sum(samples < 0.5) / length(samples)
sum(samples > 0.5 & samples < 0.75) / length(samples)

dbinom(0:2, size=2, prob=0.7)
dummy_w <- rbinom(1e5, size=2, prob=0.7)
table(dummy_w)/1e5

w <- rbinom(1e4, size=9, prob=0.6)
simplehist(w)
w <- rbinom(1e4, size=9, prob=samples)
simplehist(w)

loss <- sapply(p_grid, function(d) sum(posterior*abs(d - p_grid)))
loss
p_grid[which.min(loss)]

p_grid <- seq(from=0, to=1, length.out=1000)
prior <- rep(1, 1000)
likelihood <- dbinom(6, size=9, prob=p_grid)
posterior <- likelihood * prior
posterior <- posterior / sum(posterior)
set.seed(100)
samples <- sample(p_grid, prob=posterior, size=1e4, replace=TRUE)

sum(posterior[p_grid < 0.2])
sum(posterior[p_grid > 0.8])
sum(posterior[p_grid < 0.2 | p_grid > 0.8])
quantile(samples, 0.2)
quantile(samples, 0.8)
HPDI(samples, prob=0.66)
quantile(samples, c(0.33/2, 1-(0.33/2)))

p_grid <- seq(from=0, to=1, length.out=1000)
prior <- rep(1, 1000)
likelihood <- dbinom(8, size=15, prob=p_grid)
posterior <- likelihood * prior
posterior <- posterior / sum(posterior)
set.seed(100)
samples <- sample(p_grid, prob=posterior, size=1e5, replace=TRUE)
plot(posterior)
HPDI(samples, prob=0.9)
dens(samples)
tight_w <- rbinom(length(samples), size=15, prob=p_grid[which.max(posterior)])
simplehist(tight_w)
dummy_w <- rbinom(length(samples), size=15, prob=samples)
simplehist(dummy_w)
sum(dummy_w == 8) / length(dummy_w)
dummy_w <- rbinom(length(samples), size=9, prob=samples)
sum(dummy_w == 8) / length(dummy_w)

p_grid <- seq(from=0, to=1, length.out=1000)
prior <- sapply(1:1000, function(i) if (i < 500) 0 else 1)
likelihood <- dbinom(8, size=15, prob=p_grid)
posterior <- likelihood * prior
posterior <- posterior / sum(posterior)
set.seed(100)
samples <- sample(p_grid, prob=posterior, size=1e5, replace=TRUE)
plot(posterior)
sum(posterior)
HPDI(samples, prob=0.9)
dens(samples)
tight_w <- rbinom(length(samples), size=15, prob=p_grid[which.max(posterior)])
simplehist(tight_w)
dummy_w <- rbinom(length(samples), size=15, prob=samples)
simplehist(dummy_w)
sum(dummy_w == 8) / length(dummy_w)
dummy_w <- rbinom(length(samples), size=9, prob=samples)
sum(dummy_w == 8) / length(dummy_w)

# male=1
library(rethinking)
data(homeworkch3)
sum(birth1) + sum(birth2)

p_grid <- seq(from=0, to=1, length.out=1000)
prior <- rep(1, 1000)
likelihood <- dbinom(111, size=200, prob=p_grid)
posterior <- likelihood * prior
posterior <- posterior / sum(posterior)
plot(posterior)
p_grid[which.max(posterior)]
samples <- sample(p_grid, prob=posterior, size=1e5, replace=TRUE)
HPDI(samples, p=c(0.5, 0.89, 0.97))
dummy <- rbinom(1e5, size=200, prob=samples)
simplehist(dummy)
sum(birth1)
dummy <- rbinom(1e5, size=100, prob=samples)
simplehist(dummy)

birth_after_f <- birth2[birth1 == 0]
length(birth_after_f)
sum(birth_after_f)

dummy <- rbinom(1e5, size=49, prob=samples)
simplehist(dummy)

library(rethinking)
data(Howell1)
d <- Howell1
d
d2 <- d[d$age >= 18,]
dens(d2$height)

flist <- alist(
  height ~ dnorm(mu, sigma),
  mu ~ dnorm(178, 20),
  sigma ~ dunif(0, 50)
  )
start <- list(
  mu=mean(d2$height), 
  sigma=sd(d2$height)
)
m4.1 <- map(flist, data=d2, start=start)
precis(m4.1)

m4.2 <- map(
  alist(
    height ~ dnorm( mu , sigma ) ,
    mu ~ dnorm( 178 , 1 ) , 
    sigma ~ dunif( 0 , 50 )
  ) ,
  data=d2 
)
precis( m4.2 )

vcov(m4.1)
diag(vcov(m4.1))
cov2cor(vcov(m4.1))

post <- extract.samples(m4.1, n=1e4)
dens(post)
post
plot(post)
plot(d2$height ~ d2$weight)

m4.3 <- map(
  alist(
    height ~ dnorm(mu, sigma),
    mu <- a + b*weight,
    a ~ dnorm(178, 100),
    b ~ dnorm(0, 10),
    sigma ~ dunif(0, 50)
    ),
    data=d2
    )
precis(m4.3)
plot(extract.samples(m4.3, n=1e4))
cov2cor(vcov(m4.3))

plot(height ~ weight, data=d2)
abline(a=coef(m4.3)["a"], b=coef(m4.3)["b"])

N <- 20
dN <- d2[,]
mN <- map(
  alist(
    height ~ dnorm(mu, sigma),
    mu <- a + b*weight,
    a ~ dnorm(178, 100),
    b ~ dnorm(0, 10),
    sigma ~ dunif(0, 50)
    ),
    data=dN
    )
post <- extract.samples(mN, n=20)
plot(dN$weight, dN$height, xlim=range(d2$weight), ylim=range(d2$height), col=rangi2, xlab="weight", ylab="height")
mtext(concat("N = ", N))
for (i in 1:20)
  abline(a=post$a[i], b=post$b[i], col=col.alpha("black",0.3))
  

mu <- link(m4.3)
str(mu)
weight.seq <- seq(from=25, to=70, by=1)
mu <- link(m4.3, data=data.frame(weight=weight.seq))
str(mu)
plot(height ~ weight, d2, type="n")
for (i in 1:100)
  points(weight.seq, mu[i,], pch=16, col=col.alpha(rangi2,0.1))
  
mu.mean <- apply(mu, 2, mean)
mu.HPDI <- apply(mu, 2, HPDI, prob=0.89)

plot(height ~ weight, data=d2, col=col.alpha(rangi2,0.5))
lines(weight.seq, mu.mean)
shade(mu.HPDI, weight.seq)

sim.height <- sim(m4.3, data=list(weight=weight.seq), n=1e4)
height.PI <- apply(sim.height, 2, PI, prob=0.89)
plot(height ~ weight, d2, col=col.alpha(rangi2,0.5))
lines(weight.seq, mu.mean)
shade(mu.HPDI, weight.seq)
height.PI <- apply(sim.height, 2, PI, prob=0.89)
shade(height.PI, weight.seq)
height.PI <- apply(sim.height, 2, PI, prob=0.67)
shade(height.PI, weight.seq)

data(Howell1)
d <- Howell1
d$weight.s <- (d$weight - mean(d$weight))/sd(d$weight)
d$weight.s2 <- d$weight.s^2
m4.5 <- map(
alist(
height ~ dnorm( mu , sigma ) ,
mu <- a + b1*weight.s + b2*weight.s2 ,
a ~ dnorm( 178 , 100 ) ,
b1~dnorm(0,10),
b2~dnorm(0,10),
sigma ~ dunif( 0 , 50 )
) , 
data=d )
precis(m4.5)
plot(d)

weight.seq <- seq(from=-2.2, to=2, length.out=30)
pred_dat <- list(weight.s=weight.seq, weight.s2=weight.seq^2)
mu <- link(m4.5, data=pred_dat)
mu.mean <- apply(mu, 2, mean)
mu.PI <- apply(mu, 2, PI, prob=0.89)
sim.height <- sim(m4.5, data=pred_dat)
height.PI <- apply(sim.height, 2, PI, prob=0.89)
plot(height ~ weight.s, d, col=col.alpha(rangi2,0.5))
lines(weight.seq, mu.mean)
shade(mu.PI, weight.seq)
shade(height.PI, weight.seq)

d$weight.s3 <- d$weight.s^3 
m4.6 <- map(
alist(
height ~ dnorm( mu , sigma ) ,
mu <- a + b1*weight.s + b2*weight.s2 + b3*weight.s3 ,
a ~ dnorm( 178 , 100 ) ,
b1~dnorm(0,10),
b2~dnorm(0,10),
b3~dnorm(0,10),
sigma ~ dunif( 0 , 50 )
) , 
data=d )

d$weight.s3 <- d$weight.s^3
weight.seq <- seq(from=-2.2, to=2, length.out=30)
pred_dat <- list(weight.s=weight.seq, weight.s2=weight.seq^2, weight.s3=weight.seq^3)
mu <- link(m4.6, data=pred_dat)
mu.mean <- apply(mu, 2, mean)
mu.PI <- apply(mu, 2, PI, prob=0.89)
sim.height <- sim(m4.6, data=pred_dat)
height.PI <- apply(sim.height, 2, PI, prob=0.89)
plot(height ~ weight.s, d, col=col.alpha(rangi2,0.5))
lines(weight.seq, mu.mean)
shade(mu.PI, weight.seq)
shade(height.PI, weight.seq)

mu <- rnorm(0, 10, n=1e4)
sigma <- runif(0, 10, n=1e4)
y <- rnorm(mean=mu, sd=sigma, n=length(mu))
i = 1:1000
z <- double(1e4)
for (i in 1:1e4)
  z[i] <- rnorm(mean=mu[i], sd=sigma[i], n=1)
dens(y)
dens(z)

flist <- alist(
  height ~ Norm(mu, sigma),
  mu <- a + b * year,
  a ~ Norm(120, 50),
  b ~ Uniform(0, 50),
  sigma ~ Uniform(0, 50),
  )
  
sim.height <- sim(m4.3, data=list(weight=c(46.95)), n=1e4)
dens(sim.height)
HPDI(sim.height, 0.89)

d <- Howell1[Howell1$age < 18,]

plot(d)

m4h2 <- map(
  alist(
    height ~ dnorm(mu, sigma),
    mu <- a + b * weight,
    a ~ dnorm(120, 50),
    b ~ dnorm(0, 100),
    sigma ~ dunif(0, 50)
    ),
    data=d)
precis(m4h2)

w_seq = seq(from=min(d$weight), to=max(d$weight), length.out=100)
link.height <- link(m4h2, data=list(weight=w_seq), n=1e5)
link.mu = apply(link.height, 2, mean)
link.hpdi = apply(link.height, 2, HPDI, prob=0.89)
sim.height <- sim(m4h2, data=list(weight=w_seq), n=1e5)
sim.hpdi = apply(sim.height, 2, HPDI, prob=0.89)
plot(height ~ weight, data=d, col=rgb(0,0,age / max(d$age)))
plot(d)
panel.superpose(height ~ weight, data=d[d$male == 0,], col="blue")
points
lines(w_seq, link.mu)
shade(link.hpdi, w_seq)
shade(sim.hpdi, w_seq)
dim(sim.height)
dim(sim.height)
dens(sim.height[,1])
plot(sim.height)
    
data(Howell1)
d <- Howell1
m4h3 <- map(
  alist(
    height ~ dnorm(mu, sigma),
    mu <- a + b * log(weight),
    a ~ dnorm(178, 100),
    b ~ dnorm(0, 100),
    sigma ~ dunif(0, 50)
    ),
    data=d)
  precis(m4h3)
  
w_seq = seq(from=min(d$weight), to=max(d$weight), length.out=100)
link.height <- link(m4h3, data=list(weight=w_seq), n=1e5)
link.mu = apply(link.height, 2, mean)
link.hpdi = apply(link.height, 2, HPDI, prob=0.89)
sim.height <- sim(m4h3, data=list(weight=w_seq), n=1e5)
sim.hpdi = apply(sim.height, 2, HPDI, prob=0.89)
plot(height ~ weight, data=d, col=col.alpha(rangi2,0.4))
lines(w_seq, link.mu)
shade(link.hpdi, w_seq)
shade(sim.hpdi, w_seq)

# load data
library(rethinking) 
data(WaffleDivorce) 
d <- WaffleDivorce
# standardize predictor
d$MedianAgeMarriage.s <- (d$MedianAgeMarriage-mean(d$MedianAgeMarriage))/
sd(d$MedianAgeMarriage)
# fit model 
m5.1 <- map(
alist(
Divorce ~ dnorm( mu , sigma ) ,
mu <- a + bA * MedianAgeMarriage.s ,
a~dnorm(10,10),
bA~dnorm(0,1),
sigma ~ dunif( 0 , 10 )
),data=d)

# compute percentile interval of mean
MAM.seq <- seq( from=-3 , to=3.5 , length.out=30 )
mu <- link( m5.1 , data=data.frame(MedianAgeMarriage.s=MAM.seq) )
mu.PI <- apply( mu , 2 , PI )
# plot it all
plot( Divorce ~ MedianAgeMarriage.s , data=d , col=rangi2 ) 
abline( m5.1 )
shade( mu.PI , MAM.seq )

d$Marriage.s <- (d$Marriage - mean(d$Marriage))/sd(d$Marriage)

m5.3 <- map(
alist(
Divorce ~ dnorm( mu , sigma ) ,
mu <- a + bR*Marriage.s + bA*MedianAgeMarriage.s ,
a~dnorm(10,10),
bR~dnorm(0,1),
bA~dnorm(0,1),
sigma ~ dunif( 0 , 10 )
) , 
data=d)
precis( m5.3 )
plot(precis(m5.3))

# call link without specifying new data
# so it uses original data
mu <- link( m5.3 )
# summarize samples across cases 
mu.mean <- apply( mu , 2 , mean ) 
mu.PI <- apply( mu , 2 , PI )
# simulate observations
# again no new data, so uses original data 
divorce.sim <- sim( m5.3 , n=1e4 )
divorce.PI <- apply( divorce.sim , 2 , PI )

plot( mu.mean ~ d$Divorce , col=rangi2 , ylim=range(mu.PI) ,
xlab="Observed divorce" , ylab="Predicted divorce" )
abline( a=0 , b=1 , lty=2 )
for ( i in 1:nrow(d) )
lines( rep(d$Divorce[i],2) , c(mu.PI[1,i],mu.PI[2,i]) ,
col=rangi2 )

# compute residuals
divorce.resid <- d$Divorce - mu.mean
# get ordering by divorce rate
o <- order(divorce.resid)
# make the plot
dotchart( divorce.resid[o] , labels=d$Loc[o] , xlim=c(-6,5) , cex=0.6 ) 
abline( v=0 , col=col.alpha("black",0.2) )
for ( i in 1:nrow(d) ) {
j <- o[i] # which State in order
lines( d$Divorce[j]-c(mu.PI[1,j],mu.PI[2,j]) , rep(i,2) )
points( d$Divorce[j]-c(divorce.PI[1,j],divorce.PI[2,j]) , rep(i,2),
pch=3 , cex=0.6 , col="gray" )
}

library(rethinking) 
data(milk)
d <- milk 
str(d)

dcc <- d[ complete.cases(d) ,]

m5.5 <- map(
  alist(
    kcal.per.g ~ dnorm( mu , sigma ) ,
    mu <- a + bn*neocortex.perc ,
    a ~ dnorm( 0 , 100 ) ,
    bn ~ dnorm( 0 , 1 ) ,
    sigma ~ dunif( 0 , 1 )
    ) ,
    data=dcc )
    
plot(dcc)
    
precis(m5.5, digits=5)

np.seq <- 0:100
pred.data <- data.frame( neocortex.perc=np.seq )
mu <- link( m5.5 , data=pred.data , n=1e4 )
mu.mean <- apply( mu , 2 , mean )
mu.PI <- apply( mu , 2 , PI )
plot( kcal.per.g ~ neocortex.perc , data=dcc , col=rangi2 )
lines( np.seq , mu.mean )
lines( np.seq , mu.PI[1,] , lty=2 )
lines( np.seq , mu.PI[2,] , lty=2 )

dcc$log.mass <- log(dcc$mass)

m5.6 <- map(
  alist(
    kcal.per.g ~ dnorm(mu, sigma),
    mu <- a + bm*log.mass,
    a ~ dnorm(0,100),
    bm ~ dnorm(0,1),
    sigma ~ dunif(0,1)
    ),
    data=dcc)
precis(m5.6)

np.seq <- seq(min(dcc$log.mass), max(dcc$log.mass), length.out=100)
pred.data <- data.frame( log.mass=np.seq )
mu <- link( m5.6 , data=pred.data , n=1e4 )
mu.mean <- apply( mu , 2 , mean )
mu.PI <- apply( mu , 2 , PI )
plot( kcal.per.g ~ log.mass , data=dcc , col=rangi2 )
lines( np.seq , mu.mean )
lines( np.seq , mu.PI[1,] , lty=2 )
lines( np.seq , mu.PI[2,] , lty=2 )

m5.7 <- map(
  alist(
    kcal.per.g ~ dnorm(mu, sigma),
    mu <- a + bn*neocortex.perc + bm*log.mass,
    a ~ dnorm(0, 100),
    bn ~ dnorm(0, 1),
    bm ~ dnorm(0, 1),
    sigma ~ dunif(0,1)
    ),
    data=dcc,
    start=list(
      a = mean(dcc$kcal.per.g),
      bn = 0,
      bm = 0,
      sigma = 0.5
    )
    )
    
precis(m5.7)

mean.log.mass <- mean( log(dcc$mass) )
np.seq <- 0:100
pred.data <- data.frame(
neocortex.perc=np.seq,
log.mass=mean.log.mass
)
mu <- link( m5.7 , data=pred.data , n=1e4 )
mu.mean <- apply( mu , 2 , mean )
mu.PI <- apply( mu , 2 , PI )
plot( kcal.per.g ~ neocortex.perc , data=dcc , type="n" )
lines( np.seq , mu.mean )
lines( np.seq , mu.PI[1,] , lty=2 )
lines( np.seq , mu.PI[2,] , lty=2 )

mean.neocortex.perc <- mean(dcc$neocortex.perc)
np.seq <- seq(min(dcc$log.mass), max(dcc$log.mass), length.out=100)
pred.data <- data.frame(
log.mass=np.seq,
neocortex.perc=mean.neocortex.perc
)
mu <- link( m5.7 , data=pred.data , n=1e4 )
mu.mean <- apply( mu , 2 , mean )
mu.PI <- apply( mu , 2 , PI )
plot( kcal.per.g ~ log.mass , data=dcc, type='n'  )
lines( np.seq , mu.mean )
lines( np.seq , mu.PI[1,] , lty=2 )
lines( np.seq , mu.PI[2,] , lty=2 )

pairs(d)

d$clade.NWM <- ifelse( d$clade=="New World Monkey" , 1 , 0 )
d$clade.OWM <- ifelse( d$clade=="Old World Monkey" , 1 , 0 )
d$clade.S <- ifelse( d$clade=="Strepsirrhine" , 1 , 0 )

( d$clade_id <- coerce_index(d$clade) )

m5.16_alt <- map(
  alist(
    kcal.per.g ~ dnorm( mu , sigma ) ,
    mu <- a[clade_id] ,
    a[clade_id] ~ dnorm( 0.6 , 10 ) ,
    sigma ~ dunif( 0 , 10 )
    ) ,
    data=d )
    precis( m5.16_alt , depth=2 )
    
data(WaffleDivorce)
d <- WaffleDivorce
d
plot(Marriage ~ Divorce, d)
plot(d)

install.packages("htmltab")
library(htmltab)
doc <- htmltab("https://en.wikipedia.org/wiki/The_Church_of_Jesus_Christ_of_Latter-day_Saints_membership_statistics_(United_States)", 2)
doc
doc$State == d$Location
doc$Location <- doc$State

dd = merge(d, doc, by="Location")
dd$LDS.n <- as.numeric(sub("%","",dd$LDS))
dd$LDS.s <- (dd$LDS.n - mean(dd$LDS.n)) / sd(dd$LDS.n)
ddd <- dd[complete.cases(dd),]

m5.5a <- map(
  alist(
    Divorce ~ dnorm(mu, sigma),
    mu <- a + c*MedianAgeMarriage.s,
    a ~ dnorm(0, 100),
    c ~ dnorm(0, 1),
    sigma ~ dunif(0, 100)
    ), data=ddd)
    
    sim.divorce <- link(m5.5a, data=ddd)
    sim.divorce.mean <- apply(sim.divorce, 2, mean)
    ddd$predicted <- sim.divorce.mean
    ddd$residual <- ddd$Divorce - ddd$predicted
    plot(predicted ~ Divorce, ddd)
    plot(residual ~ log(LDS.n), ddd)  

m5.5 <- map(
  alist(
    Divorce ~ dnorm(mu, sigma),
    mu <- a + b*LDS.s + c*MedianAgeMarriage.s,
    a ~ dnorm(0, 100),
    b ~ dnorm(0, 1),
    c ~ dnorm(0, 1),
    sigma ~ dunif(0, 100)
    ), data=ddd)

sim.divorce <- link(m5.5, data=ddd)
sim.divorce.mean <- apply(sim.divorce, 2, mean)
ddd$predicted <- sim.divorce.mean
plot(predicted ~ Divorce, ddd)

library(rethinking)
data(foxes)
d <- foxes
d$groupsize.s <- (d$groupsize - mean(d$groupsize))/sd(d$groupsize)
d$area.s <- (d$area - mean(d$area))/sd(d$area)
d$weight.s <- (d$weight - mean(d$weight))/sd(d$weight)
d$avgfood.s <- (d$avgfood - mean(d$avgfood))/sd(d$avgfood)

plot(d)
d

m5h1 <- map(
  alist(
    weight.s ~ dnorm(mu, sigma),
    mu <- a + b*area.s,
    a ~ dnorm(0, 100),
    b ~ dnorm(0, 100),
    sigma ~ dunif(0, 100)
    ), data=d)

precis(m5h1)

m5h1 <- map(
  alist(
    weight.s ~ dnorm(mu, sigma),
    mu <- a + b*groupsize.s,
    a ~ dnorm(0, 100),
    b ~ dnorm(0, 100),
    sigma ~ dunif(0, 100)
    ), data=d)

precis(m5h1)

groupsize.s <- seq(from=min(d$groupsize.s), to=max(d$groupsize.s), length.out=1000)
mu <- link(m5h1, data=data.frame(groupsize.s=groupsize.s), n=1e5)
mu.mean <- apply(mu, 2, mean)
mu.hpdi <- apply(mu, 2, HPDI, prob=0.95)
sim <- sim(m5h1, data=data.frame(groupsize.s=groupsize.s), n=1e5)
sim.hpdi <- apply(sim, 2, HPDI, prob=0.95)
plot(weight.s ~ groupsize.s, data=d)
abline(a=coef(m5h1)["a"], b=coef(m5h1)["b"])
shade(sim.hpdi, groupsize.s)

m5h2 <- map(
  alist(
    weight.s ~ dnorm(mu, sigma),
    mu <- a + b*groupsize.s + c*area.s,
    a ~ dnorm(0, 100),
    b ~ dnorm(0, 100),
    c ~ dnorm(0, 100),
    sigma ~ dunif(0, 100)
    ), data=d,
    start=list(
      a=0,
      b=0,
      c=0,
      sigma=1
      ))
      
d$predicted.weight.s <- apply(link(m5h2, data=d, n=1e4), 2, mean)
plot(predicted.weight.s ~ weight.s, data=d)
abline(0,1)
      
plot(groupsize.s ~ area.s, data=d)
      
precis(m5h2)

groupsize.s <- seq(from=min(d$groupsize.s), to=max(d$groupsize.s), length.out=1000)
area.s <- seq(from=min(d$area.s), to=max(d$area.s), length.out=1000)

weight.s <- sim(m5h2, data=data.frame(groupsize.s=groupsize.s, area.s=0), n=1e4)
weight.mean <- apply(weight.s, 2, mean)
weight.hpdi <- apply(weight.s, 2, HPDI, prob=0.89)
plot(weight.s ~ groupsize.s, data=d)
lines(groupsize.s, weight.mean)
shade(weight.hpdi, groupsize.s)

weight.s <- sim(m5h2, data=data.frame(area.s=area.s, groupsize.s=0), n=1e4)
weight.mean <- apply(weight.s, 2, mean)
weight.hpdi <- apply(weight.s, 2, HPDI, prob=0.89)
plot(weight.s ~ area.s, data=d)
lines(area.s, weight.mean)
shade(weight.hpdi, area.s)

m5h3a <- map(
  alist(
    weight.s ~ dnorm(mu, sigma),
    mu <- a + b*groupsize.s + d*avgfood.s,
    a ~ dnorm(0, 100),
    b ~ dnorm(0, 100),
    d ~ dnorm(0, 100),
    sigma ~ dunif(0, 100)
    ), data=d,
    start=list(
      a=0,
      b=0,
      d=0,
      sigma=1
      ))
      
precis(m5h3a)

groupsize.s <- seq(from=min(d$groupsize.s), to=max(d$groupsize.s), length.out=1000)
area.s <- seq(from=min(d$area.s), to=max(d$area.s), length.out=1000)
avgfood.s <- seq(from=min(d$avgfood.s), to=max(d$avgfood.s), length.out=1000)

weight.s <- sim(m5h3a, data=data.frame(avgfood.s=avgfood.s, groupsize.s=0), n=1e4)
weight.mean <- apply(weight.s, 2, mean)
weight.hpdi <- apply(weight.s, 2, HPDI, prob=0.89)
plot(weight.s ~ avgfood.s, data=d)
lines(avgfood.s, weight.mean)
shade(weight.hpdi, avgfood.s)

d$predicted.weight.s <- apply(link(m5h3a, data=d, n=1e4), 2, mean)
plot(predicted.weight.s ~ weight.s, data=d)
abline(0,1)

m5h3b <- map(
  alist(
    weight.s ~ dnorm(mu, sigma),
    mu <- a + b*groupsize.s + c*area.s + d*avgfood.s,
    a ~ dnorm(0, 100),
    b ~ dnorm(0, 100),
    c ~ dnorm(0, 100),
    d ~ dnorm(0, 100),
    sigma ~ dunif(0, 100)
    ), data=d,
    start=list(
      a=0,
      b=0,
      c=0,
      d=0,
      sigma=1
      ))
      
d$predicted.weight.s <- apply(link(m5h3b, data=d, n=1e4), 2, mean)
plot(predicted.weight.s ~ weight.s, data=d)
abline(0,1)
      
precis(m5h3b)
cov2cor(vcov(m5h3b))
plot(extract.samples(m5h3b, n=100))

library(rethinking)
data(Howell1)
d <- Howell1
d$height <- (d$height - mean(d$height))/sd(d$height)
d$age <- (d$age - mean(d$age))/sd(d$age)
d$age2 <- d$age ^ 2
d$age3 <- d$age ^ 3
d$age4 <- d$age ^ 4
d$age5 <- d$age ^ 5
d$age6 <- d$age ^ 6
set.seed(1000)
i <- sample(1:nrow(d), size=nrow(d)/2)
d1 <- d[i,]
d2 <- d[-i,]

plot(d)

m1 <- map(
  alist(
    height ~ dnorm(mu, exp(sigma)),
    mu <- p0 + p1*age,
    p0 ~ dnorm(0, 1),
    p1 ~ dnorm(0, 1),
    sigma ~ dnorm(0, 1)
    ), data=d1)

m2 <- map(
  alist(
    height ~ dnorm(mu, exp(sigma)),
    mu <- p0 + p1*age + p2*age2,
    p0 ~ dnorm(0, 1),
    p1 ~ dnorm(0, 1),
    p2 ~ dnorm(0, 1),
    sigma ~ dnorm(0, 1)
    ), data=d1)

m3 <- map(
  alist(
    height ~ dnorm(mu, exp(sigma)),
    mu <- p0 + p1*age + p2*age2 + p3*age3,
    p0 ~ dnorm(0, 1),
    p1 ~ dnorm(0, 1),
    p2 ~ dnorm(0, 1),
    p3 ~ dnorm(0, 1),
    sigma ~ dnorm(0, 1)
    ), data=d1)

m4 <- map(
  alist(
    height ~ dnorm(mu, exp(sigma)),
    mu <- p0 + p1*age + p2*age2 + p3*age3 + p4*age4,
    p0 ~ dnorm(0, 1),
    p1 ~ dnorm(0, 1),
    p2 ~ dnorm(0, 1),
    p3 ~ dnorm(0, 1),
    p4 ~ dnorm(0, 1),
    sigma ~ dnorm(0, 1)
    ), data=d1)  

m5 <- map(
  alist(
    height ~ dnorm(mu, exp(sigma)),
    mu <- p0 + p1*age + p2*age2 + p3*age3 + p4*age4 + p5*age5,
    p0 ~ dnorm(0, 1),
    p1 ~ dnorm(0, 1),
    p2 ~ dnorm(0, 1),
    p3 ~ dnorm(0, 1),
    p4 ~ dnorm(0, 1),
    p5 ~ dnorm(0, 1),
    sigma ~ dnorm(0, 1)
    ), data=d1)

m6 <- map(
  alist(
    height ~ dnorm(mu, exp(sigma)),
    mu <- p0 + p1*age + p2*age2 + p3*age3 + p4*age4 + p5*age5 + p6*age6,
    p0 ~ dnorm(0, 1),
    p1 ~ dnorm(0, 1),
    p2 ~ dnorm(0, 1),
    p3 ~ dnorm(0, 1),
    p4 ~ dnorm(0, 1),
    p5 ~ dnorm(0, 1),
    p6 ~ dnorm(0, 1),
    sigma ~ dnorm(0, 1)
    ), data=d1)  

plot(compare(m1, m2, m3, m4, m5, m6), SE=TRUE, dSE=TRUE)

age_seq <- seq(from=min(d$age), to=max(d$age), length.out=1000)
pred1 <- apply(sim(m1, data=data.frame(age=age_seq)), 2, mean)
pred2 <- apply(sim(m2, data=data.frame(age=age_seq, age2=age_seq^2)), 2, mean)
pred3 <- apply(sim(m3, data=data.frame(age=age_seq, age2=age_seq^2, age3=age_seq^3)), 2, mean)
pred4 <- apply(sim(m4, data=data.frame(age=age_seq, age2=age_seq^2, age3=age_seq^3, age4=age_seq^4)), 2, mean)
pred5 <- apply(sim(m5, data=data.frame(age=age_seq, age2=age_seq^2, age3=age_seq^3, age4=age_seq^4, age5=age_seq^5)), 2, mean)
pred6 <- apply(sim(m6, data=data.frame(age=age_seq, age2=age_seq^2, age3=age_seq^3, age4=age_seq^4, age5=age_seq^5, age6=age_seq^6)), 2, mean)
hpdi1 <- apply(sim(m1, data=data.frame(age=age_seq)), 2, HPDI, prob=0.89)
hpdi2 <- apply(sim(m2, data=data.frame(age=age_seq, age2=age_seq^2)), 2, HPDI, prob=0.89)
hpdi3 <- apply(sim(m3, data=data.frame(age=age_seq, age2=age_seq^2, age3=age_seq^3)), 2, HPDI, prob=0.89)
hpdi4 <- apply(sim(m4, data=data.frame(age=age_seq, age2=age_seq^2, age3=age_seq^3, age4=age_seq^4)), 2, HPDI, prob=0.89)
hpdi5 <- apply(sim(m5, data=data.frame(age=age_seq, age2=age_seq^2, age3=age_seq^3, age4=age_seq^4, age5=age_seq^5)), 2, HPDI, prob=0.89)
hpdi6 <- apply(sim(m6, data=data.frame(age=age_seq, age2=age_seq^2, age3=age_seq^3, age4=age_seq^4, age5=age_seq^5, age6=age_seq^6)), 2, HPDI, prob=0.89)

plot(height ~ age, d2)
# lines(age_seq, pred1)
# shade(hpdi1, age_seq)
# lines(age_seq, pred2)
# shade(hpdi2, age_seq)
# lines(age_seq, pred3)
# shade(hpdi3, age_seq)
# lines(age_seq, pred4)
# shade(hpdi4, age_seq)
# lines(age_seq, pred5)
# shade(hpdi5, age_seq)
lines(age_seq, pred6)
shade(hpdi6, age_seq)

mega = ensemble(m1,m2,m3,m4,m5,m6,data=data.frame(age=age_seq, age2=age_seq^2, age3=age_seq^3, age4=age_seq^4, age5=age_seq^5, age6=age_seq^6))

plot(height ~ age, d2)
lines(age_seq, apply(mega$link, 2, mean))
shade(apply(mega$sim, 2, HPDI, prob=0.89), age_seq)
lines(age_seq, pred4)
shade(hpdi4, age_seq)

sum( dnorm( d2$height, apply(sim(m1, data=data.frame(age=age_seq, age2=age_seq^2, age3=age_seq^3, age4=age_seq^4, age5=age_seq^5, age6=age_seq^6)), 2, mean) , exp(coef(m1)["sigma"]) , log=TRUE ) )
sum( dnorm( d2$height, apply(sim(m2, data=data.frame(age=age_seq, age2=age_seq^2, age3=age_seq^3, age4=age_seq^4, age5=age_seq^5, age6=age_seq^6)), 2, mean) , exp(coef(m2)["sigma"]) , log=TRUE ) )
sum( dnorm( d2$height, apply(sim(m3, data=data.frame(age=age_seq, age2=age_seq^2, age3=age_seq^3, age4=age_seq^4, age5=age_seq^5, age6=age_seq^6)), 2, mean) , exp(coef(m3)["sigma"]) , log=TRUE ) )
sum( dnorm( d2$height, apply(sim(m4, data=data.frame(age=age_seq, age2=age_seq^2, age3=age_seq^3, age4=age_seq^4, age5=age_seq^5, age6=age_seq^6)), 2, mean) , exp(coef(m4)["sigma"]) , log=TRUE ) )
sum( dnorm( d2$height, apply(sim(m5, data=data.frame(age=age_seq, age2=age_seq^2, age3=age_seq^3, age4=age_seq^4, age5=age_seq^5, age6=age_seq^6)), 2, mean) , exp(coef(m5)["sigma"]) , log=TRUE ) )
sum( dnorm( d2$height, apply(sim(m6, data=data.frame(age=age_seq, age2=age_seq^2, age3=age_seq^3, age4=age_seq^4, age5=age_seq^5, age6=age_seq^6)), 2, mean) , exp(coef(m6)["sigma"]) , log=TRUE ) )

m6r <- map(
  alist(
    height ~ dnorm(mu, exp(sigma)),
    mu <- p0 + p1*age + p2*age2 + p3*age3 + p4*age4 + p5*age5 + p6*age6,
    p0 ~ dnorm(0, 1),
    p1 ~ dnorm(0, 0.05),
    p2 ~ dnorm(0, 0.05),
    p3 ~ dnorm(0, 0.05),
    p4 ~ dnorm(0, 0.05),
    p5 ~ dnorm(0, 0.05),
    p6 ~ dnorm(0, 0.05),
    sigma ~ dnorm(0, 1)
    ), data=d1) 
    
    
precis(m6)
precis(m6r)

sum( dnorm( d2$height, apply(sim(m6r, data=data.frame(age=age_seq, age2=age_seq^2, age3=age_seq^3, age4=age_seq^4, age5=age_seq^5, age6=age_seq^6)), 2, mean) , exp(coef(m6r)["sigma"]) , log=TRUE ) )
    
library(rethinking)
data(rugged)
d <- rugged

colnames(d)
plot(rgdppc_2000 ~ rugged, d)

d$log_gdp <- log(d$rgdppc_2000)
dd <- d[complete.cases(d$log_gdp),]

d.A1 <- dd[dd$cont_africa==1,]
d.A0 <- dd[dd$cont_africa==0,]

plot(log_gdp ~ rugged, d.A1)
plot(log_gdp ~ rugged, d.A0)

m7.1 <- map(
  alist(
    log_gdp ~ dnorm(mu, sigma),
    mu <- a + bR*rugged,
    a ~ dnorm(8, 100),
    bR ~ dnorm(0, 1),
    sigma ~ dunif(0, 10)
    ), data=d.A1)
    
m7.0 <- map(
  alist(
    log_gdp ~ dnorm(mu, sigma),
    mu <- a + bR*rugged,
    a ~ dnorm(8, 100),
    bR ~ dnorm(0, 1),
    sigma ~ dunif(0, 10)
    ), data=d.A0)
    
precis(m7.1)
precis(m7.0)

data(tulips)
d <- tulips

colnames(d)

d$blooms.s <- (d$blooms - mean(d$blooms))/sd(d$blooms)
d$shade.s <- (d$shade - mean(d$shade))/sd(d$shade)
d$water.s <- (d$water - mean(d$water))/sd(d$water)

m1 <- map(
  alist(
    blooms.s ~ dnorm(mu, sigma),
    mu <- a + w*water.s + s*shade.s + sw*shade.s*water.s,
    a ~ dnorm(0, 100),
    w ~ dnorm(0, 100),
    s ~ dnorm(0, 100),
    sw ~ dnorm(0, 100),
    sigma ~ dunif(0, 10)
    ), data=d)
    
precis(m1)

d$bed.c <- coerce_index(d$bed)

m2 <- map(
  alist(
    blooms.s ~ dnorm(mu, sigma),
    mu <- w*water.s + s*shade.s + sw*shade.s*water.s + b[bed.c],
    w ~ dnorm(0, 100),
    s ~ dnorm(0, 100),
    sw ~ dnorm(0, 100),
    b[bed.c] ~ dnorm(0, 10),
    sigma ~ dunif(0, 10)
    ), data=d)
    
precis(m2, depth=2)

compare(m1, m2)

shade.seq <- c(min(d$shade.s), 0, max(d$shade.s))
for ( w in c(min(d$water.s), 0, max(d$water.s)) ) {
  dt <- d[d$water.s==w,]
  plot( blooms.s ~ shade.s , data=dt , col=c("red", "green", "blue")[bed.c] ,
    main=paste("water.c =",w) , xaxp=c(-1,1,2) ,
    xlab="shade (centered)" )
    mu <- link( m2 , data=data.frame(water.s=w,shade.s=shade.seq,bed.c=1) )
    mu.mean <- apply( mu , 2 , mean )
    mu.PI <- apply( mu , 2 , PI , prob=0.97 )
    lines( shade.seq , mu.mean, col="red" )
    lines( shade.seq , mu.PI[1,] , lty=2, , col="red" )
    lines( shade.seq , mu.PI[2,] , lty=2 ,, col="red")
    
    
    mu <- link( m2 , data=data.frame(water.s=w,shade.s=shade.seq,bed.c=2) )
    mu.mean <- apply( mu , 2 , mean )
    mu.PI <- apply( mu , 2 , PI , prob=0.97 )
    lines( shade.seq , mu.mean, col="green" )
    lines( shade.seq , mu.PI[1,] , lty=2, , col="green" )
    lines( shade.seq , mu.PI[2,] , lty=2 ,, col="green")
    
    
    
    mu <- link( m2 , data=data.frame(water.s=w,shade.s=shade.seq,bed.c=3) )
    mu.mean <- apply( mu , 2 , mean )
    mu.PI <- apply( mu , 2 , PI , prob=0.97 )
    lines( shade.seq , mu.mean, col="blue" )
    lines( shade.seq , mu.PI[1,] , lty=2, , col="blue" )
    lines( shade.seq , mu.PI[2,] , lty=2 ,, col="blue")
  }
  
  l <- extract.samples(m2)
  str(l)
  l$b[,1]

  dens(l$b[,3])
  sum(l$b[,1] < l$b[,2]) / length(l$b[,1])

data(rugged)
d <- rugged

d$log_gdp <- log(d$rgdppc_2000)
dd <- d[complete.cases(d$log_gdp),]
dd$log_gdp.s <- (dd$log_gdp - mean(dd$log_gdp)) / sd(dd$log_gdp)
dd$rugged.s <- (dd$rugged - mean(dd$rugged)) / sd(dd$rugged)
dd_s <- dd[-(dd$country == "Seychelles"),]

dd$log_gdp.s

m1 <- map(
  alist(
    log_gdp.s ~ dnorm(mu, sigma),
    mu <- i + a * cont_africa + r * rugged.s + ar * cont_africa * rugged.s,
    i ~ dnorm(0,10),
    a ~ dnorm(0,10),
    r ~ dnorm(0,10),
    ar ~ dnorm(0,10),
    sigma ~ dunif(0,10)
    ), data=dd)
    
precis(m1)

m2 <- map(
  alist(
    log_gdp.s ~ dnorm(mu, sigma),
    mu <- i + a * cont_africa + r * rugged.s + ar * cont_africa * rugged.s,
    i ~ dnorm(0,10),
    a ~ dnorm(0,10),
    r ~ dnorm(0,10),
    ar ~ dnorm(0,10),
    sigma ~ dunif(0,10)
    ), data=dd_s)
    
precis(m2)

rugged_seq = seq(from=min(dd$rugged.s), to=max(dd$rugged.s), length.out=1000)
par(mfrow=c(1,2))
for (m in c(m1, m2)) {
plot(log_gdp.s ~ rugged.s, col=c("red", "green")[1+cont_africa], data=dd)
for (cont in c(0,1)) {
  simmed = sim(m, data=data.frame(rugged.s=rugged_seq, cont_africa=cont))
  lines(rugged_seq, apply(simmed, 2, mean), col=c("red", "green")[1+cont])  
  shade(apply(simmed, 2, HPDI, prob=0.89), rugged_seq, col=adjustcolor(c("red", "green")[1+cont], alpha.f=0.2))
}
}

m1 <- map(
  alist(
    log_gdp.s ~ dnorm(mu, sigma),
    mu <- i + r * rugged.s,
    i ~ dnorm(0,10),
    r ~ dnorm(0,10),
    sigma ~ dunif(0,10)
    ), data=dd_s)

m2 <- map(
  alist(
    log_gdp.s ~ dnorm(mu, sigma),
    mu <- i + a * cont_africa + r * rugged.s,
    i ~ dnorm(0,10),
    a ~ dnorm(0,10),
    r ~ dnorm(0,10),
    sigma ~ dunif(0,10)
    ), data=dd_s)
        
m3 <- map(
  alist(
    log_gdp.s ~ dnorm(mu, sigma),
    mu <- i + a * cont_africa + r * rugged.s + ar * cont_africa * rugged.s,
    i ~ dnorm(0,10),
    a ~ dnorm(0,10),
    r ~ dnorm(0,10),
    ar ~ dnorm(0,10),
    sigma ~ dunif(0,10)
    ), data=dd_s)
    
WAIC(m3)
plot(compare(m1, m2, m3))

rugged_seq = seq(from=min(dd$rugged.s), to=max(dd$rugged.s), length.out=1000)
plot(log_gdp.s ~ rugged.s, col=c("red", "green")[1+cont_africa], data=dd)
for (cont in c(0,1)) {
  simmed <- ensemble(m1, m2, data=data.frame(rugged.s=rugged_seq, cont_africa=cont))
  lines(rugged_seq, apply(simmed$sim, 2, mean), col=c("red", "green")[1+cont])
  shade(apply(simmed$sim, 2, HPDI, prob=0.89), rugged_seq, col=adjustcolor(c("red", "green")[1+cont], alpha.f=0.2))
  
  simmed <- sim(m2, data=data.frame(rugged.s=rugged_seq, cont_africa=cont))
  lines(rugged_seq, apply(simmed, 2, mean), col=c("orange", "blue")[1+cont])
  shade(apply(simmed, 2, HPDI, prob=0.89), rugged_seq, col=adjustcolor(c("orange", "blue")[1+cont], alpha.f=0.2))
}

data(nettle)
d <- nettle

d$log.k.pop <- log(d$k.pop)
d$log.area <- log(d$area)
d$log.dens <- log(d$k.pop / d$area)
d$log.lang.per.cap <- log(d$num.lang / d$k.pop)

plot(d)

max(d$mean.growing.season)

m1  <- map(
  alist(
    log.lang.per.cap ~ dnorm(mu, sigma),
    mu <- i + m * mean.growing.season,
    i ~ dnorm(0, 10),
    m ~ dnorm(0, 10),
    sigma ~ dunif(0, 10)
    ), data=d)
    
precis(m1)

mgs_seq = seq(from=min(d$mean.growing.season), to=max(d$mean.growing.season), length.out=1000)
simmed <- sim(m1, data=data.frame(mean.growing.season=mgs_seq))
plot(log.lang.per.cap ~ mean.growing.season, data=d)
lines(mgs_seq, apply(simmed, 2, mean))
shade(apply(simmed, 2, HPDI, prob=0.89), mgs_seq)

m2  <- map(
  alist(
    log.lang.per.cap ~ dnorm(mu, sigma),
    mu <- i + s * sd.growing.season,
    i ~ dnorm(0, 10),
    s ~ dnorm(0, 10),
    sigma ~ dunif(0, 10)
    ), data=d)

mgs_seq = seq(from=min(d$sd.growing.season), to=max(d$sd.growing.season), length.out=1000)
simmed <- sim(m2, data=data.frame(sd.growing.season=mgs_seq))
plot(log.lang.per.cap ~ sd.growing.season, data=d)
lines(mgs_seq, apply(simmed, 2, mean))
shade(apply(simmed, 2, HPDI, prob=0.89), mgs_seq)

m3  <- map(
  alist(
    log.lang.per.cap ~ dnorm(mu, sigma),
    mu <- i + m * mean.growing.season + s * sd.growing.season + ms * mean.growing.season * sd.growing.season,
    i ~ dnorm(0, 10),
    m ~ dnorm(0, 10),
    s ~ dnorm(0, 10),
    ms ~ dnorm(0, 10),
    sigma ~ dunif(0, 10)
    ), data=d)
    
compare(m1, m2, m3)

mgs_seq = seq(from=min(d$sd.growing.season), to=max(d$sd.growing.season), length.out=1000)
xlim = c(min(d$sd.growing.season), max(d$sd.growing.season))
ylim = c(min(d$log.lang.per.cap), max(d$log.lang.per.cap))
mgs = 1:11
plot(log.lang.per.cap ~ sd.growing.season, data=d, col=rgb(1 - (mean.growing.season / 12), mean.growing.season / 12,  0))
for (mgs in seq(from=0, to=0)) {
  simmed <- sim(m3, data=data.frame(mean.growing.season=mgs, sd.growing.season=mgs_seq))
  lines(mgs_seq, apply(simmed, 2, mean), col=rgb(1 - (mgs / 12), mgs / 12,  0))
  shade(apply(simmed, 2, HPDI, prob=0.89), mgs_seq, col=rgb(1 - (mgs / 12), mgs / 12,  0, 0.1))
}

plot(log.lang.per.cap ~ sd.growing.season, data=d, col=rgb(1 - (mean.growing.season / 12), mean.growing.season / 12,  0))

library(rethinking)
data(rugged)
d <- rugged
d$log_gdp <- log(d$rgdppc_2000)
dd <- d[ complete.cases(d$rgdppc_2000) , ]

m <- map(
  alist(
    log_gdp ~ dnorm(mu, sigma),
    mu <- i + r*rugged + a*cont_africa + ar*rugged*cont_africa,
    i ~ dnorm(0, 100),
    r ~ dnorm(0, 10),
    a ~ dnorm(0, 10),
    ar ~ dnorm(0, 10),
    sigma ~ dunif(0, 10)
    ), data=dd)
    
precis(m)

dd.trim <- dd[, c("log_gdp", "rugged", "cont_africa")]

ms <- map2stan(
  alist(
    log_gdp ~ dnorm(mu, sigma),
    mu <- l + r*rugged + a*cont_africa + ar*rugged*cont_africa,
    l ~ dnorm(0, 100),
    r ~ dnorm(0, 10),
    a ~ dnorm(0, 10),
    ar ~ dnorm(0, 10),
    sigma ~ dcauchy(0, 2)
    ), data=dd.trim)
    
precis(ms)

ms <- map2stan(ms, chains=4, cores=4)

precis(ms)

post <- as.data.frame(extract.samples(ms))
pairs(post)
pairs(ms)

plot(ms)

stancode(ms)

y <- c(-1,1)
m <- map2stan(
  alist(
    y ~ dnorm(mu, sigma),
    mu <- alpha,
    alpha ~ dnorm(0, 100),
    sigma ~ dcauchy(0, 10)
    ),
    data=list(y=y), start=list(alpha=0,sigma=1),
    chains=2, iter=4000, warmup=1000)

precis(m)

plot(m)

pairs(m)

y <- rnorm( 100 , mean=0 , sd=1 )

m8.4 <- map2stan(
  alist(
    y ~ dnorm( mu , sigma ) ,
    mu<-a1+a2,
    sigma ~ dcauchy( 0 , 1 )
    ) ,
    data=list(y=y) , start=list(a1=0,a2=0,sigma=1) , 
    chains=2 , iter=4000 , warmup=1000 )
precis(m8.4)

plot(m8.4)

m8.4 <- map2stan(
  alist(
    y ~ dnorm( mu , sigma ) ,
    mu<-a1+a2,
    a1 ~ dnorm(0, 10),
    a2 ~ dnorm(0, 10),
    sigma ~ dcauchy( 0 , 1 )
    ) ,
    data=list(y=y) , start=list(a1=0,a2=0,sigma=1) , 
    chains=2 , iter=4000 , warmup=1000 )
    
plot(m8.4)

m1 <- map2stan(
  alist(
    log_gdp ~ dnorm(mu, sigma),
    mu <- l + r*rugged + a*cont_africa + ar*rugged*cont_africa,
    l ~ dnorm(0, 100),
    r ~ dnorm(0, 10),
    a ~ dnorm(0, 10),
    ar ~ dnorm(0, 10),
    sigma ~ dunif(0, 10)
    ), data=dd.trim)

m2 <- map2stan(
  alist(
    log_gdp ~ dnorm(mu, sigma),
    mu <- l + r*rugged + a*cont_africa + ar*rugged*cont_africa,
    l ~ dnorm(0, 100),
    r ~ dnorm(0, 10),
    a ~ dnorm(0, 10),
    ar ~ dnorm(0, 10),
    sigma ~ dexp(1)
    ), data=dd.trim)
    
pairs(m1)

pairs(m2)

ms <- map2stan(
  alist(
    log_gdp ~ dnorm(mu, sigma),
    mu <- l + r*rugged + a*cont_africa + ar*rugged*cont_africa,
    l ~ dnorm(0, 100),
    r ~ dnorm(0, 10),
    a ~ dnorm(0, 10),
    ar ~ dnorm(0, 10),
    sigma ~ dcauchy(0, 2)
    ), data=dd.trim)
pairs(ms)

ms2 <- map2stan(
  alist(
    log_gdp ~ dnorm(mu, sigma),
    mu <- l + r*rugged + a*cont_africa + ar*rugged*cont_africa,
    l ~ dnorm(0, 100),
    r ~ dnorm(0, 10),
    a ~ dnorm(0, 10),
    ar ~ dnorm(0, 10),
    sigma ~ dcauchy(0, 0.01)
    ), data=dd.trim)
pairs(ms2)

ms2 <- map2stan(
  alist(
    log_gdp ~ dnorm(mu, sigma),
    mu <- l + r*rugged + a*cont_africa + ar*rugged*cont_africa,
    l ~ dnorm(0, 100),
    r ~ dnorm(0, 10),
    a ~ dnorm(0, 10),
    ar ~ dnorm(0, 10),
    sigma ~ dexp(0.1)
    ), data=dd.trim)
pairs(ms2)

mp <- map2stan(
alist(
a ~ dnorm(0,1),
b ~ dcauchy(0,1)
),
data=list(y=1), 
start=list(a=0,b=0),
iter=1e4, warmup=100 , WAIC=FALSE )
plot(mp)

data(WaffleDivorce) 
d <- WaffleDivorce
d$MedianAgeMarriage.s <- (d$MedianAgeMarriage-mean(d$MedianAgeMarriage))/
d$Marriage.s <- (d$Marriage - mean(d$Marriage))/sd(d$Marriage)

m5.1 <- map2stan(
  alist(
    Divorce ~ dnorm( mu , sigma ) ,
    mu <- a + bA * MedianAgeMarriage.s ,
    a~dnorm(10,10),
    bA~dnorm(0,1),
    sigma ~ dunif( 0 , 10 )
    ),data=d)
    
m5.2 <- map2stan(
  alist(
    Divorce ~ dnorm( mu , sigma ) ,
    mu <- a + bR * Marriage.s ,
    a~dnorm(10,10),
    bR~dnorm(0,1),
    sigma ~ dunif( 0 , 10 )
    ),data=d)
    
m5.3 <- map2stan(
  alist(
    Divorce ~ dnorm( mu , sigma ) ,
    mu <- a + bR*Marriage.s + bA*MedianAgeMarriage.s ,
    a~dnorm(10,10),
    bR~dnorm(0,1),
    bA~dnorm(0,1),
    sigma ~ dunif( 0 , 10 )
    ), data=d)
    
pairs(d[,c("Divorce", "Marriage", "MedianAgeMarriage")])
pairs(m5.3)
    
compare(m5.1, m5.2, m5.3)

N <- 100 
                         # number of individuals
height <- rnorm(N,10,2) 
          # sim total height of each
leg_prop <- runif(N,0.4,0.5)      # leg as proportion of height
leg_left <- leg_prop*height +     # sim left leg as proportion + error
rnorm( N , 0 , 0.02 )
leg_right <- leg_prop*height +    # sim right leg as proportion + error
rnorm( N , 0 , 0.02 )
# combine into data frame
d <- data.frame(height,leg_left,leg_right)

m5.8s <- map2stan(
  alist(
    height ~ dnorm( mu , sigma ) ,
    mu <- a + bl*leg_left + br*leg_right ,
    a ~ dnorm( 10 , 100 ) ,
    bl~dnorm(2,10),
    br~dnorm(2,10),
    sigma ~ dcauchy( 0 , 1 )
    ) ,
    data=d, chains=4,
    start=list(a=10,bl=0,br=0,sigma=1) )
    
m5.8s2 <- map2stan(
  alist(
    height ~ dnorm( mu , sigma ) ,
    mu <- a + bl*leg_left + br*leg_right ,
    a ~ dnorm( 10 , 100 ) ,
    bl~dnorm(2,10),
    br ~ dnorm( 2 , 10 ) & T[0,] ,
    sigma ~ dcauchy( 0 , 1 )
    ) ,
    data=d, chains=4,
    start=list(a=10,bl=0,br=0,sigma=1) )
    
m5.8s3 <- map2stan(
  alist(
    height ~ dnorm( mu , sigma ) ,
    mu <- a + bl*leg_left + br*leg_right ,
    a ~ dnorm( 10 , 100 ) ,
    bl~dnorm(2,10) & T[0,],
    br ~ dnorm( 2 , 10 ) & T[0,] ,
    sigma ~ dcauchy( 0 , 1 )
    ) ,
    data=d, chains=4,
    start=list(a=10,bl=0,br=0,sigma=1) )
    
pairs(m5.8s)
pairs(m5.8s2)
pairs(m5.8s3)

compare(m5.8s, m5.8s2, m5.8s3)

library(rethinking)
data(Kline)
d <- Kline

d$log_pop <- log(d$population)
d$contact_high <- ifelse(d$contact=="high", 1, 0)

m10.10 <- map( 
  alist(
    total_tools ~ dpois( lambda ), 
    log(lambda) <- a + bp*log_pop +
    bc*contact_high + bpc*contact_high*log_pop,
    a ~ dnorm(0,100),
    c(bp,bc,bpc) ~ dnorm(0,1)
    ),
    data=d )
    
plot(precis(m10.10))

data(chimpanzees)
d <- chimpanzees

d2<-d
d2$recipient <- NULL

m1 <- map2stan(
  alist(
    pulled_left ~ dbinom( 1 , p ) ,
    logit(p) <- a[actor] + (bp + bpC*condition)*prosoc_left ,
    a[actor] ~ dnorm(0,10),
    bp ~ dnorm(0,10), 
    bpC ~ dnorm(0,10)
    ) ,
    data=d2 , chains=2 , iter=2500 , warmup=500 )
    
m2 <- map2stan(
  alist(
    pulled_left ~ dbinom( 1 , p ) , 
    logit(p) <- a + bp*prosoc_left , 
    a ~ dnorm(0,10) ,
    bp ~ dnorm(0,10)
    ) , 
    data=d2 , chains=2 , iter=2500 , warmup=500  )
    
m3 <- map2stan(
  alist(
    pulled_left ~ dbinom( 1 , p ) ,
    logit(p) <- a + (bp + bpC*condition)*prosoc_left ,
    a ~ dnorm(0,10) , 
    bp ~ dnorm(0,10) , 
    bpC ~ dnorm(0,10)
    ) , 
    data=d2 , chains=2 , iter=2500 , warmup=500  )
    
compare(m1,m2,m3)
    
pairs(m)

pairs(ms)

library(MASS);data(eagles) 
d <- eagles

d$P_cat <- coerce_index(d$P)
d$V_cat <- coerce_index(d$V)
d$A_cat <- coerce_index(d$A)
d$PA <- paste(d$P, d$A)
d$PA_cat <- coerce_index(d$PA)

m1 <- map2stan(
  alist(
    y ~ dbinom(n, p),
    logit(p) <- a + bp*P_cat + bv*V_cat + ba*A_cat,
    a ~ dnorm(0,10),
    bp ~ dnorm(0,5),
    bv ~ dnorm(0,5),
    ba ~ dnorm(0,5)
    ), data=d) 
    
pairs(m)

paste(d$)

s <- sim(m, data=d)
s.mean <- apply(s, 2, mean)
s.hpdi <- apply(s, 2, HPDI, prob=0.89)

postcheck(m)

m2 <- map2stan(
  alist(
    y ~ dbinom(n, p),
    logit(p) <- a + bp*P_cat + bv*V_cat + ba*A_cat + bpa[PA_cat],
    a ~ dnorm(0,10),
    bp ~ dnorm(0,5),
    bv ~ dnorm(0,5),
    ba ~ dnorm(0,5),
    bpa[PA_cat] ~ dnorm(0,5)
    ), data=d) 
    
compare(m1, m2)

postcheck(m2)

pairs(m2)

apply(extract.samples(m2), 2, mean)
d
coef(m2)

m3 <- map2stan(
  alist(
    y ~ dbinom(n, p),
    logit(p) <- a + bv*V_cat + bpa[PA_cat],
    a ~ dnorm(0,10),
    bv ~ dnorm(0,5),
    bpa[PA_cat] ~ dnorm(0,5)
    ), data=d) 

postcheck(m3)

pairs(m3)

m4 <- map2stan(
  alist(
    y ~ dbinom(n, p),
    logit(p) <- bv*V_cat + bpa[PA_cat],
    bv ~ dnorm(0,5),
    bpa[PA_cat] ~ dnorm(0,5)
    ), data=d) 
    
compare(m1,m4)

postcheck(m4)

m5 <- map2stan(
  alist(
    y ~ dbinom(n, p),
    logit(p) <- a + bp*P_cat + bv*V_cat + ba*A_cat + bpa*A_cat*P_cat,
    a ~ dnorm(0,10),
    bp ~ dnorm(0,5),
    bv ~ dnorm(0,5),
    ba ~ dnorm(0,5),
    bpa ~ dnorm(0,5)
    ), data=d) 
    
compare(m1,m5)

compare(m1,m2,m3,m4,m5)

postcheck(m5)

data(salamanders)
d <- salamanders
dim(d)
pairs(d)
plot(PCTCOVER ~ log(FORESTAGE), d)

m1 <- map2stan(
  alist(
    SALAMAN ~ dpois(l),
    log(l) <- a + p * PCTCOVER,
    a ~ dnorm(0, 100),
    p ~ dnorm(0, 100)
    ), data=d)
    
precis(m1)
plot(m1)
pairs(m1)
    
postcheck(m1)
coef(m1)

s <- sim(m1, data=d)
d$pred <- apply(s, 2, mean)

d$resid <- d$SALAMAN - d$pred

pairs(d)


cover_seq = seq(from=0, to=100, length.out=1000)
ss <- sim(m1, data=data.frame(PCTCOVER=cover_seq), n=1000)
plot(SALAMAN ~ PCTCOVER, d)
lines(cover_seq, apply(ss, 2, mean))
shade(apply(ss, 2, HPDI, prob=0.89), cover_seq)

pairs(m1)

pairs(d)

m2 <- map2stan(
  alist(
    SALAMAN ~ dpois(l),
    log(l) <- a + p * PCTCOVER + f * FORESTAGE,
    a ~ dnorm(0, 10),
    p ~ dnorm(0, 5),
    f ~ dnorm(0, 5)
    ), data=d, warmup=2000, iter=4000, chains=4)

precis(m2)
    
plot(m2)

d$log_FORESTAGE <- log(d$FORESTAGE + 1)
d$log_FORESTAGE_s <- (d$log_FORESTAGE - mean(d$log_FORESTAGE)) / sd(d$log_FORESTAGE)

m3 <- map2stan(
  alist(
    SALAMAN ~ dpois(l),
    log(l) <- a + p * PCTCOVER + f * log_FORESTAGE_s,
    a ~ dnorm(0, 10),
    p ~ dnorm(0, 5),
    f ~ dnorm(0, 5)
    ), data=d, warmup=2000, iter=4000, chains=4)
    
plot(m3)

d$pred3 <- apply(sim(m3, data=d), 2, mean)

pairs(d)

precis(m3)
    
compare(m1, m2)

m3 <- map2stan(
  alist(
    SALAMAN ~ dpois(l),
    log(l) <- a + p * PCTCOVER + f * log_FORESTAGE_s + pf * PCTCOVER * log_FORESTAGE,
    a ~ dnorm(0, 10),
    p ~ dnorm(0, 5),
    f ~ dnorm(0, 5),
    pf ~ dnorm(0, 5)
    ), data=d, warmup=2000, iter=4000, chains=4, start=list(a=1,p=1,f=1,pf=1))
    
plot(m3)
