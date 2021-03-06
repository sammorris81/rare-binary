# get the datasets
load(paste("./", species, ".RData", sep = ""))
upload.pre <- paste("samorris@hpc.stat.ncsu.edu:~/repos-git/rare-binary/code/",
                    "analysis/birds/cv-tables/", sep = "")
results.file <- paste("./cv-results/", species, "-", knot.percent, "-", cv,
                      ".RData", sep = "")
table.file   <- paste("./cv-tables/", species, "-", knot.percent, "-", cv,
                      ".txt", sep = "")

# get the correct y, x, and s
if (species == "cattle_egret") {
  y.o <- cattle_egret[cv.idx[[cv]]]
  y.p <- cattle_egret[-cv.idx[[cv]]]
  seed.base <- 1000
} else if (species == "common_nighthawk") {
  y.o <- common_nighthawk[cv.idx[[cv]]]
  y.p <- common_nighthawk[-cv.idx[[cv]]]
  seed.base <- 2000
} else if (species == "vesper_sparrow") {
  y.o <- vesper_sparrow[cv.idx[[cv]]]
  y.p <- vesper_sparrow[-cv.idx[[cv]]]
  seed.base <- 3000
} else if (species == "western_bluebird") {
  y.o <- western_bluebird[cv.idx[[cv]]]
  y.p <- western_bluebird[-cv.idx[[cv]]]
  seed.base <- 4000
} else if (species == "longbilled_curlew") {
  y.o <- longbilled_curlew[cv.idx[[cv]]]
  y.p <- longbilled_curlew[-cv.idx[[cv]]]
  seed.base <- 5000
} else if (species == "common_grounddove") {
  y.o <- common_grounddove[cv.idx[[cv]]]
  y.p <- common_grounddove[-cv.idx[[cv]]]
  seed.base <- 6000
} else if (species == "mountain_bluebird") {
  y.o <- mountain_bluebird[cv.idx[[cv]]]
  y.p <- mountain_bluebird[-cv.idx[[cv]]]
  seed.base <- 7000
} else if (species == "greater_white_goose") {
  y.o <- greater_white_goose[cv.idx[[cv]]]
  y.p <- greater_white_goose[-cv.idx[[cv]]]
  seed.base <- 8000
} else if (species == "bluewinged_teal") {
  y.o <- bluewinged_teal[cv.idx[[cv]]]
  y.p <- bluewinged_teal[-cv.idx[[cv]]]
  seed.base <- 9000
} else if (species == "whiteeyed_vireo") {
  y.o <- whiteeyed_vireo[cv.idx[[cv]]]
  y.p <- whiteeyed_vireo[-cv.idx[[cv]]]
  seed.base <- 10000
} else if (species == "sharpshinned_hawk") {
  y.o <- sharpshinned_hawk[cv.idx[[cv]]]
  y.p <- sharpshinned_hawk[-cv.idx[[cv]]]
  seed.base <- 11000
} else if (species == "lesser_goldfinch") {
  y.o <- lesser_goldfinch[cv.idx[[cv]]]
  y.p <- lesser_goldfinch[-cv.idx[[cv]]]
  seed.base <- 12000
} else if (species == "snowy_plover") {
  y.o <- snowy_plover[cv.idx[[cv]]]
  y.p <- snowy_plover[-cv.idx[[cv]]]
  seed.base <- 13000
} else if (species == "longeared_owl") {
  y.o <- longeared_owl[cv.idx[[cv]]]
  y.p <- longeared_owl[-cv.idx[[cv]]]
  seed.base <- 14000
} else if (species == "piping_plover") {
  y.o <- piping_plover[cv.idx[[cv]]]
  y.p <- piping_plover[-cv.idx[[cv]]]
  seed.base <- 15000
} else if (species == "hooded_oriole") {
  y.o <- hooded_oriole[cv.idx[[cv]]]
  y.p <- hooded_oriole[-cv.idx[[cv]]]
  seed.base <- 16000
} else {
  stop("incorrect species selected")
}

# 10, 15, 20, 1, 2, 5: This order because we originally ran only 10, 15, 20
if (knot.percent == 10) {
  knots <- knots.10[[cv]]
  seed.knot <- 100
} else if (knot.percent == 15) {
  knots <- knots.15[[cv]]
  seed.knot <- 200
} else if (knot.percent == 20) {
  knots <- knots.20[[cv]]
  seed.knot <- 300
} else if (knot.percent == 1) {
  knots <- knots.1[[cv]]
  seed.knot <- 400
} else if (knot.percent == 2) {
  knots <- knots.2[[cv]]
  seed.knot <- 500
} else if (knot.percent == 5) {
  knots <- knots.5[[cv]]
  seed.knot <- 600
} else {
  stop("only can use knots.percent = 10, 15, or 20")
}

# extract info about simulation settings
ns     <- length(y.o)
npred  <- length(y.p)
nt     <- 1
nknots <- nrow(knots)

# scale sites so in [0, 1] x [0, 1] (or close)
s.min <- apply(s, 2, min)
s.max <- apply(s, 2, max)
s.range <- c(diff(range(s[, 1])), diff(range(s[, 2])))
s.scale <- s
s.scale[, 1] <- (s[, 1] - s.min[1]) / max(s.range)
s.scale[, 2] <- (s[, 2] - s.min[2]) / max(s.range)
knots[, 1] <- (knots[, 1] - s.min[1]) / max(s.range)
knots[, 2] <- (knots[, 2] - s.min[2]) / max(s.range)

y.o <- matrix(y.o, ns, nt)
s.o <- s.scale[cv.idx[[cv]], ]
X.o <- matrix(1, nrow(s.o), 1)
y.p <- matrix(y.p, npred, nt)
s.p <- s.scale[-cv.idx[[cv]], ]
X.p <- matrix(1, nrow(s.p), 1)

####################################################################
#### Start MCMC setup: Most of this is used for the spBayes package
####################################################################
iters <- 30000; burn <- 25000; update <- 500; thin <- 1; iterplot <- FALSE
# iters <- 25000; burn <- 20000; update <- 500; thin <- 1; iterplot <- TRUE
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

# storage for some of the results
scores <- matrix(NA, 3, 2)  # place to store brier scores and auc
rownames(scores) <- c("gev", "probit", "logit")
colnames(scores) <- c("bs", "auc")

timings <- rep(NA, 3)

# start the simulation
set.seed(seed.base + seed.knot + cv * 10)

rho.init.pcl <- 0.05
dw2.o     <- rdist(s.o, knots)^2
d.o       <- as.matrix(rdist(s.o))
diag(d.o) <- 0
max.dist  <- 0.20

#### spatial GEV
cat("  Start gev \n")

# using pairwise estimates as starting points for rho, alpha, and beta. also
# using the the pairwise estimate of alpha as the mean of the prior
# distribution along with a standard deviation of 0.05 to allow for some
# variability, but hopefully also some better convergence w.r.t. alpha.
# we set max.dist to 0.15 in order to only consider pairs of sites that
# are relatively close to one another.
cat("    Start pairwise fit \n")
fit.pcl <- tryCatch(
  fit.rarebinaryCPP(beta.init = 0, xi.init = 0,
                    alpha.init = 0.5, rho.init = rho.init.pcl,
                    xi.fix = TRUE, alpha.fix = FALSE,
                    rho.fix = FALSE, beta.fix = TRUE,
                    y = y.o, dw2 = dw2.o, d = d.o,
                    cov = X.o, method = "BFGS",
                    max.dist = max.dist,
                    alpha.min = 0.1, alpha.max = 0.9,
                    threads = 2),
  error = function(e) {
    fit.rarebinaryCPP(beta.init = 0, xi.init = 0,
                      alpha.init = 0.5, rho.init = rho.init.pcl,
                      xi.fix = TRUE, alpha.fix = FALSE,
                      rho.fix = FALSE, beta.fix = TRUE,
                      y = y.o, dw2 = dw2.o, d = d.o,
                      cov = X.o, method = "Nelder-Mead",
                      max.dist = max.dist,
                      alpha.min = 0.1, alpha.max = 0.9,
                      threads = 2)
  }
)

cat("    Finish pairwise fit \n")

cat("    Start mcmc fit \n")
mcmc.seed <- 6262 + seed.base + seed.knot + cv * 10
set.seed(mcmc.seed)

alpha.mn <- fit.pcl$par[1]

# for numerical stability with the current set of starting values for the a
# terms. if alpha is too small, the algorithm has a very hard time getting
# started.
if (alpha.mn < 0.3) {
  alpha.init <- 0.3
} else {
  alpha.init <- alpha.mn
}

rho.init <- fit.pcl$par[2]
beta.init <- fit.pcl$beta

fit.gev <- spatial_GEV(y = y.o, s = s.o, x = X.o, knots = knots,
                       beta.init = log(-log(1 - mean(y.o))),
                       beta.mn = 0, beta.sd = 10,
                       beta.eps = 0.1, beta.attempts = 50,
                       xi.init = 0, xi.mn = 0, xi.sd = 0.5, xi.eps = 0.01,
                       xi.attempts = 50, xi.fix = TRUE,
                       a.init = 1, a.eps = 0.05, a.attempts = 50,
                       a.cutoff = 0.2, a.steps = 5,
                       b.init = 0.5, b.eps = 0.2,
                       b.attempts = 50, b.steps = 5,
                       alpha.init = alpha.init, alpha.attempts = 50,
                       alpha.mn = 0.5, alpha.sd = 0.1,
                       a.alpha.joint = FALSE, alpha.eps = 0.01,
                       rho.init = rho.init, logrho.mn = -2, logrho.sd = 1,
                       rho.eps = 0.1, rho.attempts = 50, threads = 1,
                       iters = iters, burn = burn,
                       update = update, iterplot = iterplot,
                       # update = 10, iterplot = TRUE,
                       thin = thin, thresh = 0)

cat("    Start mcmc predict \n")
post.prob.gev <- pred.spgev(mcmcoutput = fit.gev, x.pred = X.p,
                            s.pred = s.p, knots = knots,
                            start = 1, end = iters - burn, update = update)
timings[1] <- fit.gev$minutes

bs.gev             <- BrierScore(post.prob.gev, y.p, median)
post.prob.gev.med  <- apply(post.prob.gev, 2, median)
post.prob.gev.mean <- apply(post.prob.gev, 2, mean)
roc.gev            <- roc(y.p ~ post.prob.gev.med)
auc.gev            <- roc.gev$auc

print(bs.gev * 100)

# copy table to tables folder on beowulf
scores[1, ] <- c(bs.gev, auc.gev)
write.table(scores, file = table.file)
if (do.upload) {
  upload.cmd <- paste("scp ", table.file, " ", upload.pre, sep = "")
  system(upload.cmd)
}

###### spatial probit
cat("  Start probit \n")

cat("    Start mcmc fit \n")
mcmc.seed <- mcmc.seed + 1
set.seed(mcmc.seed)
fit.probit <- probit(Y = y.o, X = X.o, s = s.o, knots = knots,
                     iters = iters, burn = burn, update = update)

cat("    Start mcmc predict \n")
post.prob.pro <- pred.spprob(mcmcoutput = fit.probit, X.pred = X.p,
                             s.pred = s.p, knots = knots,
                             start = 1, end = iters - burn, update = update)
timings[2] <- fit.probit$minutes

bs.pro             <- BrierScore(post.prob.pro, y.p, median)
post.prob.pro.med  <- apply(post.prob.pro, 2, median)
post.prob.pro.mean <- apply(post.prob.pro, 2, mean)
roc.pro            <- roc(y.p ~ post.prob.pro.med)
auc.pro            <- roc.pro$auc

print(bs.pro * 100)

# copy table to tables folder on beowulf
scores[2, ] <- c(bs.pro, auc.pro)
write.table(scores, file = table.file)
if (do.upload) {
  upload.cmd <- paste("scp ", table.file, " ", upload.pre, sep = "")
  system(upload.cmd)
}


####### spatial logit
cat("  start logit \n")

cat("    Start mcmc fit \n")
mcmc.seed <- mcmc.seed + 1
set.seed(mcmc.seed)
tic       <- proc.time()[3]
fit.logit <- spGLM(formula = y.o ~ 1, family = "binomial",
                   coords = s.o, knots = knots, starting = starting,
                   tuning = tuning, priors = priors,
                   cov.model = cov.model, n.samples = iters,
                   verbose = verbose, n.report = n.report, amcmc = amcmc)
toc        <- proc.time()[3]

print("    start mcmc predict")
yp.sp.log <- spPredict(sp.obj = fit.logit, pred.coords = s.p,
                       pred.covars = X.p, start = burn + 1,
                       end = iters, thin = 1, verbose = TRUE,
                       n.report = 500)

post.prob.log <- t(yp.sp.log$p.y.predictive.samples)

timings[3] <- toc - tic

bs.log             <- BrierScore(post.prob.log, y.p, median)
post.prob.log.med  <- apply(post.prob.log, 2, median)
post.prob.log.mean <- apply(post.prob.log, 2, mean)
roc.log            <- roc(y.p ~ post.prob.log.med)
auc.log            <- roc.log$auc

print(bs.log * 100)

# copy table to tables folder on beowulf
scores[3, ] <- c(bs.log, auc.log)
write.table(scores, file = table.file)
if (do.upload) {
  upload.cmd <- paste("scp ", table.file, " ", upload.pre, sep = "")
  system(upload.cmd)
}

save(fit.gev, post.prob.gev.med, post.prob.gev.mean,
     bs.gev, roc.gev, auc.gev,
     fit.probit, post.prob.pro.med, post.prob.pro.mean,
     bs.pro, roc.pro, auc.pro,
     fit.logit, post.prob.log.med, post.prob.log.mean,
     bs.log, roc.log, auc.log,
     y.p, y.o, knots,
     s.o, s.p, timings,
     file = results.file)