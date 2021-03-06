// [[Rcpp::depends(RcppArmadillo)]]
#include <RcppArmadillo.h>
using namespace Rcpp;
using namespace arma;

#ifdef _OPENMP
#include <omp.h>
#endif

// [[Rcpp::export]]
arma::mat dPSCPP(arma::mat a, double alpha, arma::vec mid_points,
                      arma::vec bin_width, int threads = 1) {

  uword ns = a.n_rows; uword nt = a.n_cols;
  uword nbins = mid_points.n_elem;
  uword s; uword t; uword i;
  double integral; double llst; double psi; double logc; double logint;
  double ast;
  arma::mat ll(ns, nt);

  for (s = 0; s < ns; s++) {
    for (t = 0; t < nt; t++) {
      ast = a(s, t);
      llst = log(alpha) - log(1 - alpha) - log(ast) / (1 - alpha);
      integral = 0;
#pragma omp parallel for private(psi, logc, logint) reduction(+:integral) schedule(dynamic)
      for (i = 0; i < nbins; i++) {
        psi = PI * mid_points[i];
        logc = (log(sin(alpha * psi)) - log(sin(psi))) / (1 - alpha) +
          log(sin((1 - alpha) * psi)) - log(sin(alpha * psi));
        logint = logc - exp(logc) * pow(ast, (- alpha / (1 - alpha)));
        integral += exp(logint) * bin_width[i];
      }
      ll(s, t) = llst + log(integral);
    }
  }

  return ll;
}

// [[Rcpp::export]]
arma::mat logPriorACPP(arma::mat a, double alpha, arma::vec mid_points,
                 arma::vec bin_width, int threads = 1) {
  
  uword ns = a.n_rows; uword nt = a.n_cols;
  uword nbins = mid_points.n_elem;
  uword s; uword t; uword i;
  double integral; double llst; double psi; double logc; double logint;
  double ast;
  double alpha1m = 1 - alpha;
  arma::mat ll(ns, nt);
  
  for (s = 0; s < ns; s++) {
    for (t = 0; t < nt; t++) {
      ast = a(s, t);
      llst = log(ast) * alpha / alpha1m;  // includes jacobian
      integral = 0;
#pragma omp parallel for private(psi, logc, logint) reduction(+:integral) schedule(dynamic)
      for (i = 0; i < nbins; i++) {
        psi = PI * mid_points[i];
        logc = (log(sin(alpha * psi)) - log(sin(psi))) / (alpha1m) +
          log(sin((alpha1m) * psi)) - log(sin(alpha * psi));
        logint = logc - exp(logc) * pow(ast, (- alpha / (alpha1m)));
        integral += exp(logint) * bin_width[i];
      }
      ll(s, t) = llst + log(integral);
    }
  }
  
  return ll;
}
