for (set in these.sets) {
  for (species in species.list[these.species]) {
    print(paste("Start set ", set, sep = ""))

    # get the datasets
    load(paste("./", species, ".RData", sep = ""))
    upload.pre <- paste("samorris@hpc.stat.ncsu.edu:~/repos-git/rare-binary/",
                        "code/analysis/birds/cv-tables-samp/", sep = "")

    if (cluster) {
      samp.type <- "clu"
    } else {
      samp.type <- "srs"
    }
    table.file   <- paste("./cv-tables-samp/", species, "-", samp.type, "-", n,
                          "-", set, ".txt", sep = "")
    results.file <- paste("./cv-results/", species, "-", samp.type, "-", n, "-",
                          set, ".RData", sep = "")
    sample.file  <- paste("./cv-sample/", species, "-", samp.type, "-", n, "-",
                          set, ".txt", sep = "")

    ns <- c(100, 200)
    d  <- rdist(s)

    # get the correct y, x, and s
    y <- get(species)
    seed.base <- which(species.list == species) * 1000
    seed.n    <- which(ns == n) * 100

    set.seed(726753 + set)  # sample
    nobs <- 0
    while(nobs < 3) {
      # keep repeating the sampling until there are at least 3 observations
      these.train <- sort(sample(length(y), n))
      y.o <- y[these.train]
      these.cluster <- y.o == 1
      these.cluster.ids <- these.train[these.cluster]
      for (i in 1:length(these.cluster.ids)) {
        # for rook neighbors, d == 0.25
        these.train <- c(these.train, which(d[these.cluster.ids[i], ] == 0.25))
      }
      these.train <- sort(unique(these.train))
      y.o <- y[these.train]
      nobs <- sum(y.o)
    }

    if (!cluster) {
      nobs <- 0
      while (nobs < 3) {
        nsamp <- length(these.train)
        these.train <- sort(sample(length(y), nsamp))
        y.o <- y[these.train]
        nobs <- sum(y.o)
      }
    }

    # y.o <- y[these.train]
    y.p <- y[-these.train]

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
    # knots[, 1] <- (knots[, 1] - s.min[1]) / max(s.range)
    # knots[, 2] <- (knots[, 2] - s.min[2]) / max(s.range)

    y.o <- matrix(y.o, ns, nt)
    s.o <- s.scale[these.train, ]
    X.o <- matrix(1, nrow(s.o), 1)
    y.p <- matrix(y.p, npred, nt)
    s.p <- s.scale[-these.train, ]
    X.p <- matrix(1, nrow(s.p), 1)
    knots <- s.o

    this.save <- cbind(y.o, s.o)
    colnames(this.save) <- c("y", "s1", "s2")
    write.table(this.save, file = sample.file)

    ####################################################################
    #### Start MCMC setup: Most of this is used for the spBayes package
    ####################################################################
    iters <- 25000; burn <- 20000; update <- 500; thin <- 1; iterplot <- FALSE
    # iters <- 15000; burn <- 10000; update <- 500; thin <- 1; iterplot <- TRUE
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
    set.seed(seed.base + seed.n)

    rho.init.pcl <- 0.05
    dw2.o     <- rdist(s.o, knots)^2
    d.o       <- as.matrix(rdist(s.o))
    diag(d.o) <- 0
    max.dist  <- 1

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
    mcmc.seed <- seed.base + seed.n + set
    set.seed(mcmc.seed)

    alpha.mn <- fit.pcl$par[1]
    alpha.sd <- 0.05
    # when alpha is close to 0, the PS random effects have a much higher 
    # variance, and when it's close to 1, then the variance will decrease
    if (alpha.mn < 0.3) {
      a.eps <- 0.5
      b.eps <- 0.1
    } else if (alpha.mn < 0.85) {
      a.eps <- 0.1
      b.eps <- 0.1
    } else {
      a.eps <- 0.05
      b.eps <- 0.1
    }
    logrho.mn <- -3
    logrho.sd <- 0.7

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
                           a.init = 1, a.eps = a.eps, a.attempts = 500,
                           a.cutoff = 0.05, a.steps = 7,
                           b.init = 0.5, b.eps = b.eps,
                           b.attempts = 500, b.steps = 5,
                           alpha.init = alpha.init, alpha.attempts = 50,
                           alpha.mn = alpha.mn, alpha.sd = alpha.sd,
                           a.alpha.joint = FALSE, alpha.eps = 0.01,
                           rho.init = rho.init, logrho.mn = logrho.mn,
                           logrho.sd = logrho.sd,
                           rho.eps = 0.1, rho.attempts = 50, threads = 1,
                           iters = iters, burn = burn,
                           update = update, iterplot = iterplot,
                           # update = 10,
                           # iterplot = TRUE,
                           thin = thin, thresh = 0)

    cat("    Start mcmc predict \n")
    y.pred.gev <- pred.spgev(mcmcoutput = fit.gev, x.pred = X.p,
                             s.pred = s.p, knots = knots,
                             start = 1, end = iters - burn, update = update)
    timings[1] <- fit.gev$minutes

    post.prob.gev <- apply(y.pred.gev, 2, mean)
    bs.gev        <- mean((y.p - post.prob.gev)^2)
    roc.gev       <- roc(y.p ~ post.prob.gev)
    auc.gev       <- roc.gev$auc

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
    y.pred.pro <- pred.spprob(mcmcoutput = fit.probit, X.pred = X.p,
                              s.pred = s.p, knots = knots,
                              start = 1, end = iters - burn, update = update)
    timings[2] <- fit.probit$minutes

    post.prob.pro <- apply(y.pred.pro, 2, mean)
    bs.pro        <- mean((y.p - post.prob.pro)^2)
    roc.pro       <- roc(y.p ~ post.prob.pro)
    auc.pro       <- roc.pro$auc

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
    post.prob.log <- spPredict(sp.obj = fit.logit, pred.coords = s.p,
                               pred.covars = X.p, start = burn + 1,
                               end = iters, thin = 1, verbose = TRUE,
                               n.report = 500)$p.y.predictive.samples

    post.prob.log <- t(post.prob.log)
    y.pred.log <- matrix(
      rbinom(n = length(post.prob.log), size = 1, prob = post.prob.log),
      nrow = nrow(post.prob.log), ncol = ncol(post.prob.log))
    rm(post.prob.log)

    timings[3] <- toc - tic

    post.prob.log <- apply(y.pred.log, 2, mean)
    bs.log        <- mean((y.p - post.prob.log)^2)
    roc.log       <- roc(y.p ~ post.prob.log)
    auc.log       <- roc.log$auc

    print(bs.log * 100)

    # copy table to tables folder on beowulf
    scores[3, ] <- c(bs.log, auc.log)
    write.table(scores, file = table.file)
    if (do.upload) {
      upload.cmd <- paste("scp ", table.file, " ", upload.pre, sep = "")
      system(upload.cmd)
    }

    if ((set - 1) %% 5 == 0) {
      save(fit.gev, fit.probit, fit.logit,
           post.prob.gev, post.prob.pro, post.prob.log,
           y.o, y.p, s.o, s.p, file = results.file)
    } else {
      save(post.prob.gev, post.prob.pro, post.prob.log,
           y.o, y.p, s.o, s.p, file = results.file)
    }
  }
}