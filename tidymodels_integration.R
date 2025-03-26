library(parsnip)
library(tscount)
library(rlang)

# ─────────────────────────────────────────────────────────────
# Step 1: Register the custom model + engine
# ─────────────────────────────────────────────────────────────

set_new_model("nb_ingarch")
set_model_mode(model = "nb_ingarch", mode = "regression")
set_model_engine("nb_ingarch", mode = "regression", eng = "tscount")
set_dependency("nb_ingarch", eng = "tscount", pkg = "tscount")
show_model_info("nb_ingarch")

# ─────────────────────────────────────────────────────────────
# Step 2: Register custom arguments
# ─────────────────────────────────────────────────────────────

for (arg in c("link", "distr", "ar_lags", "mean_lags")) {
  set_model_arg(
    model = "nb_ingarch",
    eng   = "tscount",
    parsnip = arg,
    original = arg,
    func = list(pkg = "rlang", fun = "eval_tidy"),
    has_submodel = FALSE
  )
}

# ─────────────────────────────────────────────────────────────
# Step 3: Model constructor
# ─────────────────────────────────────────────────────────────

nb_ingarch <- function(mode = "regression", 
                       link = "log", 
                       distr = "nbinom", 
                       ar_lags = NULL, 
                       mean_lags = NULL) {
  
  if (mode != "regression") {
    rlang::abort("Only 'regression' mode is supported for nb_ingarch.")
  }
  
  args <- list(
    link       = rlang::enquo(link),
    distr      = rlang::enquo(distr),
    ar_lags    = rlang::enquo(ar_lags),
    mean_lags  = rlang::enquo(mean_lags)
  )
  
  new_model_spec(
    "nb_ingarch",
    args     = args,
    eng_args = NULL,
    mode     = mode,
    method   = NULL,
    engine   = "tscount"
  )
}

# ─────────────────────────────────────────────────────────────
# Step 4: Register fit method
# ─────────────────────────────────────────────────────────────

nb_ingarch_pre <- function(object, x, y, ...) {
  # Evaluate captured arguments
  link_val      <- rlang::eval_tidy(object$args$link)
  distr_val     <- rlang::eval_tidy(object$args$distr)
  ar_lags_val   <- rlang::eval_tidy(object$args$ar_lags)
  mean_lags_val <- rlang::eval_tidy(object$args$mean_lags)
  
  # Convert outcome to numeric vector
  outcome_ts <- as.numeric(y)
  
  # Create predictor matrix from x (data.frame of predictors)
  if (ncol(x) > 0) {
    xreg <- model.matrix(~ . - 1, data = x)
  } else {
    xreg <- NULL
  }
  
  list(
    ts    = outcome_ts,
    model = list(past_obs = ar_lags_val, past_mean = mean_lags_val),
    xreg  = xreg,
    link  = link_val,
    distr = distr_val,
    info  = "score"
  )
}


set_fit(
  model = "nb_ingarch",
  eng   = "tscount",
  mode  = "regression",
  value = list(
    interface = "data.frame",    # switch from "formula" to "data.frame"
    protect   = c("x", "y"),
    func      = c(pkg = "tscount", fun = "tsglm"),
    defaults  = list(info = "score"),
    pre       = nb_ingarch_pre,   # Now pre will be called with (object, x, y, ...)
    post      = NULL
  )
)

# ─────────────────────────────────────────────────────────────
# Step 5: Data and fit test
# ─────────────────────────────────────────────────────────────

set.seed(123)
df_example <- data.frame(
  y  = rpois(100, lambda = 5),
  x1 = runif(100),
  x2 = rnorm(100)
)

spec <- nb_ingarch(
  link = "log",
  distr = "nbinom",
  ar_lags = 1,
  mean_lags = 1
) %>%
  set_engine("tscount")

spec

translate(spec, engine = "tscount")

show_model_info("nb_ingarch")

print(spec)

parsnip::get_model_env()$fit

fit_obj <- fit(
  spec,
  x = df_example[, c("x1", "x2")],
  y = df_example$y
)

pre_list <- nb_ingarch_pre(spec, y ~ x1 + x2, data = df_example)
print(pre_list)