# Processing and visualizing
library(fpp3) # tibble, dplyr, tidyr, lubridate, ggplot2, tsibble, tsibbledata, feasts, fable
library(arrow)
library(skimr)
library(shiny)
library(grid)
library(gridExtra)
library(lubridate)

# Modeling
library(tscount)
library(MASS)
library(bayesforecast)
# library(sandwich)
# library(lmtest)


## ===== Model-Running Functions =====

fill_gaps <- function(df_daily) {
  df_daily %>%
    mutate(date = as.Date(created_at)) %>% 
    # complete missing weeks from first to last date; fill outcome with 0 (use NA in fill if desired)
    complete(date = seq.Date(min(date), max(date), by = "day"),
             fill = list(vegan_outcome = 0))
}

# Split data into train and test sets
split_data <- function(df, train_frac) {
  
  # Sort by date and split by time
  unique_dates <- sort(unique(df$date))
  cut_date <- unique_dates[floor(length(unique_dates) * train_frac)]
  train <- df %>% filter(date <= cut_date)
  test  <- df %>% filter(date > cut_date)
  list(train = train, test = test)
}

# Preprocess predictors (scale selected variables; keep date unchanged)
standardize_data <- function(df) {
  df %>% mutate(
    #meat_window_avg       = as.numeric(scale(meat_window_avg)[,1]),
    #vegetarian_window_avg = as.numeric(scale(vegetarian_window_avg)[,1]),
    #vegan_window_avg      = as.numeric(scale(vegan_window_avg)[,1]),
    date = as.Date(created_at),
    day_of_week_cat = as.factor(day_of_week_cat#, 
                             #levels = c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
                             ),
    season = as.factor(season#, 
                    #levels = c("Spring", "Summer", "Autumn", "Winter")
                    ),
    month = lubridate::month(created_at),
    month_cat = as.factor(month_cat#, 
                       #levels = month.abb
                       ),
    year = lubridate::year(created_at),
    year_cat = as.factor(year_cat),
    year_num = as.numeric(year)
  )
}

# Fits and returns a NB model with given outcome and predictors
fit_nb_model <- function(df, outcome, predictors) {
  formula_str <- paste(outcome, "~", paste(predictors, collapse = " + "))
  MASS::glm.nb(as.formula(formula_str), data = df)
}

# Fits and returns a NB model with AR terms and Mean lag teams
fit_nbar_model <- function(df, outcome, predictors, ar_lags=c(), mean_lags=c()) {
  outcome_ts <- ts(df[[outcome]])
  xreg <- if (!is.null(predictors)) {model.matrix(~ . - 1, data = df[, predictors])} else {NULL}
  print(outcome_ts)
  print(xreg)
  
  tsglm(outcome_ts, 
        model = list(past_obs = ar_lags, past_mean = mean_lags), 
        xreg = xreg, 
        link = "log", 
        distr = "nbinom")
}

# Generate fitted values for training data
training_predictions <- function(train_df, model) {
  fitted_vals <- NULL
  if (inherits(model, "tsglm")) {fitted_vals <- fitted(model)}
  else {fitted_vals <- predict(model, newdata = train_df, type = "response")}
  if (length(fitted_vals) < nrow(train_df)) {fitted_vals <- c(rep(NA, nrow(train_df) - length(fitted_vals)), fitted_vals)} else {fitted_vals <- fitted_vals[1:nrow(train_df)]}
  fitted_vals
}

# Append to training dataframe and returns dataframe
append_train_pred <- function(train_df, model) {
  train_df %>% mutate(pred = training_predictions(train_df, model))
}

# Generates and returns rolling forecasts for testing data using nbar
rolling_forecast_nbar <- function(test_df, model, outcome, predictors) {
  n_test <- nrow(test_df)
  forecasts <- numeric(n_test)
  for(i in seq_len(n_test)) {
    # If predictors exist, create the design matrix for the first i test observations.
    if (!is.null(predictors) && length(predictors) > 0) {
      newxreg <- model.matrix(~ . - 1, data = test_df[1:i, predictors, drop = FALSE])
    } else {
      newxreg <- NULL
    }
    # Pass the first i actual outcomes as newobs and get forecasts for steps 1:i.
    pred_obj <- predict(model, 
                        n.ahead = i, 
                        newobs = test_df[[outcome]][1:i],
                        newxreg = newxreg)
    # Extract the forecast for the i-th observation.
    forecasts[i] <- pred_obj$pred[i]}
  forecasts
}

# Appends to testing dataframe and returns dataframe
append_test_pred <- function(test_df, model, outcome, predictors) {
  test_df %>% mutate(pred = rolling_forecast_nbar(test_df, model, outcome, predictors))
}

# aggregate daily data to weekly sums
agg_weekly <- function(df, outcome) {
  df %>% 
    mutate(week = floor_date(created_at, unit = "week")) %>% 
    group_by(week) %>% 
    summarise(obs  = sum(!!sym(outcome)),
              pred = ifelse(exists("pred"), sum(pred, na.rm = TRUE), NA_real_)) %>% 
    ungroup()
}

# diagnostic plots: ACF of train residuals, PACF of train residuals, weekly train and test obs vs pred
diag_plots <- function(loc, train_weekly, test_weekly, model, ar_label, mean_label) {
  
  # Append residuals
  train_resid_df <- train_weekly %>% 
    mutate(resid = obs - pred, 
           week = as.Date(week)
           ) %>% 
    as_tsibble(index = week)
  test_resid_df <- test_weekly %>% 
    mutate(resid = obs - pred, 
           week = as.Date(week)
           ) %>% 
    as_tsibble(index = week)
  
  # ACF plot using ggacf
  p_acf <- train_resid_df %>% ACF(resid, lag_max=30) %>% autoplot() + ggtitle("ACF of train residuals") + theme_minimal()
  
  # PACF plot using ggpacf
  p_pacf <- train_resid_df %>% PACF(resid, lag_max=30) %>% autoplot() + ggtitle("PACF of train residuals") + xlim(0,30) + theme_minimal()
  
  # Plot of train residuals
  p_train_res <- ggplot(train_resid_df, aes(sample = resid)) +
    geom_point(aes(x=pred, y=resid), alpha=0.3) +
    ggtitle("Plot of train residuals") +
    theme_minimal()
  
  # Plot of test residuals
  p_test_res <- ggplot(test_resid_df, aes(sample = resid)) +
    geom_point(aes(x=pred, y=resid), alpha=0.3) +
    ggtitle("Plot of test residuals") +
    theme_minimal()
  
  # Train weekly obs vs pred plot
  p_train <- ggplot(train_weekly, aes(x = week)) +
    geom_line(aes(y = obs, color = "obs")) +
    geom_line(aes(y = pred, color = "pred")) +
    ggtitle("Train weekly: obs vs pred") +
    labs(x = "Week", y = "Count") +
    scale_color_manual(values = c("obs" = "blue", "pred" = "red")) +
    #ylim(0, 90) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  # Test weekly obs vs pred plot
  p_test <- ggplot(test_weekly, aes(x = week)) +
    geom_line(aes(y = obs, color = "obs")) +
    geom_line(aes(y = pred, color = "pred")) +
    ggtitle("Test weekly: obs vs pred") +
    labs(x = "Week", y = "Count") +
    scale_color_manual(values = c("obs" = "blue", "pred" = "red")) +
    #ylim(0, 90) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  # Arrange the plots together with a header that shows location and AR lags.
  gridExtra::grid.arrange(
    gridExtra::arrangeGrob(p_acf, p_train_res, p_train, p_pacf, p_test_res, p_test, ncol = 3),
    top = grid::textGrob(paste("Diagnostic Plots: Restaurant", loc, "- AR lags:", ar_label, "- Mean lags:", mean_label), 
                         gp = grid::gpar(fontsize = 16, fontface = "bold"))
  )
}

process_models <- function(df, loc, outcome, predictors, model_type="nb", ar_lags=c(), mean_lags=c(), sample=FALSE, standardize=TRUE, train_frac=0.5) {
  
  # model_dir <- file.path("modeling_results")
  # model_file <- file.path(model_dir, paste0(loc, "_model.rds"))
  # # Check if the model file exists
  # if (file.exists(model_file)) {
  #   message("Loading existing model from: ", model_file)
  #   model <- readRDS(model_file)
  # } else {
  #   message("No existing model found. Training a new model...")
  
  # Filter to restaurant
  df <- df %>% filter(location_id == loc)
  
  # Fill gaps
  df <- fill_gaps(df)
  
  # Set default sample size to entire dataset
  if (sample) {df <- df %>% slice_sample(n = sample)}
  
  # Standardize if opted for
  if (standardize) {df <- df %>% standardize_data()}
  
  # Train test split
  splits <- split_data(df, train_frac)
  train_df <- splits$train
  test_df  <- splits$test
  
  # Fit the model on training data:
  model <- NULL
  if (model_type == "nb") {
    model <- fit_nb_model(train_df, outcome, predictors)
  }
  if (model_type == "nbar") {
    model <- fit_nbar_model(train_df, outcome, predictors, ar_lags, mean_lags)
  }
  
  # Append predictions to training and testing data
  train_df <- append_train_pred(train_df, model)
  test_df  <- append_test_pred(test_df, model, outcome, predictors)
  
  # Aggregate to weekly sums for train and test (use dates from original df)
  train_weekly <- agg_weekly(train_df, outcome)
  test_weekly  <- agg_weekly(test_df, outcome)
  
  glimpse(train_weekly)
  
  # Show diagnostic plots: ACF, train weekly obs vs pred, test weekly obs vs pred
  diag_grob <- diag_plots(loc, train_weekly, test_weekly, model, paste(ar_lags, collapse = ","), paste(mean_lags, collapse = ","))
  
  return(list(model = model, diag_plot = diag_grob))
}


walk_forward_cv_nbar <- function(df, outcome, predictors, initial_train_days, test_days = 30, ar_lags, mean_lags) {
  
  all_dates <- df$date
  
  # Define training fold end dates:
  # The first training fold ends after 'initial_train_days' have passed.
  # Then, only include folds where there are at least test_days available after.
  first_train_end <- min(all_dates) + days(initial_train_days - 1)
  last_possible_train_end <- max(all_dates) - days(test_days)
  fold_end_dates <- all_dates[all_dates >= first_train_end & all_dates <= last_possible_train_end]
  
  cv_results <- list()
  
  # To ensure non-overlapping test sets, we will move forward by test_days each time.
  # (That is, once you take a fold, the next fold starts at the end of its test set.)
  current_train_end <- first_train_end
  fold_counter <- 1
  
  while(current_train_end <= last_possible_train_end) {
    # Define the training set: all data up to and including current_train_end
    train_fold <- df %>% filter(date <= current_train_end)
    
    # Define the test set: the next test_days
    test_fold <- df %>% filter(date > current_train_end & date <= current_train_end + days(test_days))
    if(nrow(test_fold) < test_days) break  # exit if not enough test days
    
    # Fit the model using your custom function
    model <- fit_nbar_model(train_fold, outcome, predictors, ar_lags, mean_lags)
    
    # Get forecasts for the entire test set using your rolling forecast function
    fc <- rolling_forecast_nbar(test_fold, model, outcome, predictors)
    
    cv_results[[fold_counter]] <- tibble(
      fold = fold_counter,
      train_end = current_train_end,
      date = test_fold$date,
      horizon = 1:nrow(test_fold),
      actual = test_fold[[outcome]],
      forecast = fc
    )
    
    # Move forward: set the next training end date to be the last date in the current test set.
    current_train_end <- max(test_fold$date)
    fold_counter <- fold_counter + 1
  }
  
  bind_rows(cv_results)
}


df_all_daily <- read_parquet("data/3_palate_data_parquet_modeling/all_locations_daily.parquet") %>%
  standardize_data() %>%
  mutate(
    date = as.Date(created_at)
  )

process_models(df_all_daily,
               loc = "SRQS8F7JWA9MZ",
               outcome = "vegan_outcome",
               predictors = c("meat_window_avg",
                              "day_of_week_cat",
                              #"day_of_month_cat",
                              #"month_cat",
                              "season",
                              "year"),
               model_type = "nbar",
               ar_lags = c(1,7,14,21),
               mean_lags = c(),
               sample = FALSE,
               standardize = FALSE,
               train_frac = 0.8)

# df_loc <- df_all_daily %>% 
#   filter(location_id == "SRQS8F7JWA9MZ")
# outcome    <- "vegan_outcome"
# predictors <- c("meat_window_avg", 
#                 #"day_of_week_cat", 
#                 #"month_cat", 
#                 #"season", 
#                 "year"
#                 )
# initial_train_days <- 1000      # for example, use the first 100 days for initial training
# test_days  <- 30               # forecast 30 days ahead in each fold
# ar_lags    <- c(1,7,14,21)
# mean_lags  <- c()              # adjust if needed

# # Run walk-forward cross validation
# cv_results <- walk_forward_cv_nbar(df_loc, outcome, predictors, 
#                                    initial_train_days, test_days,
#                                    ar_lags, mean_lags)
# 
# cv_results
# 
# agg_weekly(cv_results %>% 
#              mutate(created_at = date, pred = forecast) %>% 
#              cbind(df_loc[1001:1570,'vegan_outcome']), 
#            'vegan_outcome')

# View results: each row is one forecast from one fold.
# print(cv_results)


# ## ===== Fit the Initial Model on the Training Window =====
# 
# # Use a subset of data for one location as an example:
# df_loc1 <- df_all_daily %>% 
#   filter(location_id == "SRQS8F7JWA9MZ") %>%
#   slice(100:5100)
# 
# # Split data into training and test sets
# splits <- split_data(df_loc1, 0.95)
# train_df <- splits$train
# test_df  <- splits$test
# 
# # Fit the NB model with AR terms (using your fit_nbar_model function)
# mod <- fit_nbar_model(
#   df         = train_df,
#   outcome    = outcome,
#   predictors = predictors,
#   ar_lags    = c(1,7,14,21),
#   mean_lags  = c(1)
# )
# 
# ## ===== Define Rolling Forecast Function =====
# 
# 
# 
# ## ===== Compute Rolling Forecasts =====
# 
# # Compute rolling forecasts for the test set
# rolling_preds <- rolling_forecast_nbar(mod, test_df, outcome, predictors)
# 
# # Add the rolling forecasts to the test data
# test_df <- test_df %>% mutate(rolling_pred = rolling_preds)
# 
# ## ===== Diagnostic Plots for Rolling Forecasts =====
# 
# # This function mimics your diag_plots() but works on the rolling forecast residuals.
# diag_plots_rolling <- function(test_df, outcome, loc, ar_label) {
#   # Compute residuals: actual outcome minus rolling forecast
#   test_df <- test_df %>% mutate(resid = !!sym(outcome) - rolling_pred)
#   
#   # ACF plot of the rolling forecast residuals using bayesforecast::ggacf
#   p_acf <- bayesforecast::ggacf(test_df$resid) + 
#     ggtitle("ACF of Rolling Forecast Residuals") + 
#     theme_minimal()
#   
#   # PACF plot using bayesforecast::ggpacf
#   p_pacf <- bayesforecast::ggpacf(test_df$resid) + 
#     ggtitle("PACF of Rolling Forecast Residuals") + 
#     theme_minimal()
#   
#   # Scatterplot of residuals versus rolling forecast (as a proxy for fitted values)
#   p_res <- ggplot(test_df, aes(x = rolling_pred, y = resid)) +
#     geom_point(alpha = 0.3) +
#     ggtitle("Residuals vs Rolling Forecast") +
#     theme_minimal()
#   
#   # Plot of actual outcomes and rolling forecasts over time
#   p_test <- ggplot(test_df, aes(x = created_at)) +
#     geom_line(aes(y = vegan_outcome, color = "Actual"), size = 1, alpha=.7) +
#     geom_line(aes(y = rolling_pred, color = "Rolling Forecast"), 
#               size = 1, alpha=.7) +
#     ggtitle("Test: Actual vs Rolling Forecast") +
#     labs(x = "Date", y = "Count") +
#     scale_color_manual(values = c("Actual" = "blue", "Rolling Forecast" = "red")) +
#     theme_minimal() +
#     theme(axis.text.x = element_text(angle = 45, hjust = 1))
#   
#   # Arrange the plots together, similar to your original diag_plots() layout.
#   gridExtra::grid.arrange(
#     gridExtra::arrangeGrob(p_acf, p_pacf, p_res, p_test, ncol = 2),
#     top = grid::textGrob(
#       paste("Rolling Forecast Diagnostics: Restaurant", loc, "- AR lags:", ar_label),
#       gp = grid::gpar(fontsize = 16, fontface = "bold")
#     )
#   )
# }
# 
# ## ===== Plot Diagnostics =====
# 
# # Display diagnostic plots for the rolling forecast residuals.
# diag_plots_rolling(test_df, outcome, loc = "SRQS8F7JWA9MZ", ar_label = "1")
# 
# 
#  