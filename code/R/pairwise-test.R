rm(list=ls())
options(warn=2)
library(fields)
library(evd)
library(spBayes)
library(fields)
library(SpatialTools)
# library(microbenchmark)
library(mvtnorm)
library(Rcpp)
library(numDeriv)
Sys.setenv("PKG_CXXFLAGS"="-fopenmp")
Sys.setenv("PKG_LIBS"="-fopenmp")
sourceCpp(file = "./pairwise.cpp")

source("auxfunctions.R")
source("updateModel.R")
source("mcmc.R")

set.seed(7483)  # site
ns    <- 1000
s     <- cbind(runif(ns), runif(ns))
knots <- expand.grid(seq(0.01, 0.99, length=12), seq(0.01, 0.99, length=12))
knots.h <- abs(knots[1, 1] - knots[2, 1])
x     <- matrix(1, ns, 1)

alpha.t <- 0.25
rho.t   <- 0.1
xi.t    <- 0.25

set.seed(3282)  # data
y <- matrix(data = NA, nrow = ns, ncol = 10)
for (i in 1:10) {
  data <- rRareBinarySpat(x, s = s, knots = knots, beta = 0, xi = xi.t,
                          alpha = alpha.t, rho = rho.t, prob.success = 0.05)

  y[, i] <- data$y
}
plot(knots, ylim = c(0, 1), xlim = c(0, 1), xlab = "", ylab = "")
points(s[which(y[, 1] != 1), ], pch = 21, col = "dodgerblue4", bg = "dodgerblue1")
points(s[which(y[, 1] == 1), ], pch = 21, col = "firebrick4", bg = "firebrick1")

thresh <- data$thresh
dw2    <- rdist(s, knots)
d      <- rdist(s)
diag(d) <- 0

beta.t <- -thresh

fit.2 <- fit.5 <- fit.6 <- fit.8 <- fit.9 <- fit.10 <- vector(mode = "list", length = 10)

for (i in 1:10) {
  y.i <- y[, i, drop = FALSE]
  print(paste("Starting: Set ", i, sep = ""))
  fit.2[[i]] <- fit.rarebinaryCPP(beta.init = 0, xi.init = xi.t,
                                  alpha.init = 0.5, rho.init = knots.h,
                                  xi.fix = TRUE, alpha.fix = FALSE,
                                  rho.fix = FALSE,
                                  y = y.i, dw2 = dw2, d = d,
                                  cov = x, max.dist = knots.h,
                                  alpha.min = 0.1, alpha.max = 0.9,
                                  threads = 6)
  print("    fit.2")

  fit.5[[i]] <- fit.rarebinaryCPP(beta.init = 0, xi.init = xi.t,
                                  alpha.init = 0.5, rho.init = knots.h,
                                  xi.fix = TRUE, alpha.fix = TRUE,
                                  rho.fix = FALSE,
                                  y = y.i, dw2 = dw2, d = d,
                                  cov = x, max.dist = knots.h,
                                  alpha.min = 0.1, alpha.max = 0.9,
                                  threads = 6)
  print("    fit.5")

  fit.6[[i]] <- fit.rarebinaryCPP(beta.init = 0, xi.init = xi.t,
                                  alpha.init = 0.5, rho.init = knots.h,
                                  xi.fix = TRUE, alpha.fix = FALSE,
                                  rho.fix = TRUE,
                                  y = y.i, dw2 = dw2, d = d,
                                  cov = x, max.dist = knots.h,
                                  alpha.min = 0.1, alpha.max = 0.9,
                                  threads = 6)
  print("    fit.6")

  fit.8[[i]] <- fit.rarebinaryCPP(beta.init = 0, xi.init = xi.t,
                                  alpha.init = 0.5, rho.init = knots.h,
                                  xi.fix = TRUE, alpha.fix = TRUE,
                                  rho.fix = TRUE,
                                  y = y.i, dw2 = dw2, d = d,
                                  cov = x, max.dist = knots.h,
                                  alpha.min = 0.1, alpha.max = 0.9,
                                  threads = 6)
  print("    fit.8")

  fit.9[[i]] <- fit.rarebinaryCPP(beta.init = 0, xi.init = xi.t,
                                   alpha.init = 0.5, rho.init = knots.h,
                                   xi.fix = TRUE, alpha.fix = FALSE,
                                   rho.fix = FALSE, beta.fix = TRUE,
                                   y = y.i, dw2 = dw2, d = d,
                                   cov = x, max.dist = knots.h,
                                   alpha.min = 0.1, alpha.max = 0.9,
                                   threads = 6)
  print("    fit.9")

  fit.10[[i]] <- fit.rarebinaryCPP(beta.init = 0, xi.init = xi.t,
                                   alpha.init = 0.5, rho.init = knots.h,
                                   xi.fix = TRUE, alpha.fix = FALSE,
                                   rho.fix = TRUE, beta.fix = TRUE,
                                   y = y.i, dw2 = dw2, d = d,
                                   cov = x, max.dist = knots.h,
                                   alpha.min = 0.1, alpha.max = 0.9,
                                   threads = 6)
  print("    fit.10")


  print(paste("Finished: Set ", i, sep = ""))
}

save(y, s, knots, fit.2, fit.5, fit.6, fit.8, fit.9, fit.10, file = "pairwisetest-maxd.RData")

rm(list=ls())
load(file = "pairwisetest-maxd.RData")

# str(fit.6)  # really want fit.6 to be reliable because fits alpha and beta

# unlist results
alpha.hat.2 <- alpha.se.2 <- beta.hat.2 <- beta.se.2 <- rep(NA, length(fit.2))
rho.hat.2 <- rho.se.2 <- rep(NA, length(fit.2))
for (i in 1:10) {
  # varcov <- solve(fit.2[[i]]$hessian)
  alpha.hat.2[i] <- fit.2[[i]]$par[1]
  # alpha.se.2[i]  <- sqrt(varcov[1, 1])
  rho.hat.2[i] <- fit.2[[i]]$par[2]
  # rho.se.2[i]  <- sqrt(varcov[2, 2])
  beta.hat.2[i] <- fit.2[[i]]$par[3]
  # beta.se.2[i]  <- sqrt(varcov[3, 3])
}
rbind(round(alpha.hat.2, 3), round(rho.hat.2, 3), round(beta.hat.2, 3))

alpha.hat.6 <- alpha.se.6 <- beta.hat.6 <- beta.se.6 <- rep(NA, length(fit.6))
for (i in 1:10) {
  # varcov <- solve(fit.6[[i]]$hessian)
  alpha.hat.6[i] <- fit.6[[i]]$par[1]
  # alpha.se.6[i]  <- sqrt(varcov[1, 1])
  beta.hat.6[i] <- fit.6[[i]]$par[2]
  # beta.se.6[i]  <- sqrt(varcov[2, 2])
}
rbind(round(alpha.hat.6, 3), round(beta.hat.6, 3))

beta.hat.8 <- beta.se.8 <- rep(NA, length(fit.8))
for (i in 1:10) {
  # varcov <- solve(fit.8[[i]]$hessian)
  beta.hat.8[i] <- fit.8[[i]]$par[1]
  # beta.se.8[i]  <- sqrt(varcov[1, 1])
}
beta.hat.8

alpha.hat.9 <- alpha.se.9 <- beta.hat.9 <- beta.se.9 <- rep(NA, length(fit.9))
rho.hat.9 <- rho.se.9 <- rep(NA, length(fit.9))
for (i in 1:10) {
  varcov <- solve(fit.9[[i]]$hessian)
  alpha.hat.9[i] <- fit.9[[i]]$par[1]
  alpha.se.9[i]  <- sqrt(varcov[1, 1])
  rho.hat.9[i] <- fit.9[[i]]$par[2]
  rho.se.9[i]  <- sqrt(varcov[2, 2])
  beta.hat.9[i] <- fit.9[[i]]$beta
  beta.se.9[i]  <- sqrt(fit.9[[i]]$beta.cov)
}
rbind(round(alpha.hat.9, 3), round(rho.hat.9, 3), round(beta.hat.9, 3))
rbind(round(alpha.se.9, 3), round(rho.se.9, 3), round(beta.se.9, 3))

alpha.hat.10 <- alpha.se.10 <- beta.hat.10 <- beta.se.10 <- rep(NA, length(fit.10))
for (i in 1:10) {
  varcov <- solve(fit.10[[i]]$hessian)
  alpha.hat.10[i] <- fit.10[[i]]$par[1]
  alpha.se.10[i]  <- sqrt(varcov[1, 1])
  beta.hat.10[i]  <- fit.10[[i]]$beta
  beta.se.10[i]   <- sqrt(fit.10[[i]]$beta.cov)
}
rbind(round(alpha.hat.10, 3), round(beta.hat.10, 3))
# [,1]   [,2]   [,3]   [,4]   [,5]   [,6]   [,7]   [,8]   [,9]  [,10]
# [1,]  0.436  0.539  0.257  0.495  0.334  0.201  0.290  0.201  0.568  0.201
# [2,] -4.405 -4.405 -4.405 -4.405 -4.405 -4.405 -4.405 -4.405 -4.405 -4.405
rbind(round(alpha.se.10, 3), round(beta.se.10, 3))

# W.t      <- stdW(makeW(dw2, rho.t))
# par.true <- c(alpha.t, rho.t, xi.t, beta.t)
# pairwise.rarebinaryR(par.true, y, dw2, x)
# pairwise.rarebinaryCPP(par.true, y, dw2, x, threads = 6)
# pairwise.rarebinary2CPP(c(xi.t, beta.t), alpha.t, rho.t, y, W, x, threads=1)
# microbenchmark(pairwise.rarebinary1(par.true, y, dw2, x),
#                pairwise.rarebinary2(par.true, y, dw2, x, threads = 6), times = 50)
#
# alpha.t <- 0.2
# rho.t   <- 0.1
# xi.t    <- 0.25
# ns      <- 500
# s       <- cbind(runif(ns), runif(ns))
# knots   <- expand.grid(seq(0.01, 0.99, length=12), seq(0.01, 0.99, length=12))
# x       <- matrix(1, ns, 1)
# set.seed(3282)  # data
# data <- rRareBinarySpat(x, s = s, knots = knots, beta = 0, xi = xi.t,
#                         alpha = alpha.t, rho = rho.t, prob.success = 0.1)
# dw2    <- rdist(s, knots)
# d      <- rdist(s)
# diag(d) <- 0
# y <- data$y
# plot(s[which(y == 1), ], pch=19, col=2, ylim=c(0, 1), xlim=c(0, 1))
# points(knots)
# rho <- knots[2, 1] - knots[1, 1]
# fit.rarebinaryCPP(c(0, 0.5, -4), rho = rho,  y = y, dw2 = dw2,
#                   cov = x, threads = 1)
#
# alphas <- seq(0.1, 0.9, by=0.05)
# rhos    <- (knots[2, 1] - knots[1, 1]) * seq(1, 2.5, 0.5)
# results1 <- matrix(9999999, length(rhos), length(alphas))
# for (j in seq_along(alphas)) {
#   for (i in seq_along(rhos)) {
#     results1[i, j] <- fit.rarebinaryCPP(c(0, -4), alpha = alphas[j],
#                                         rho = rho,  y = y, dw2 = dw2,
#                                         cov = x, threads = 1)$value
#     print(paste("alpha = ", alphas[j], ", rho = ", round(rhos[i], 3), sep=""))
#   }
# }
#
# xplot <- rep(alphas, each=length(rhos))
# yplot <- rep(rhos, length(alphas))
# color <- two.colors(n = 256, start = "dodgerblue4", end = "firebrick4",
#                     middle = "white")
# quilt.plot(x = xplot, y = yplot, z = results1,
#            nx = length(alphas), ny = length(rhos),
#            col = color,
#            main=bquote(paste("negative log likelihood grid search (", pi, "= 0.2)")),
#            xlab=bquote(alpha), ylab=bquote(rho))
# points(alpha.t, rho.t, col = "gray16", bg = "gray60",
#        pch = 21, cex = 1.4)
# min.idx <- which(results == min(results), arr.ind = TRUE)
# points(alphas[min.idx[2]], rhos[min.idx[1]], col = "gray16", bg = "gray60",
#        pch = 24, cex = 1.4)
#
# alpha.t <- 0.3
# rho.t   <- 0.1
# xi.t    <- 0.25
#
# set.seed(3282)  # data
# data <- rRareBinarySpat(x, s = s, knots = knots, beta = 0, xi = xi.t,
#                         alpha = alpha.t, rho = rho.t, prob.success = 0.1)
#
# alphas <- seq(0.1, 0.9, by=0.05)
# rhos   <- (knots[2, 1] - knots[1, 1]) * seq(1, 3, by = 0.5)
# results2 <- matrix(9999999, length(rhos), length(alphas))
# for (j in seq_along(alphas)) {
#   for (i in seq_along(rhos)) {
#     results2[i, j] <- fit.rarebinaryCPP(c(0, -4), alpha = alphas[j],
#                                         rho = rhos[i],  y = y, dw2 = dw2,
#                                         cov = x, threads = 1)$value
#     print(paste("alpha = ", alphas[j], ", rho = ", round(rhos[i], 3), sep=""))
#   }
# }
#
# xplot <- rep(alphas, each=length(rhos))
# yplot <- rep(rhos, length(alphas))
# color <- two.colors(n = 256, start = "dodgerblue4", end = "firebrick4",
#                     middle = "white")
# quilt.plot(x = xplot, y = yplot, z = results2,
#            nx = length(alphas), ny = length(rhos),
#            col = color,
#            main=bquote(paste("negative log likelihood grid search (", pi, "= 0.1)")),
#            xlab=bquote(alpha), ylab=bquote(rho))
# points(alpha.t, rho.t, col = "gray16", bg = "gray60",
#        pch = 21, cex = 1.4)
# min.idx <- which(results == min(results), arr.ind = TRUE)
# points(alphas[min.idx[2]], rhos[min.idx[1]], col = "gray16", bg = "gray60",
#        pch = 24, cex = 1.4)
#
# alpha.t <- 0.3
# rho.t   <- 0.1
# xi.t    <- 0.25
#
# set.seed(3282)  # data
# data <- rRareBinarySpat(x, s = s, knots = knots, beta = 0, xi = xi.t,
#                         alpha = alpha.t, rho = rho.t, prob.success = 0.1)
#
# alphas <- seq(0.1, 0.9, by=0.05)
# rhos   <- (knots[2, 1] - knots[1, 1]) * seq(1, 3, by = 0.5)
# results3 <- matrix(9999999, length(rhos), length(alphas))
# for (j in seq_along(alphas)) {
#   for (i in seq_along(rhos)) {
#     results3[i, j] <- fit.rarebinaryCPP(c(0, -4), alpha = alphas[j],
#                                         rho = rhos[i],  y = y, dw2 = dw2,
#                                         cov = x, threads = 1)$value
#     print(paste("alpha = ", alphas[j], ", rho = ", round(rhos[i], 3), sep=""))
#   }
# }
#
#
# fit.rarebinaryCPP(c(0, -4), alpha = 0.2, rho = 0.1, y = y, dw2 = dw2, cov = x,
#                   threads = 1)
#
#
# results <- optim(c(0.5, 0.1, 0, -4), pairwise.rarebinaryCPP, y = y, dw2 = dw2,
#                  cov = x, threads = 1,
#                  # lower = c(1e-6, 1e-6, -1, -Inf),
#                  # upper = c(1 - 1e-6, Inf, 3, Inf),
#                  hessian = TRUE)
#
#
# # to generate logistic data with around 1% rareness, need intercept = -log(99)
# # to generate logistic data with around 5% rareness, need intercept = -log(19)
# int.logit   <- -log(19)
# rho.logit   <- 1
# sigsq.logit <- 1
# nu.logit    <- 0.5
#
# data <- rLogitSpat(x = X, s = s, knots = knots, beta = int.logit,
#                    rho = rho.logit, sigma.sq = sigsq.logit,
#                    nu = nu.logit)
#
# # par = c(gamma, sigmasq, logrho, nu, beta)
# results <- optim(c(0.5, 1, log(0.2), 0.5, -4), pairwise.logisticR, y = y, d = d,
#                  cov = x, hessian = TRUE)
#
# results <- nlm(pairwise.rarebinaryCPP, c(0.5, 0.2, 0, -4), y = y, dw2 = dw2,
#                cov = x, threads = 4,
#                # lower = c(1e-6, 1e-6, -1, -Inf),
#                # upper = c(1 - 1e-6, Inf, 3, Inf),
#                hessian = TRUE)
#
# j <- cbind(results$gradient) %*% results$gradient
# h <- -results$hessian
# asym.var <- solve(h) %*% j %*% solve(h)
#
# # get gradient and hessian matrices - unnecessary calculations currently causing this to be very slow
# library(numDeriv)
# d <- matrix(0, 1, 4)
# h <- matrix(0, 4, 4)
#
# for (i in 1:(ns - 1)) {
#   for (j in i:(ns)) {
#     d <- d + jacobian(pairwise.rarebinaryCPP, x=results$par, y=y[c(i, j)],
#                       dw2=dw2, cov=x[c(i, j), , drop=F])
#     h <- h + hessian(pairwise.rarebinaryCPP, x=results$par, y=y[c(i, j)],
#                      dw2=dw2, cov=x[c(i, j), , drop=F])
#   }
#   print(paste("i = ", i))
# }
#
#
# microbenchmark(jacobian(pairwise.rarebinaryCPP, x=results$par, y=y[c(i, j)],
#                       dw2=dw2, cov=x[c(i, j), , drop=F]),
#                jacobian(pairwise.rarebinaryR, x=results$par, y=y[c(i, j)],
#                       dw2=dw2, cov=x[c(i, j), , drop=F])
#   )
#
# j <- (d) %*% d
# h <- -h
# asym.var <- solve(results$hessian) %*% j %*% solve(results$hessian)
# asym.var
# system.time(optim(c(0.5, 0.2, 0, -4), pairwise.rarebinary4, y=y, dw2=dw2, x=x, threads = 4))
#
# # timing
# # around 5 seconds when ns = 200
# # around 35 seconds when ns = 500
# # around 30 seconds when ns = 1000 and nthread = 4
#
#
#
#
#
# # originally testing speed of 4 different methods
# # r with function to get kernel combinations
# # r with apply to get kernel combinations
# # cpp without pointers used for kernel combinations
# # cpp with pointers used for kernel combinations
# pairwise.rarebinary1(par.true, y, dw2, x)
# pairwise.rarebinary2(par.true, y, dw2, x)
# pairwise.rarebinary3(par.true, y, dw2, x, threads = 4)
# pairwise.rarebinary4(par.true, y, dw2, x, threads = 4)
#
# microbenchmark(pairwise.rarebinary1(par.true, y, dw2, x),
#                pairwise.rarebinary2(par.true, y, dw2, x),
#                pairwise.rarebinary3(par.true, y, dw2, x),
#                pairwise.rarebinary4(par.true, y, dw2, x), times = 50)
#
# # when ns = 100
# # Unit: milliseconds
# #                                      expr       min        lq      mean    median        uq       max neval
# # pairwise.rarebinary1(par.true, y, dw2, x) 135.24563 136.01825 151.13502 136.77547 152.98440 268.17594    50
# # pairwise.rarebinary2(par.true, y, dw2, x) 372.12786 374.45486 400.07225 375.38344 389.75383 577.38213    50
# # pairwise.rarebinary3(par.true, y, dw2, x)  15.78985  15.90479  17.25929  16.04462  16.45333  24.27989    50
# # pairwise.rarebinary4(par.true, y, dw2, x)  10.69880  10.71617  11.54585  10.79183  11.06266  15.96124    50
#
# # when ns = 200
# # Unit: milliseconds
# #                                      expr       min        lq      mean    median        uq       max neval
# # pairwise.rarebinary1(par.true, y, dw2, x)  540.62006  548.09158  557.58586  550.75619  558.26123  597.28543    50
# # pairwise.rarebinary2(par.true, y, dw2, x) 1490.19606 1514.30555 1529.62580 1524.22436 1540.11635 1618.19104    50
# # pairwise.rarebinary3(par.true, y, dw2, x)   81.09228   81.92453   84.71521   82.88241   88.15506   92.18456    50
# # pairwise.rarebinary4(par.true, y, dw2, x)   42.20400   42.28760   42.59847   42.32965   42.62128   48.97245    50
#
# xplot <- c(100, 200)
# y1 <- c(151.135, 557.586)
# y2 <- c(400.072, 1529.626)
# y3 <- c(17.259, 84.715)
# y4 <- c(11.546, 42.598)
# ylim <- range(y1, y2, y3, y4)
# plot(xplot, y1, type = "l", ylim = ylim)
# lines(xplot, y2, lty=2)
# lines(xplot, y3, lty=3)
# lines(xplot, y4, lty=4)
