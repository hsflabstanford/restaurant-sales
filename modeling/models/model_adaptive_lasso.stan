data {
  // Input data
  int<lower=1> J;                 // # of covariates incl. intercept
  int<lower=1> p;                 // # of lags for past outcomes (y)
  int<lower=1> q;                 // # of lags for the conditional mean (λ)
                                  // aka the latent intensity 
  
  // Effective lags for past outcomes
  int<lower=1> p_effective;
  array[p_effective] int effective_lags_alpha;
  
  // Effective lags for latent intensity
  int<lower=1> q_effective;
  array[q_effective] int effective_lags_delta;
  
  // Training
  int<lower=1> N_train;           // # of time points
  matrix[N_train, J] X_train;     // Design matrix incl. intercept
  array[N_train] int y_train;     // Outcome
  
  // Testing
  int<lower=1> N_test;            // # of time points (test)
  matrix[N_test, J] X_test;       // Design matrix incl. intercept (test)
  array[N_test] int y_test;       // Outcome (test)
  
  // Hyperprior parameter inputs
  real<lower=0> beta_hyper;       // Input hyperprior scale for covariates
  real<lower=0> alpha_hyper;      // For past outcomes
  real<lower=0> delta_hyper;      // For latent intensity
}

parameters {
  // Exogenous coefficients and dispersion
  vector[J] beta;                  // Exogenous coefficients incl. intercept
  real<lower=0> phi;               // Negative binomial dispersion parameter
  
  // Autoregressive coefficients for lagged transformed counts and past linear predictor
  // For the log-linear model, we constrain these to lie in (-1, 1)
  // Only effective lags (e.g., lags 1–7 and any lags > 7 that are divisible by 7) are estimated.
  vector<lower=-1, upper=1>[p_effective] alpha;  // Effects for log(y_{t-1}+1), log(y_{t-2}+1)
  vector<lower=-1, upper=1>[q_effective] delta;  // Effects for lagged log-intensities ν_{t-1} and ν_{t-2}

  // Adaptive lasso: individual shrinkage scales
  vector<lower=0>[J] beta_scale;
  vector<lower=0>[p_effective] alpha_scale;
  vector<lower=0>[q_effective] delta_scale;
}

transformed parameters {

  vector[N_train] nu;             // nu[t] = log(λ_t)
  vector[N_train] lambda;         // λ_t = exp(nu[t]), which is the 
  
  for (t in 1:N_train) {

    nu[t] = dot_product(X_train[t], beta);
    
    // Outcome lags
    for (i in 1:p_effective)
      if (t > effective_lags_alpha[i])
        nu[t] += alpha[i] * log(y_train[t - effective_lags_alpha[i]] + 1);
    
    // Latent intensity lags
    for (j in 1:q_effective)
      if (t > effective_lags_delta[j])
        nu[t] += delta[j] * nu[t - effective_lags_delta[j]];
    
    lambda[t] = exp(nu[t]);
  }
}

model {
  // Priors
  phi ~ gamma(2, 0.1);

  // Hyperpriors for the shrinkage scales (i.e., adaptive)
  for (j in 1:J) {
    beta_scale[j] ~ exponential(beta_hyper);
    beta[j] ~ double_exponential(0, beta_scale[j]);
  }
  for (k in 1:p_effective) {
    alpha_scale[k] ~ exponential(alpha_hyper * (k % 7 + k %/% 7));
    alpha[k] ~ double_exponential(0, alpha_scale[k]);
  }
  for (l in 1:q_effective) {
    delta_scale[l] ~ exponential(delta_hyper * (l % 7 + l %/% 7));
    delta[l] ~ double_exponential(0, delta_scale[l]);
  }
  
  // Likelihood: parametrized by mean λ and dispersion φ
  for (t in 1:N_train)
    y_train[t] ~ neg_binomial_2(lambda[t], phi);
}

generated quantities {
  // In-sample posterior prediction
  array[N_train] int y_rep;         // Predicted outcome
  vector[N_train] log_lik;          // Pointwise log-likelihood
  for (t in 1:N_train) {
    y_rep[t] = neg_binomial_2_rng(lambda[t], phi);
    log_lik[t] = neg_binomial_2_lpmf(y_train[t] | lambda[t], phi);
  }

  // Out-of-sample posterior prediction using a rolling forecast:
  array[N_test] int y_test_rep;      // Predicted outcome (test)
  vector[N_test] lambda_test;        // Predicted intensities (test)
  vector[N_test] nu_test;            // Log-scale intensities (test)
  for (t in 1:N_test) {

    nu_test[t] = dot_product(X_test[t], beta);

    // Outcome lags (for single-step forecasts, we use y_test not y_test_rep!)
    for (i in 1:p_effective) {
        if (t - effective_lags_alpha[i] > 0)
          nu_test[t] += alpha[i] * log(y_test[t - effective_lags_alpha[i]] + 1);
        // If we aren't far enough into the test data, use the train data
        else
          nu_test[t] += alpha[i] * log(y_train[N_train - (effective_lags_alpha[i] - t)] + 1);
    }

    // Latent intensity lags
    for (j in 1:q_effective) {
        if (t - effective_lags_delta[j] > 0)
          nu_test[t] += delta[j] * nu_test[t - effective_lags_delta[j]];
        else
          nu_test[t] += delta[j] * nu[N_train - (effective_lags_delta[j] - t)];
    }

    lambda_test[t] = exp(nu_test[t]);
    y_test_rep[t] = neg_binomial_2_rng(lambda_test[t], phi);
  }
}
