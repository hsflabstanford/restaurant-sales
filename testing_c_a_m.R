# Processing and visualizing
library(fpp3) # tibble, dplyr, tidyr, lubridate, ggplot2, tsibble, tsibbledata, feasts, fable
library(arrow)
library(skimr)
library(shiny)
library(grid)
library(gridExtra)

# Modeling
library(tscount)
library(sandwich)
library(lmtest)
library(MASS)
library(bayesforecast)


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
    meat_window_avg       = as.numeric(scale(meat_window_avg)[,1]),
    vegetarian_window_avg = as.numeric(scale(vegetarian_window_avg)[,1]),
    vegan_window_avg      = as.numeric(scale(vegan_window_avg)[,1]),
    day_of_week_cat       = as.factor(day_of_week_cat),
    day_of_month_cat      = as.factor(day_of_month_cat),
    month_cat             = as.factor(month_cat),
    season                = as.factor(season),
    year_cat              = as.factor(year_cat)
  )
}

# fit NB model with given outcome and predictors
fit_nb_model <- function(df, outcome, predictors) {
  formula_str <- paste(outcome, "~", paste(predictors, collapse = " + "))
  MASS::glm.nb(as.formula(formula_str), data = df)
}

# Fit NB model with AR terms
fit_nbar_model <- function(df, outcome, predictors, ar_lags) {
  outcome_ts <- ts(df[[outcome]])
  xreg <- if (!is.null(predictors)) {
    model.matrix(~ . - 1, data = df[, predictors])
  } else {
    NULL
  }
  tsglm(outcome_ts, 
        model = list(past_obs = ar_lags, past_mean = c()), 
        xreg = xreg, 
        link = "log", 
        distr = "nbinom")
}

# aggregate daily data to weekly sums
agg_weekly <- function(df, outcome, model = NULL) {
  if (!is.null(model)) {
    if (inherits(model, "tsglm")) {
      # Get the fitted values from the tsglm model
      fitted_vals <- fitted(model)
      if (length(fitted_vals) < nrow(df)) {
        # pad beginning with NAs so that length equals nrow(df)
        full_fitted <- c(rep(NA, nrow(df) - length(fitted_vals)), fitted_vals)
      } else {
        # if more fitted values than rows, use only first nrow(df)
        full_fitted <- fitted_vals[1:nrow(df)]
      }
      df <- df %>% mutate(pred = full_fitted)
    } else {
      # For other models (e.g., MASS::glm.nb)
      df <- df %>% mutate(pred = predict(model, newdata = df, type = "response"))
    }
  }
  df %>% 
    mutate(week = floor_date(created_at, unit = "week")) %>% 
    group_by(week) %>% 
    summarise(obs  = sum(!!sym(outcome)),
              pred = ifelse(exists("pred"), sum(pred, na.rm = TRUE), NA_real_)) %>% 
    ungroup()
}

# diagnostic plots: ACF of train residuals, PACF of train residuals, weekly train and test obs vs pred
diag_plots <- function(model, train_weekly, test_weekly, loc, ar_label) {
  
  # residuals from train NB model
  train_resid <- residuals(model, type = "pearson")
  train_fitted <- fitted(model)
  
  # ACF plot using ggacf
  p_acf <- bayesforecast::ggacf(train_resid) + ggtitle("ACF of train residuals") + theme_minimal()
  
  # PACF plot using ggpacf
  p_pacf <- bayesforecast::ggpacf(train_resid) + ggtitle("PACF of train residuals") + theme_minimal()
  
  # Plot of residuals
  resid_df <- tibble(resid = train_resid, fitted=train_fitted)
  p_res <- ggplot(resid_df, aes(sample = resid)) +
    geom_point(aes(x=fitted, y=resid), alpha=0.3) +
    ggtitle("Plot of train residuals") +
    theme_minimal()
  
  # Train weekly obs vs pred plot
  p_train <- ggplot(train_weekly, aes(x = week)) +
    geom_line(aes(y = obs, color = "obs")) +
    geom_line(aes(y = pred, color = "pred")) +
    ggtitle("Train weekly: obs vs pred") +
    labs(x = "Week", y = "Count") +
    scale_color_manual(values = c("obs" = "blue", "pred" = "red")) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  # Test weekly obs vs pred plot
  p_test <- ggplot(test_weekly, aes(x = week)) +
    geom_line(aes(y = obs, color = "obs")) +
    geom_line(aes(y = pred, color = "pred")) +
    ggtitle("Test weekly: obs vs pred") +
    labs(x = "Week", y = "Count") +
    scale_color_manual(values = c("obs" = "blue", "pred" = "red")) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  # Arrange the plots together with a header that shows location and AR lags.
  gridExtra::grid.arrange(
    gridExtra::arrangeGrob(p_acf, p_pacf, p_res, p_train, p_test, ncol = 3),
    top = grid::textGrob(paste("Diagnostic Plots: Restaurant", loc, "- AR lags:", ar_label), 
                         gp = grid::gpar(fontsize = 16, fontface = "bold"))
  )
}

process_models <- function(df, loc, ar_lags, model_type="nb", sample=FALSE, standardize=TRUE, train_frac=0.5) {
  
  # model_dir <- file.path("modeling_results")
  # model_file <- file.path(model_dir, paste0(loc, "_model.rds"))
  # 
  # message(model_file)
  # 
  # # Check if the model file exists
  # if (file.exists(model_file)) {
  #   message("Loading existing model from: ", model_file)
  #   model <- readRDS(model_file)
  # } else {
  #   message("No existing model found. Training a new model...")
  
  # Filter to restaurant
  df <- df %>% filter(location_id == loc)
  
  # Fill gaps
  # fill_gaps(df)
  
  # Set default sample size to entire dataset
  if (sample) {df <- df %>% slice_sample(n = sample)}
  
  # Standardize if opted for
  if (standardize) {df <- df %>% standardize_data()}
  
  # Train test split
  splits <- split_data(df, train_frac)
  train_df <- splits$train
  test_df  <- splits$test
  
  # Fit models
  model <- NULL
  if (model_type == "nb") {model <- fit_nb_model(train_df, outcome, predictors)}
  if (model_type == "nbar") {model <- fit_nbar_model(train_df, outcome, predictors, ar_lags)}
  # }
  
  # Aggregate to weekly sums for train and test (use dates from original df)
  train_weekly <- agg_weekly(train_df, outcome, model = model)
  test_weekly  <- agg_weekly(test_df, outcome, model = model)
  
  # Show diagnostic plots: ACF, train weekly obs vs pred, test weekly obs vs pred
  diag_grob <- diag_plots(model, train_weekly, test_weekly, loc, paste(ar_lags, collapse = ","))
  
  return(list(model = model, diag_plot = diag_grob))
}


## ===== Data, Predictors, Outcome =====

setwd("C:/Users/Jared/Desktop/HSFL/restaurant-sales")

df_all_daily <- read_parquet("data/3_palate_data_parquet_modeling/all_locations_daily.parquet")

glimpse(df_all_daily)

# df_all_daily <- df_all_daily %>%
#   slice(round(nrow(df_all_daily)/2)-10000:round(nrow(df_all_daily)/2)+10000)

predictors <- c("vegan_window_avg",
                "vegetarian_window_avg",
                "meat_window_avg",
                "day_of_week_cat",
                #"weekend",
                #"day_of_month",
                "month_cat",
                "season",
                "year",
                "date"
)

outcome <- "vegan_outcome"


## ===== Define AR Lag Options =====

ar_lags_options <- list(
  "0"           = c(),
)


## ===== Loop Over All Locations and Store Visuals =====

# 19 location IDs
location_ids <- c(
  'SRQS8F7JWA9MZ',
  # '2HRX9P6HKXA8V',
  # 'JHDN7CF1C03X5',
  # 'L69HYJ4Y3TR91',
  # 'ED5J990H5VAZT',
  # 'W8T41JZK0ZMEP',
  # 'EMBVNVD207CC6',
  # 'C0BE4NDSW26QN',
  # '75WYSXR9QBK5M',
  # 'V3Q26BHF3SE2H',
  # 'LBZEEFSBJNB3Z',
  # 'SAFK7ND1HR6XS',
  # 'CB2KHY1C2G9PT',
  # 'S8MT0YGD2KTN9',
  # 'LFZFT3VASXPED',
  # '1SQPTEGYPH0GA',
  # '9XKJD8DQTH559',
  # 'LQ5EH4BKGV61T',
  '78AY09MVJVTYE'
)

results_list <- list()
plot_list <- list()

for(loc in location_ids) {
  results_list[[loc]] <- list()
  plot_list[[loc]] <- list()
  
  for(ar_label in names(ar_lags_options)) {
    cat("Processing location:", loc, "with AR lags:", ar_label, "\n")
    
    res <- process_models(df_all_daily, 
                          loc = loc, 
                          ar_lags = ar_lags_options[[ar_label]], 
                          model_type = "nbar", 
                          sample = FALSE, 
                          standardize = TRUE, 
                          train_frac = 0.5)
    
    # Store results in the nested lists
    results_list[[loc]][[ar_label]] <- res$model
    plot_list[[loc]][[ar_label]] <- res$diag_plot
    
    # Save the diagnostic plot as a PNG file (with loc and AR label in the name)
    png_filename <- file.path("modeling_results", paste0(loc, "_diagnostics_", ar_label, ".png"))
    png(png_filename, width = 1200, height = 800)
    grid.draw(res$diag_plot)
    dev.off()
    
    # Save the model object as an RDS file
    rds_filename <- file.path("modeling_results", paste0(loc, "_model_", ar_label, ".rds"))
    saveRDS(res$model, file = rds_filename)
  }
}
