data {
  // Training
  int<lower=1> K;                 // Number of covariates
  int<lower=1> N_train;           // Number of training time points
  matrix[N_train, K] X_train;     // Covariate matrix for training data
  array[N_train] int y_train;     // Observed training counts
  
  // Testing
  int<lower=1> N_test;            // Number of test time points
  matrix[N_test, K] X_test;       // Covariate matrix for test data
  array[N_test] int y_test;       // (True test counts; used for rolling forecasts)   
  
  // Prior parameters
  vector<lower=0>[3] alpha_scale;
  vector<lower=0>[3] delta_scale;
}

parameters {
  vector[K] beta;                  // Regression coefficients (K includes intercept)
  real<lower=0> phi;               // Negative binomial dispersion parameter
  
  // Autoregressive coefficients for lagged transformed counts and past linear predictor
  // For the log-linear model, we constrain these to lie in (-1, 1)
  vector<lower=-1, upper=1>[3] alpha;  // Effects for log(y_{t-1}+1), log(y_{t-2}+1)
  vector<lower=-1, upper=1>[3] delta;  // Effects for lagged log-intensities ν_{t-1} and ν_{t-2}
}

transformed parameters {
  vector[N_train] nu;      // nu[t] = log(λ_t)
  vector[N_train] lambda;  // Conditional mean λ_t = exp(nu[t])
  
  // Initialize the process:
  // At t = 1, we have no past observations or past nu values
  nu[1] = dot_product(X_train[1], beta);
  lambda[1] = exp(nu[1]);
  
  // For t = 2, we only have one lag available
  if (N_train >= 2) {
    nu[2] = dot_product(X_train[2], beta)
            + alpha[1] * log(y_train[1] + 1)
            + delta[1] * nu[1];
    lambda[2] = exp(nu[2]);
  }
  
  // For t = 3, we only have one lag available
  if (N_train >= 3) {
    nu[3] = dot_product(X_train[2], beta)
            + alpha[1] * log(y_train[1] + 1)
            + alpha[2] * log(y_train[2] + 1)
            + delta[1] * nu[1]
            + delta[2] * nu[2];
    lambda[3] = exp(nu[3]);
  }
  
  // For t >= 4, use both lags
  for (t in 4:N_train) {
    nu[t] = dot_product(X_train[t], beta)
            + alpha[1] * log(y_train[t-1] + 1)
            + alpha[2] * log(y_train[t-2] + 1)
            + alpha[3] * log(y_train[t-3] + 1)
            + delta[1] * nu[t-1]
            + delta[2] * nu[t-2]
            + delta[3] * nu[t-3];
    lambda[t] = exp(nu[t]);
  }
}

model {
  // Priors:
  beta ~ normal(0, 5);
  phi ~ gamma(2, 0.1);
  
  // For the AR/mean coefficients we use a Laplace prior centered at 0 to induce selection
  for (i in 1:3) {
    alpha[i] ~ double_exponential(0, alpha_scale[i]);
    delta[i] ~ double_exponential(0, delta_scale[i]);
  }
  
  // Likelihood: the negative binomial likelihood (parametrized by its mean λ and dispersion φ)
  for (t in 1:N_train)
    y_train[t] ~ neg_binomial_2(lambda[t], phi);
}

generated quantities {
  // In-sample posterior predictive checks:
  array[N_train] int y_rep;    // Replicated training counts
  vector[N_train] log_lik;  // Pointwise log-likelihoods for training data
  for (t in 1:N_train) {
    y_rep[t] = neg_binomial_2_rng(lambda[t], phi);
    log_lik[t] = neg_binomial_2_lpmf(y_train[t] | lambda[t], phi);
  }
  
  // Out-of-sample predictions for test data using a rolling forecast:
  array[N_test] int y_test_rep;   // Predicted counts for test data
  vector[N_test] lambda_test; // Predicted intensities for test data
  vector[N_test] nu_test;     // Log-scale intensities for test data

  // For t = 1: Use last three training values to initialize the recursion
  nu_test[1] = dot_product(X_test[1], beta)
               + alpha[1] * log(y_train[N_train] + 1)
               + alpha[2] * log(y_train[N_train - 1] + 1)
               + alpha[3] * log(y_train[N_train - 2] + 1)
               + delta[1] * nu[N_train]
               + delta[2] * nu[N_train - 1]
               + delta[3] * nu[N_train - 2];
  lambda_test[1] = exp(nu_test[1]);
  y_test_rep[1] = neg_binomial_2_rng(lambda_test[1], phi);
  
  // For t = 2: Use the first test observation and training values
  if (N_test >= 2) {
    nu_test[2] = dot_product(X_test[2], beta)
                 + alpha[1] * log(y_test[1] + 1)
                 + alpha[2] * log(y_train[N_train] + 1)
                 + alpha[3] * log(y_train[N_train - 1] + 1)
                 + delta[1] * nu_test[1]
                 + delta[2] * nu[N_train]
                 + delta[3] * nu[N_train - 1];
    lambda_test[2] = exp(nu_test[2]);
    y_test_rep[2] = neg_binomial_2_rng(lambda_test[2], phi);
  }
  
  // For t = 3: Use two previous test observations and one training value
  if (N_test >= 3) {
    nu_test[3] = dot_product(X_test[3], beta)
                 + alpha[1] * log(y_test[2] + 1)
                 + alpha[2] * log(y_test[1] + 1)
                 + alpha[3] * log(y_train[N_train] + 1)
                 + delta[1] * nu_test[2]
                 + delta[2] * nu_test[1]
                 + delta[3] * nu[N_train];
    lambda_test[3] = exp(nu_test[3]);
    y_test_rep[3] = neg_binomial_2_rng(lambda_test[3], phi);
  }
  
  // For t >= 4: Use only test data from previous periods
  for (t in 4:N_test) {
    nu_test[t] = dot_product(X_test[t], beta)
                 + alpha[1] * log(y_test[t-1] + 1)
                 + alpha[2] * log(y_test[t-2] + 1)
                 + alpha[3] * log(y_test[t-3] + 1)
                 + delta[1] * nu_test[t-1]
                 + delta[2] * nu_test[t-2]
                 + delta[3] * nu_test[t-3];
    lambda_test[t] = exp(nu_test[t]);
    y_test_rep[t] = neg_binomial_2_rng(lambda_test[t], phi);
  }
}
