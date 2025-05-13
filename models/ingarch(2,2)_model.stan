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
  vector<lower=0>[2] alpha_scale;
  vector<lower=0>[2] delta_scale;
}

parameters {
  vector[K] beta;                  // Regression coefficients (K includes intercept)
  real<lower=0> phi;               // Negative binomial dispersion parameter
  
  // Autoregressive coefficients for lagged transformed counts and past linear predictor
  // For the log-linear model, we constrain these to lie in (-1, 1)
  vector<lower=-1, upper=1>[2] alpha;  // Effects for log(y_{t-1}+1), log(y_{t-2}+1)
  vector<lower=-1, upper=1>[2] delta;  // Effects for lagged log-intensities ν_{t-1} and ν_{t-2}
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
  
  // For t >= 3, use both lags
  for (t in 3:N_train) {
    nu[t] = dot_product(X_train[t], beta)
            + alpha[1] * log(y_train[t-1] + 1)
            + alpha[2] * log(y_train[t-2] + 1)
            + delta[1] * nu[t-1]
            + delta[2] * nu[t-2];
    lambda[t] = exp(nu[t]);
  }
}

model {
  // Priors:
  beta ~ normal(0, 5);
  phi ~ gamma(2, 0.1);
  
  // For the AR/mean coefficients we use a Laplace prior centered at 0 to induce selection
  alpha[1] ~ double_exponential(0, alpha_scale[1]);
  alpha[2] ~ double_exponential(0, alpha_scale[2]);
  delta[1] ~ double_exponential(0, delta_scale[1]);
  delta[2] ~ double_exponential(0, delta_scale[2]);
  
  // Likelihood: the negative binomial likelihood (parametrized by its mean λ and dispersion φ)
  for (t in 1:N_train)
    y_train[t] ~ neg_binomial_2(lambda[t], phi);
}
