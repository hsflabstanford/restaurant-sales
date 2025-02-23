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

outcome <- "vegan_outcome"

# process_models(df_all_daily,
#                loc = "2HRX9P6HKXA8V",
#                outcome = "vegan_outcome",
#                predictors = c(#"meat_window_avg",
#                  "day_of_week_cat",
#                  #"day_of_month_cat",
#                  #"month_cat",
#                  "season",
#                  "year"),
#                model_type = "nbar",
#                ar_lags = c(1,7),
#                mean_lags = c(),
#                sample = FALSE,
#                standardize = FALSE,
#                train_frac = 0.95)
# 
# cv <- walk_forward_cv_nbar(df_all_daily,
#                            loc = "2HRX9P6HKXA8V",
#                            outcome = "vegan_outcome",
#                            predictors = c(#"meat_window_avg",
#                              "day_of_week_cat",
#                              #"day_of_month_cat",
#                              #"month_cat",
#                              "season",
#                              "year"),
#                            initial_train_days=200,
#                            test_days=30,
#                            ar_lags=c(1),
#                            mean_lags=c())




# === Full Backward Stepwise Selection ===

# starting_ar_lag_set <- c(1,2,3,4,5,6,7,14,21,28,35,42,49,56)
# starting_mean_lag_set <- c(1,2,3,4,5,6,7,14,21,28,35,42,49,56)
# num_ar_lags <- length(starting_ar_lag_set)
# 
# current_ar_lag_set <- starting_ar_lag_set
# cv_results <- list()

# # Backward stepwise selection
# while (length(current_ar_lag_set) > 1) {
#   
#   # Store CV results for each lag removed
#   lag_cv_errors <- numeric(length(current_ar_lag_set))
#   
#   for (i in seq_along(current_ar_lag_set)) {
#     
#     # Create a reduced lag set by removing one lag
#     reduced_ar_lag_set <- current_ar_lag_set[-i]
#     cv_error <- compute_cv_error(reduced_ar_lag_set, starting_mean_lag_set)
#     lag_cv_errors[i] <- cv_error
#     
#   }
#   
#   # Find the lag whose removal resulted in the smallest CV
#   best_lag_to_remove <- current_ar_lag_set[which.min(lag_cv_errors)]
#   
#   # Print progress
#   cat("Removing lag:", best_lag_to_remove, "\n")
#   
#   # Update current AR lag set
#   current_ar_lag_set <- setdiff(current_ar_lag_set, best_lag_to_remove)
#   
#   # Store the best CV result at this step
#   cv_results[[length(current_ar_lag_set)]] <- list(
#     remaining_lags = current_ar_lag_set,
#     cv_error = min(lag_cv_errors)
#   )
# }

# # Print final selected model
# cat("Final selected AR lags:", current_ar_lag_set, "\n")



# === Linear Backward Stepwise Selection ===

# library(doParallel)
# library(foreach)
# 
# num_cores <- detectCores() - 1  # Use all but one core to avoid freezing your system
# cl <- makeCluster(num_cores)    # Create cluster with `num_cores`
# registerDoParallel(cl)   
# 
# # Function to perform a computationally expensive task
# heavy_computation <- function(n) {
#   mat <- matrix(runif(n * n), n, n)  # Generate a random matrix
#   eigen(mat)$values  # Compute eigenvalues (heavy computation)
# }
# 
# # Benchmark parallel vs sequential execution
# benchmark_results <- microbenchmark(
#   parallel = {
#     result_parallel <- foreach(i = 1:10, .combine = c) %dopar% {
#       heavy_computation(500)  # Expensive operation: eigenvalues of a 500x500 matrix
#     }
#   },
#   sequential = {
#     result_sequential <- vector("list", 10)  # Preallocate storage
#     for (i in 1:10) {
#       result_sequential[[i]] <- heavy_computation(500)  # Same task, run sequentially
#     }
#   },
#   times = 5
# )
# 
# getDoParWorkers()
# 
# stopCluster(cl)
# registerDoSEQ()
# 
# getDoParWorkers()
# 
# print(benchmark_results)






ar_lag_sets_1 <- list(
  c(),    
  #c(1),
  #c(7),
  #c(14),
  #c(1,7),
  #c(7,14,21),
  # c(1,2,3),
  # c(1,2,3,4,5,6,7),
  # c(7,14,28),
  # c(1,2,3,4,5,6,7,14,21),
  c(1,2,3,4,5,6,7,14,21,28,42)
)

mean_lag_sets_1 <- list(
  c(),    
  #c(1),
  #c(7),
  #c(14),
  #c(1,7), <-
  #c(7,14,21), 
  # c(1,2,3),
  # c(1,2,3,4,5,6,7),
  # c(7,14,28),
  # c(1,2,3,4,5,6,7,14,21),
  c(1,2,3,4,5,6,7,14,21,28,42)
)


predictors <- c(#"vegan_window_avg",
  #"vegetarian_window_avg",
  "meat_window_avg",
  "day_of_week_cat",
  #"weekend",
  #"day_of_month",
  "month_cat",
  "season",
  "year"#,
  #"date"
)


predictor_sets <- list(
  #c("day_of_week_cat", "season", "year"),
  #c("day_of_week_cat", "season", "year", "meat_window_avg"),
  c("day_of_week_cat", "season", "year", "vegan_price_real"),
  c("day_of_week_cat", "season", "year")
)

param_grid <- expand.grid(ar_lag_sets_1, mean_lag_sets_1, predictor_sets, stringsAsFactors = FALSE)

names(param_grid) <- c("ar_lags", "mean_lags", "predictors")

num_cores <- detectCores() - 1
plan(multisession, workers = num_cores)

fit_and_cv <- function(ar_lags, mean_lags, predictors) {
  cv_result <- walk_forward_cv_nbar(
    df_all_daily,
    loc = "2HRX9P6HKXA8V",
    outcome = "vegan_outcome",
    predictors = predictors,
    initial_train_days = 100,
    test_days = 30,
    ar_lags = ar_lags,
    mean_lags = mean_lags,
    sample = 200
  )
  
  # Aggregate the CV results to produce an error metric
  cv_err <- aggregate_cv_results(cv_result)
  return(cv_err)
}

# Run model training over grid in parallel
start_time <- Sys.time()
cv_errors <- future_pmap(param_grid, function(ar_lags, mean_lags, predictors) {
  fit_and_cv(ar_lags, mean_lags, predictors)})
end_time <- Sys.time()

#Store
param_grid$cv_err <- unlist(cv_errors)

# Reset to sequential
plan(sequential)

print(param_grid)

elapsed_time <- difftime(end_time, start_time, units = "secs")
print(elapsed_time)

param_grid