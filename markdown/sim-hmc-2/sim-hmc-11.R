# load packages and source files
rm(list=ls())
options(warn=2)
library(fields)
library(evd)
library(spBayes)
library(fields)
library(SpatialTools)
# library(microbenchmark)  # comment out for beowulf
library(mvtnorm)
library(Rcpp)
library(numDeriv)
Sys.setenv("PKG_CXXFLAGS"="-fopenmp")
Sys.setenv("PKG_LIBS"="-fopenmp")

source("../../code/R/spatial_gev.R", chdir = TRUE)
source("../../code/R/spatial_logit.R", chdir = TRUE)
source("../../code/R/spatial_probit.R", chdir = TRUE)

# get the datasets
load("./simdata.RData")

# data setting and sets to include - written by bash script
# setMKLthreads(1)
sets <- c(81:90)
setting <- 4

# extract the relevant setting from simdata
y <- simdata[[setting]]$y
s <- simdata[[setting]]$s
x <- simdata[[setting]]$x

# extract info about simulation settings
ns        <- dim(y)[1]
nt        <- 1
nsets     <- dim(y)[2]
nsettings <- dim(y)[3]
nknots    <- nrow(knots)

# some precalculated values for quicker pairwise evaluation
dw2     <- rdist(s, knots)
d       <- rdist(s)
diag(d) <- 0

# testing vs training
ntrain <- floor(0.75 * ns)
ntest  <- ns - ntrain
obs    <- c(rep(T, ntrain), rep(F, ntest))
y.o    <- matrix(y[obs, ], ntrain, nsets)
X.o    <- matrix(x[obs], ntrain, 1)
s.o    <- s[obs, ]
y.p    <- matrix(y[!obs, ], ntest, nsets)
X.p    <- matrix(x[!obs, ], ntest, 1)
s.p    <- s[!obs, ]
dw2.o  <- rdist(s.o, knots)
d.o    <- as.matrix(rdist(s.o))
diag(d.o) <- 0

####################################################################
#### Start MCMC setup: Most of this is used for the spBayes package
####################################################################
iters <- 25000; burn <- 15000; update <- 1000; thin <- 1
# iters <- 100; burn <- 50; update <- 10; thin <- 1
n.report     <- 10
batch.length <- 100
n.batch      <- floor(iters / batch.length)
verbose      <- TRUE
tuning       <- list("phi" = 0.1, "sigma.sq" = 0.2, "beta" = 1, "w" = 5)
starting     <- list("phi" = 3/0.5, "sigma.sq" = 50, "beta" = 0, "w" = 0)
priors       <- list("beta.norm" = list(0, 100),
                     "phi.unif" = c(0.1, 1e4), "sigma.sq.ig" = c(1, 1))
cov.model <- "exponential"
timings   <- rep(NA, 3)
# with so many knots, adaptive is time prohibitive
amcmc     <- list("n.batch" = n.batch, "batch.length" = batch.length,
                  "accept.rate" = 0.35)

timings <- rep(NA, 3)

for (i in sets) {
  filename <- paste("sim-results/", setting, "-", i, ".RData", sep = "")
  tblname  <- paste("sim-tables/", setting, "-", i, ".txt", sep ="")
  y.i.o <- matrix(y.o[, i], ntrain, 1)
  y.i.p <- matrix(y.p[, i], ntest, 1)
  
  knots.o  <- rbind(knots, s.o[y.i.o == 1, ])
  cat("Starting: Set", i, "\n")
  
  cat("  Start gev \n")
  
  # spatial GEV
  cat("    Start mcmc fit \n")
  mcmc.seed <- i * 10
  set.seed(mcmc.seed)
  
  fit.gev <- spatial_GEV(y = y.i.o, s = s.o, x = X.o, knots = knots.o, 
                         beta.init = log(-log(1 - mean(y.o))),
                         beta.mn = 0, beta.sd = 10,
                         beta.eps = 0.1, beta.attempts = 50, 
                         xi.init = 0, xi.mn = 0, xi.sd = 0.5, xi.eps = 0.01, 
                         xi.attempts = 50, xi.fix = TRUE, 
                         a.init = 10, a.eps = 0.2, a.attempts = 50, 
                         a.cutoff = 0.1, b.init = 0.5, b.eps = 0.2, 
                         b.attempts = 50, alpha.init = 0.5, alpha.attempts = 50, 
                         a.alpha.joint = TRUE, alpha.eps = 0.0001,
                         rho.init = 0.1, logrho.mn = -2, logrho.sd = 1, 
                         rho.eps = 0.1, rho.attempts = 50, threads = 1, 
                         iters = iters, burn = burn, 
                         update = update, thin = 1, thresh = 0)
  
  cat("    Start mcmc predict \n")
  post.prob.gev <- pred.spgev(mcmcoutput = fit.gev, x.pred = X.p,
                              s.pred = s.p, knots = knots.o,
                              start = 1, end = iters - burn, update = update)
  timings[1] <- fit.gev$minutes
  
  bs.gev <- BrierScore(post.prob.gev, y.i.p)
  print(bs.gev * 100)
  
  # copy table to tables folder on beowulf
  bs <- rbind(bs.gev)
  write.table(bs, file = tblname)
  upload.cmd <- paste("scp ", tblname, " samorris@hpc.stat.ncsu.edu:~/rare-binary/markdown/sim-hmc-2/sim-tables", sep = "")
  system(upload.cmd)
  
  # spatial probit
  cat("  Start probit \n")
  
  cat("    Start mcmc fit \n")
  mcmc.seed <- mcmc.seed + 1
  set.seed(mcmc.seed)
  fit.probit <- probit(Y = y.i.o, X = X.o, s = s.o, knots = knots.o, 
                       iters = iters, burn = burn, update = update)
  
  cat("    Start mcmc predict \n")
  post.prob.pro <- pred.spprob(mcmcoutput = fit.probit, X.pred = X.p,
                               s.pred = s.p, knots = knots.o,
                               start = 1, end = iters - burn, update = update)
  timings[2] <- fit.probit$minutes
  
  bs.pro <- BrierScore(post.prob.pro, y.i.p)
  print(bs.pro * 100)
  
  # copy table to tables folder on beowulf
  bs <- rbind(bs.gev, bs.pro)
  write.table(bs, file = tblname)
  upload.cmd <- paste("scp ", tblname, " samorris@hpc.stat.ncsu.edu:~/rare-binary/markdown/sim-hmc-2/sim-tables", sep = "")
  system(upload.cmd)
  
  #   # spatial logit
  #   cat("  Start logit \n")
  #   cat("    Start mcmc fit \n")
  #   mcmc.seed <- mcmc.seed + 1
  #   set.seed(mcmc.seed)
  #   fit.logit <- spatial_logit(Y = y.i.o, s = s.o, eps = 0.1, 
  #                              a = 1, b = 1, knots = knots.o, 
  #                              iters = iters, burn = burn, update = update)
  #   
  #   cat("    Start mcmc predict \n")
  #   post.prob.log <- pred.splogit(mcmcoutput = fit.logit, s.pred = s.p, 
  #                                 knots = knots.o, start = 1, end = iters - burn, 
  #                                 update = update)
  #   timings[3] <- fit.logit$minutes
  #   
  #   bs.log <- BrierScore(post.prob.log, y.i.p)
  #   print(bs.log * 100)
  
  # spatial logit
  print("  start logit")
  print("    start mcmc fit")
  mcmc.seed <- mcmc.seed + 1
  set.seed(mcmc.seed)
  tic       <- proc.time()[3]
  fit.logit <- spGLM(formula = y.i.o ~ 1, family = "binomial",
                     coords = s.o, knots = knots.o, starting = starting,
                     tuning = tuning, priors = priors,
                     cov.model = cov.model, n.samples = iters,
                     verbose = verbose, n.report = n.report, amcmc = amcmc)
  
  print("    start mcmc predict")
  yp.sp.log <- spPredict(sp.obj = fit.logit, pred.coords = s.p,
                         pred.covars = X.p, start = burn + 1,
                         end = iters, thin = 1, verbose = TRUE,
                         n.report = 500)
  
  post.prob.log <- t(yp.sp.log$p.y.predictive.samples)
  toc        <- proc.time()[3]
  timings[3] <- toc - tic
  
  bs.log <- BrierScore(post.prob.log, y.i.p)
  print(bs.log * 100)
  
  # copy table to tables folder on beowulf
  bs <- rbind(bs.gev, bs.pro, bs.log)
  write.table(bs, file = tblname)
  upload.cmd <- paste("scp ", tblname, " samorris@hpc.stat.ncsu.edu:~/rare-binary/markdown/sim-hmc-2/sim-tables", sep = "")
  system(upload.cmd)
  
  cat("Finished: Set", i, "\n")
  save(fit.gev, post.prob.gev, bs.gev,
       fit.probit, post.prob.pro, bs.pro, 
       fit.logit, post.prob.log, bs.log,
       y.i.p, y.i.o, knots.o, s, timings,
       file = filename)
}
