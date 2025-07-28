library(tidymodels)
set_new_model("discrim_mixture")
set_model_mode(model = "discrim_mixture", mode = "classification")
set_model_engine(
  "discrim_mixture", 
  mode = "classification", 
  eng = "mda"
)
set_dependency("discrim_mixture", eng = "mda", pkg = "mda")
show_model_info("discrim_mixture")
set_model_arg(
  model = "discrim_mixture",
  eng = "mda",
  parsnip = "sub_classes",
  original = "subclasses",
  func = list(pkg = "foo", fun = "bar"),
  has_submodel = FALSE
)
show_model_info("discrim_mixture")
discrim_mixture <-
  function(mode = "classification",  sub_classes = NULL) {
    # Check for correct mode
    if (mode  != "classification") {
      rlang::abort("`mode` should be 'classification'.")
    }
    
    # Capture the arguments in quosures
    args <- list(sub_classes = rlang::enquo(sub_classes))
    
    # Save some empty slots for future parts of the specification
    new_model_spec(
      "discrim_mixture",
      args = args,
      eng_args = NULL,
      mode = mode,
      method = NULL,
      engine = NULL
    )
  }
set_fit(
  model = "discrim_mixture",
  eng = "mda",
  mode = "classification",
  value = list(
    interface = "formula",
    protect = c("formula", "data"),
    func = c(pkg = "mda", fun = "mda"),
    defaults = list()
  )
)

show_model_info("discrim_mixture")

set_encoding(
  model = "discrim_mixture",
  eng = "mda",
  mode = "classification",
  options = list(
    predictor_indicators = "traditional",
    compute_intercept = TRUE,
    remove_intercept = TRUE,
    allow_sparse_x = FALSE
  )
)

class_info <- 
  list(
    pre = NULL,
    post = NULL,
    func = c(fun = "predict"),
    args =
      # These lists should be of the form:
      # {predict.mda argument name} = {values provided from parsnip objects}
      list(
        # We don't want the first two arguments evaluated right now
        # since they don't exist yet. `type` is a simple object that
        # doesn't need to have its evaluation deferred. 
        object = rlang::expr(object$fit),
        newdata = rlang::expr(new_data),
        type = "class"
      )
  )

set_pred(
  model = "discrim_mixture",
  eng = "mda",
  mode = "classification",
  type = "class",
  value = class_info
)

prob_info <-
  pred_value_template(
    post = function(x, object) {
      tibble::as_tibble(x)
    },
    func = c(fun = "predict"),
    # Now everything else is put into the `args` slot
    object = rlang::expr(object$fit),
    newdata = rlang::expr(new_data),
    type = "posterior"
  )

set_pred(
  model = "discrim_mixture",
  eng = "mda",
  mode = "classification",
  type = "prob",
  value = prob_info
)

show_model_info("discrim_mixture")

discrim_mixture(sub_classes = 2) %>%
  translate(engine = "mda")

data("two_class_dat", package = "modeldata")
set.seed(4622)
example_split <- initial_split(two_class_dat, prop = 0.99)
example_train <- training(example_split)
example_test  <-  testing(example_split)

mda_spec <- discrim_mixture(sub_classes = 2) %>% 
  set_engine("mda")

mda_fit <- mda_spec %>%
  fit(Class ~ ., data = example_train)
mda_fit


library(tidymodels)
set_new_model("nb_ingarch")
set_model_mode(model = "nb_ingarch", mode = "regression")
set_model_engine(
  "nb_ingarch", 
  mode = "regression", 
  eng = "tscount"
)
set_dependency("nb_ingarch", eng = "tscount", pkg = "tscount")

show_model_info("nb_ingarch")

set_model_arg(
  model = "nb_ingarch",
  eng = "tscount",
  parsnip = "link",
  original = "link",
  func = c(fun = "identity"),  # Correct NULL usage
  has_submodel = FALSE
)

set_model_arg(
  model = "nb_ingarch",
  eng = "tscount",
  parsnip = "distr",
  original = "distr",
  func = c(fun = "identity"),
  has_submodel = FALSE
)

set_model_arg(
  model = "nb_ingarch",
  eng = "tscount",
  parsnip = "ar_lags",
  original = "ar_lags",
  func = c(fun = "identity"),
  has_submodel = FALSE
)

set_model_arg(
  model = "nb_ingarch",
  eng = "tscount",
  parsnip = "mean_lags",
  original = "mean_lags",
  func = c(fun = "identity"),
  has_submodel = FALSE
)

show_model_info("nb_ingarch")

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
    engine   = NULL
  )
}

# Update the pre-processing function to remove 'info'
nb_ingarch_pre <- function(object, formula, data, ...) {
  mf <- model.frame(formula, data)
  outcome_ts <- mf[[1]]
  
  if (ncol(mf) > 1) {
    x <- mf[, -1, drop = FALSE]
    xreg <- model.matrix(~ . - 1, data = x)
  } else {
    xreg <- NULL
  }
  
  list(
    ts    = as.numeric(outcome_ts),
    model = list(
      past_obs  = rlang::eval_tidy(object$args$ar_lags),
      past_mean = rlang::eval_tidy(object$args$mean_lags)
    ),
    xreg  = xreg,
    link  = rlang::eval_tidy(object$args$link),
    distr = rlang::eval_tidy(object$args$distr)
    # Removed 'info = "score"'
  )
}

set_fit(
  model = "nb_ingarch",
  eng   = "tscount",
  mode  = "regression",
  value = list(
    interface = "formula",            # Using a formula interface
    protect   = c("formula", "data"),
    func      = c(pkg = "tscount", fun = "tsglm"),
    defaults  = list(),
    pre       = nb_ingarch_pre,         # Our pre-processor for formula input
    post      = NULL
  )
)

show_model_info("nb_ingarch")

translate(nb_ingarch(link = "log", distr = "nbinom", ar_lags = 1, mean_lags = 1) %>% set_engine("tscount"), engine = "tscount")

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
) %>% set_engine("tscount")

# Inspect the translation, model info, and spec structure if desired
print(translate(spec, engine = "tscount"))
show_model_info("nb_ingarch")
str(spec)

# Fit the model using the formula interface
fit_obj <- fit(spec, y ~ x1 + x2, data = df_example)
print(fit_obj)
