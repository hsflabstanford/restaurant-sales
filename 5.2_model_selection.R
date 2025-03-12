# Processing and visualizing
library(fpp3) # tibble, dplyr, tidyr, lubridate, ggplot2, tsibble, tsibbledata, feasts, fable
library(arrow)
library(skimr)
library(shiny)
library(grid)
library(gridExtra)

# Modeling
library(tscount)
library(MASS)
library(bayesforecast)

# Parallel
library(doParallel)
library(future)
library(furrr)
library(data.table)
library(pryr)

source("tools/modeling_functions.R")

## ===== Data, Predictors, Outcome =====

before_after_details_true <- read.csv("data/before_after_details_true.csv")

bad_restaurants <- c('AQD04SM0J92WA','LBMCPAYT7W36V','L3XS7WSJ4AJA3','1G5AJ17XCH2A8','3AXDVZJYN9DRS','MS8R16DY0JQAM','N0PC58FB2XAZ3','ADPFRN3QZRCXK','WJA3YCD4QBWRX','0RJH3FFPYBPEY','LZ5MR1TS37E7W')

restaurants_by_coverage <- read.csv('data/2_palate_data_parquet_cleaned/restaurants_by_4m_coverage.csv') %>%
  filter(!(location_id %in% bad_restaurants)) %>%
  pull(location_id)

cpi_food_away <- read.csv("data/inflation.csv") %>%
  filter(Period != "S01" & Period != "S02") %>%
  mutate(
    month = as.numeric(sub("M", "", Period)),  
    date = as.Date(paste(Year, month, "01", sep = "-")),
    year = year(date),
    month = month(date)
  ) %>% dplyr::select(year, month, Value)

base_year <- 2018
base_month <- 1
cpi_base <- cpi_food_away %>% filter(year == base_year & month == base_month) %>% pull(Value)

df_all_daily <- read_parquet("data/3_palate_data_parquet_modeling/all_locations_daily.parquet") %>%
  process_predictors() %>%
  left_join(cpi_food_away, by = c("year", "month")) %>%
  mutate(
    vegan_price_real = vegan_window_avg / (Value / cpi_base),
    meat_price_real = meat_window_avg / (Value / cpi_base),
    inflation = Value
  ) %>%
  identity()

num_weeks_before <- 25 # 8
num_weeks_after <- 17 # 2

# Filter each restaurants to k months before to k months after the promo date in before_after_details_true
df_all_intervention_period <- df_all_daily %>%
  left_join(before_after_details_true %>% 
              mutate(cross_over_date = as.Date(cross_over_date)), 
            by = "location_id") %>%
  group_by(location_id) %>%
  filter(created_at >= (cross_over_date %m-% weeks(num_weeks_before)) &
           created_at <= (cross_over_date %m+% weeks(num_weeks_after))) %>%
  ungroup()

ar_lag_sets_1 <- list(
  c(),
  c(1),
  c(1,2),
  c(1,2,3),
  c(1,2,3,4,5,6,7),
  c(1,2,3,4,5,6,7,14,21),
  c(1,2,3,4,5,6,7,14,21,28,42),
  c(1,2,3,4,5,6,7,14,21,28,42,56),
  c(1,3,5,7),
  c(1,7),
  c(1,7,14,28),
  c(1,7,28,56),
  c(1,7,14,21,28,42,56),
  c(7),
  c(7,28),
  c(7,14,21),
  c(7,28,56),
  c(7,14,21,28),
  c(14,28),
  c(28,56)
)

mean_lag_sets_1 <- list(
  c(),
  c(1),
  c(1,2),
  c(1,2,3),
  c(1,2,3,4,5,6,7),
  c(1,2,3,4,5,6,7,14,21),
  c(1,2,3,4,5,6,7,14,21,28,42),
  c(1,2,3,4,5,6,7,14,21,28,42,56),
  c(1,3,5,7),
  c(1,7),
  c(1,7,14,28),
  c(1,7,28,56),
  c(1,7,14,21,28,42,56),
  c(7),
  c(7,28),
  c(7,14,21),
  c(7,28,56),
  c(7,14,21,28),
  c(14,28),
  c(28,56)
)

outcome <- "nonvegan_outcome"

predictors <- c(
  "vegan_price_real",
  "meat_price_real",
  "day_of_week_cat",
  "weekend",
  "month_cat",
  "season",
  "year",
  "inflation"
)

## ======= View Dataset Sizes =======

# df_subset_numeric <- df_all_daily %>%
#   filter(location_id == "SRQS8F7JWA9MZ") %>%
#   mutate(across(all_of(predictors), as.numeric)) %>%
#   dplyr::select(all_of(predictors)) %>%
#   identity()
# cor(df_subset_numeric)

# Full data
df_all_daily %>%
  group_by(location_id) %>%
  summarize(count = n()) %>%
  arrange(match(location_id, restaurants_by_coverage)) %>%
  identity()

# Partial data before and after intervention
df_all_daily %>%
  left_join(before_after_details_true %>% 
              mutate(cross_over_date = as.Date(cross_over_date)), 
            by = "location_id") %>%
  group_by(location_id) %>%
  filter(created_at >= (cross_over_date %m-% weeks(num_weeks_before)) & # 8
           created_at <= (cross_over_date %m+% weeks(num_weeks_after))) %>% # 2
  summarize(count = n(), na_count = sum(is.na(vegan_outcome))) %>%
  arrange(match(location_id, restaurants_by_coverage)) %>%
  identity()


## ======= AR/Mean Selection Functions =======

# 4. Cross-validation wrapper function
fit_and_cv <- function(df, 
                       loc_id, 
                       outcome, 
                       predictors, 
                       ar_lags, 
                       mean_lags, 
                       initial_train_days = 63, 
                       test_days = 42) {
  
  print(mean_lags)
  
  # Calculate CV result
  cv_result <- tryCatch(
    walk_forward_cv_nbar(df,
                         loc = loc_id,
                         outcome = outcome,
                         predictors = predictors,
                         initial_train_days = initial_train_days,
                         test_days = test_days,
                         ar_lags = ar_lags,
                         mean_lags = mean_lags,
                         sample = FALSE), 
    error = function(e) {
      message("fit_and_cv: Error in cross-validation: ", e$message)
      NULL}
    )
  
  # Don't try to aggregate if it already failed
  if (is.null(cv_result)) return(Inf)
  
  # Fit CV result
  tryCatch(
    aggregate_cv_results(cv_result), 
    error = function(e) {
      message("Error aggregating CV results: ", e$message)
      Inf}
    )
}


# 5. Backward selection over predictors
fit_and_select_backward <- function(df, 
                                    loc_id, 
                                    outcome, 
                                    predictors, 
                                    ar_lags, 
                                    mean_lags) {
  
  # Establish superset predictors
  current_predictors <- predictors
  print(paste("Starting with predictors:", paste(predictors, collapse=", ")))
  
  # Attempt fitting
  best_error <- fit_and_cv(df, loc_id, outcome, predictors, ar_lags, mean_lags)
  if (best_error == Inf) message("Initial model failed, giving it Inf CV error")
  
  # Track best working set
  improvement <- TRUE
  best_predictors <- current_predictors  
  while (1 < length(current_predictors) && improvement) {
    message("Current predictor set: ", paste(current_predictors, collapse = ", "))
    
    errors <- sapply(current_predictors, function(pred) {
      candidate_set <- current_predictors[current_predictors != pred]
      result <- fit_and_cv(df, loc_id, outcome, candidate_set, ar_lags, mean_lags)
      if (result == Inf) message("Removing predictor, ", pred, " caused an error, giving Inf for it")
      return(result)
    })
    
    # If all errors are Inf, exit the loop (no valid models left)
    if (all(errors == Inf)) {
      message("All remaining models failed, stopping backward selection")
      break
    }
    
    # Find best working model
    min_error <- min(errors, na.rm = TRUE)
    if (min_error < best_error) {
      best_error <- min_error
      best_removal <- current_predictors[which.min(errors)]
      best_predictors <- current_predictors[current_predictors != best_removal]
      currents_predictors <- best_predictors  # Save best predictor set
      message("Removing predictor: ", best_pred, "; New set: ", paste(best_predictors, collapse = ", "))} 
    else {
      message("No improvement, stopping backward selection")
      improvement <- FALSE
    }
  }
  
  # Return
  message("Final selected predictors: ", paste(best_predictors, collapse = ", "))
  return(list(cv_error = best_error, predictors = best_predictors))
}


parallelize_garch_models <- function(fit_func, 
                                     df, 
                                     loc_id,  
                                     outcome,
                                     predictors,
                                     ar_lag_sets, 
                                     mean_lag_sets,
                                     timeout = 3 # timeout in minutes
                                     ) {
  
  # Add a time bound
  time_bounded_func <- function(df_, loc_id_, outcome_, predictors_, ar_lags_, mean_lags_) {
    withTimeout(
      fit_func(df_, loc_id_, outcome_, predictors_, ar_lags_, mean_lags_), 
      timeout = timeout * 60,
      onTimeout = "error"
      )  
  }

  # Add error handling
  error_handled_func <- function(df_, loc_id_, outcome_, predictors_, ar_lags_, mean_lags_) {
    result <- tryCatch(
      time_bounded_func(df_, loc_id_, outcome_, predictors_, ar_lags_, mean_lags_),
      error = function(e) {
        message("Grid search error for ar_lags = ",
                paste(ar_lags_, collapse = ","),
                " and mean_lags = ", 
                paste(mean_lags_, collapse = ","),
                ": ", 
                e$message) 
        list(cv_error = Inf, predictors = predictors_)}
    )
    if (is.null(result)) result <- list(cv_error = Inf, predictors = predictors_)
    result
  }
  
  # Initialize grid of AR and mean lags
  param_grid_lags <- expand.grid(ar_lags = ar_lag_sets_1, 
                                 mean_lags = mean_lag_sets_1, stringsAsFactors = FALSE)
  names(param_grid_lags) <- c("ar_lags", 
                              "mean_lags")
  
  # Start multisession
  num_cores <- detectCores() - 1
  print(num_cores)
  plan(multisession, workers = num_cores)
  
  # Start memory and time tracking
  mem_used <- mem_used()
  start_time <- Sys.time()
  
  # Run model training over grid in parallel
  param_grid_lags$cv_results <- future_pmap(param_grid_lags, function(ar_lags_, mean_lags_) {error_handled_func(df, loc_id, outcome, predictors, ar_lags_, mean_lags_)})

  # End memory and time tracking
  end_time <- Sys.time()
  mem_used_after <- mem_used()
  print(mem_used_after - mem_used)
  print(difftime(end_time, start_time, units = "secs"))
  
  # Return to single core
  plan(sequential)
  
  # Save
  saveRDS(param_grid_lags, file = paste0("param_grid_lags_",loc_id,".rds"))
  
  # Return
  param_grid_lags
}

# for (loc_id in restaurants_by_coverage) {
# 
#   param_grid_lags <- parallelize_garch_models(fit_func = fit_and_cv,
#                                               df = df_all_intervention_period,
#                                               loc_id = loc_id,
#                                               outcome = outcome,
#                                               predictors = predictors,
#                                               ar_lag_sets = ar_lag_sets_1,
#                                               mean_lag_sets = mean_lag_sets_1)
# 
#   saveRDS(param_grid_lags, file = paste0("param_grid_lags_",loc_id,".rds"))
#   
# }


# param_grid_lags[which.min(unlist(param_grid_lags$cv_results)),]
# 
# param_grid_lags

#           ar_lags         mean_lags
# 31      7, 14, 28            7
# cv_results
# 31   5281.302

list_of_param_grids <- list()
list_of_best_params <- list()
for (loc_id in restaurants_by_coverage[1:6]) {
  param_grid_lags <- readRDS(paste0("param_grid_lags_",loc_id,".rds"))
  list_of_param_grids[[loc_id]] <- param_grid_lags
  best_params <- param_grid_lags[which.min(unlist(param_grid_lags$cv_results)),]
  list_of_best_params[[loc_id]] <- best_params
}

list_of_param_grids
list_of_best_params