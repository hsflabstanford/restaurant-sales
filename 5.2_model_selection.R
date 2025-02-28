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
    meat_price_real = meat_window_avg / (Value / cpi_base)
  ) %>%
  identity()

before_after_details_true <- read.csv("data/before_after_details_true.csv")
before_after_details_true

bad_restaurants <- c('AQD04SM0J92WA',
                     'LBMCPAYT7W36V',
                     'L3XS7WSJ4AJA3',
                     '1G5AJ17XCH2A8',
                     '3AXDVZJYN9DRS',
                     'MS8R16DY0JQAM',
                     'N0PC58FB2XAZ3',
                     'ADPFRN3QZRCXK',
                     'WJA3YCD4QBWRX',
                     '0RJH3FFPYBPEY',
                     'LZ5MR1TS37E7W')

restaurants_by_coverage <- read.csv('data/2_palate_data_parquet_cleaned/restaurants_by_4m_coverage.csv') %>%
  filter(!(location_id %in% bad_restaurants)) %>%
  pull(location_id)

df_all_daily %>%
  group_by(location_id) %>%
  summarize(count = n()) %>%
  arrange(match(location_id, restaurants_by_coverage)) %>%
  identity()

outcome <- "vegan_outcome"

ar_lag_sets_1 <- list(
  #c(),
  c(1),
  c(7),
  #c(14),
  #c(1,7),
  c(7,14,21),
  #c(1,2,3),
  c(1,2,3,4,5,6,7),
  #c(7,14,28),
  #c(1,2,3,4,5,6,7,14,21),
  c(1,2,3,4,5,6,7,14,21,28,42)
)

mean_lag_sets_1 <- list(
  c(),
  #c(1),
  c(7),
  #c(14),
  #c(1,7),
  #c(7,14,21),
  #c(1,2,3),
  #c(1,2,3,4,5,6,7),
  #c(7,14,28),
  #c(1,2,3,4,5,6,7,14,21),
  c(1,2,3,4,5,6,7,14,21,28,42)
)

predictors_short_term <- c(
  #"vegan_window_avg",
  #"meat_window_avg",
  "vegan_price_real",
  "meat_price_real",
  "day_of_week_cat",
  "weekend",
  "day_of_month",
  "month_cat",
  "season",
  "date"
)


predictors <- c(
  "vegan_window_avg",
  "vegetarian_window_avg",
  "meat_window_avg",
  "day_of_week_cat",
  "weekend",
  "day_of_month",
  "month_cat",
  "season",
  "year",
  "date"
)

# Count observations before and after intervention
df_all_daily %>%
  left_join(before_after_details_true %>% 
              mutate(cross_over_date = as.Date(cross_over_date)), 
            by = "location_id") %>%
  group_by(location_id) %>%
  filter(created_at >= (cross_over_date %m-% weeks(25)) & # 8
           created_at <= (cross_over_date %m+% weeks(17))) %>% # 2
  summarize(count = n(), na_count = sum(is.na(vegan_outcome))) %>%
  arrange(match(location_id, restaurants_by_coverage)) %>%
  identity()

# Filter each restaurants to k months before to k months after the promo date in before_after_details_true
df_all_intervention_period <- df_all_daily %>%
  left_join(before_after_details_true %>% 
              mutate(cross_over_date = as.Date(cross_over_date)), 
            by = "location_id") %>%
  group_by(location_id) %>%
  filter(created_at >= (cross_over_date %m-% weeks(25)) & # 8
           created_at <= (cross_over_date %m+% weeks(17))) %>% # 2
  ungroup()

all_param_grids <- list()
for (loc_id in restaurants_by_coverage[2:2]) {

# 4. Cross-validation wrapper function
fit_and_cv <- function(ar_lags, mean_lags, predictors) {
  cv_result <- tryCatch({
    walk_forward_cv_nbar(
      df_all_intervention_period,
      loc = loc_id,
      outcome = "vegan_outcome",
      predictors = predictors,
      initial_train_days = 63,
      test_days = 42,
      ar_lags = ar_lags,
      mean_lags = mean_lags,
      sample = FALSE
    )
  }, error = function(e) {
    message("fit_and_cv: Error in cross-validation: ", e$message)
    return(NULL)
  })
  
  if (is.null(cv_result)) {
    return(Inf)  # Return a worst-case error if CV fails
  }
  
  cv_err <- tryCatch({
    aggregate_cv_results(cv_result)
  }, error = function(e) {
    message("Error aggregating CV results: ", e$message)
    return(Inf)
  })
  
  return(cv_err)
}


# 5. Backward selection over predictors
fit_and_cv_with_backward <- function(ar_lags, mean_lags, full_predictors) {
  current_predictors <- full_predictors
  print(paste("Starting with predictors:", paste(current_predictors, collapse=", ")))
  
  best_error <- tryCatch(
    fit_and_cv(ar_lags, mean_lags, current_predictors),
    error = function(e) {
      message("Initial model failed, returning Inf error: ", e$message)
      return(Inf)  # Worst possible error
    }
  )
  
  improvement <- TRUE
  best_predictors <- current_predictors  # Track best working set
  
  while (improvement && length(current_predictors) > 1) {
    message("Current predictor set: ", paste(current_predictors, collapse = ", "))
    
    errors <- sapply(current_predictors, function(pred) {
      candidate_set <- current_predictors[current_predictors != pred]
      result <- tryCatch(
        fit_and_cv(ar_lags, mean_lags, candidate_set),
        error = function(e) {
          message("Skipping predictor removal due to error: ", e$message)
          return(Inf)  # Assign bad error so it won't be chosen
        }
      )
      if (is.null(result)) result <- Inf # Convert to Inf if there is still NULL somehow
      return(result)
    })
    
    # If all errors are Inf, exit the loop (no valid models left)
    if (all(errors == Inf)) {
      message("All remaining models failed, stopping backward selection.")
      improvement <- FALSE
      break
    }
    
    # Find best working model (ignoring Inf values)
    min_error <- min(errors, na.rm = TRUE)
    if (min_error < best_error) {
      best_error <- min_error
      best_pred <- current_predictors[which.min(errors)]
      current_predictors <- current_predictors[current_predictors != best_pred]
      best_predictors <- current_predictors  # Save best predictor set
      message("Removing predictor: ", best_pred, "; New set: ", paste(best_predictors, collapse = ", "))
    } else {
      message("No improvement, stopping backward selection.")
      improvement <- FALSE
      break
    }
  }
  
  message("Final selected predictors: ", paste(best_predictors, collapse = ", "))
  return(list(cv_error = best_error, predictors = best_predictors))
}



param_grid_lags <- expand.grid(ar_lags = ar_lag_sets_1,
                               mean_lags = mean_lag_sets_1, stringsAsFactors = FALSE)

names(param_grid_lags) <- c("ar_lags", "mean_lags")

# Start multisession
num_cores <- detectCores() - 1
print(num_cores)
plan(multisession, workers = num_cores)

# Run model training over grid in parallel
start_time <- Sys.time()
param_grid_lags$cv_results <- future_pmap(param_grid_lags, function(ar_lags, mean_lags) {
  result <- tryCatch({
    withTimeout({
      fit_and_cv_with_backward(ar_lags, mean_lags, predictors_short_term)
    }, timeout = 3 * 3600, onTimeout = "error")  # 4 hours timeout
  }, error = function(e) {
    message("Grid search error for ar_lags = ", paste(ar_lags, collapse = ","),
            " and mean_lags = ", paste(mean_lags, collapse = ","), ": ", e$message)
    return(list(cv_error = Inf, predictors = NULL))
  })

  # In case the result is NULL, fill it in with a safe fallback
  if (is.null(result)) {
    result <- list(cv_error = Inf, predictors = NULL)
  }
  return(result)
})
end_time <- Sys.time()

# Reset to sequential
plan(sequential)

# Print time
elapsed_time <- difftime(end_time, start_time, units = "secs")
print(elapsed_time)

# all_param_grids[[loc_id]] <- param_grid_lags
param_grid_lags
saveRDS(param_grid_lags, file = paste0("param_grid_lags_",loc_id,".rds"))

}

mem_used <- mem_used()  # Check before
start_time <- Sys.time()
fit_and_cv_with_backward(ar_lags = c(1,2,3,7,14,21), mean_lags = c(1,2,3,7,14,21), predictors_short_term)
end_time <- Sys.time()
mem_used_after <- mem_used()  # Check after
print(mem_used_after - mem_used)  # Memory used by one process
elapsed_time <- difftime(end_time, start_time, units = "secs")
print(elapsed_time)

# (Intercept) vegan_window_avg  meat_window_avg vegan_price_real  meat_price_real 
# -530.42654864      -4.47011150       0.89423051       4.59590570      -0.92689336 
# weekend     day_of_month       seasonfall     seasonspring     seasonsummer 
# 0.58974366      -0.07421215       0.00000000       0.00000000       0.00000000 
# seasonwinter             date 
# -532.00970931       0.05976945
