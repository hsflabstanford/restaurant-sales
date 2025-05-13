data {
  int<lower=1> K;           // Number of covariates
  int<lower=1> N_train;           // Number of time points
  matrix[N_train, K] X_train;           // Covariate matrix
  array[N_train] int y_train;           // Observed counts
  int<lower=1> N_test;      // Number of test time points
  matrix[N_test, K] X_test; // Covariate matrix for test data
  array[N_test] int y_test;
  
}

parameters {
  vector[K] beta;           // Regression coefficients for covariates
  real<lower=0,upper=1> alpha;  // Weight on previous count
  real<lower=0,upper=1> delta;  // Weight on previous intensity
  real<lower=0> phi;    // NB dispersion parameter
}

transformed parameters {
  vector[N_train] lambda;         // Time-varying intensity
  // Initial intensity: using stationary mean given the covariates at t=1
  lambda[1] = exp(dot_product(X_train[1], beta)) / (1 - alpha - delta);
  
  // Recursive definition of lambda
  for (t in 2:N_train) {
    lambda[t] = exp(dot_product(X_train[t], beta)) + alpha * y_train[t - 1] + delta * lambda[t - 1];
  }
}

model {
  // Enforce stationarity
  if (alpha + delta >= 1)
    target += negative_infinity();
  
  // Priors
  beta ~ normal(0, 5);
  alpha ~ beta(2, 2);
  delta ~ beta(2, 2);
  phi ~ gamma(2, 0.1);
  
  // Likelihood: Poisson likelihood using the computed intensities
  for (t in 1:N_train)
   // variance = mu + mu^2/phi_nb.
    y_train[t] ~ neg_binomial_2(lambda[t], phi);
}

generated quantities {
  // In-sample posterior predictive checks:
  array[N_train] int y_rep;   // Replicate for training data
  vector[N_train] log_lik;    // Pointwise log-likelihood for training data
  
  for (t in 1:N_train) {
    y_rep[t] = neg_binomial_2_rng(lambda[t], phi);       // Draw a replicate count
    log_lik[t] = neg_binomial_2_lpmf(y_train[t] | lambda[t], phi); // Compute log likelihood for y_train[t]
  }
  
  // Out-of-sample predictions for test data:
  array[N_test] int y_test_rep;  // Predicted counts for test data
  vector[N_test] lambda_test;    // Predicted intensities for test data
  
  // For test data, use the last training observations as initial conditions:
  lambda_test[1] = exp(dot_product(X_test[1], beta)) + alpha * y_train[N_train] + delta * lambda[N_train];
  y_test_rep[1] = neg_binomial_2_rng(lambda_test[1], phi);
  
  for (t in 2:N_test) {
    lambda_test[t] = exp(dot_product(X_test[t], beta)) + alpha * y_test[t - 1] + delta * lambda_test[t - 1];
    y_test_rep[t] = neg_binomial_2_rng(lambda_test[t], phi);
  }
}
