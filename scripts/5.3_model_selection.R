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
  filter(!(location_id %in% c('75WYSXR9QBK5M','CB2KHY1C2G9PT'))) %>%
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
  #c(),
  c(1),
  c(1,2),
  #c(1,2,3),
  #c(1,2,3,4,5,6,7),
  c(1,2,3,4,5,6,7,14,28),
  #c(1,2,3,4,5,6,7,14,21,28,42),
  c(1,2,3,4,5,6,7,14,21,28,42,56),
  c(1,3,5,7),
  #c(1,7),
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
  #c(),
  c(1),
  #c(1,2),
  #c(1,2,3),
  #c(1,2,3,4,5,6,7),
  #c(1,2,3,4,5,6,7,14,28),
  #c(1,2,3,4,5,6,7,14,21,28,42),
  c(1,2,3,4,5,6,7,14,21,28,42,56),
  #c(1,3,5,7),
  #c(1,7),
  c(1,7,14,28),
  c(1,7,28,56),
  #c(1,7,14,21,28,42,56),
  c(7),
  #c(7,28),
  c(7,14,21),
  c(7,28,56),
  c(7,14,21,28),
  c(14,28),
  c(28,56)
)

# ar_lag_sets_1 <- list(
#   c(),
#   c(1),
#   c(1,2),
#   c(1,2,3),
#   c(1,2,3,4,5,6,7),
#   c(1,2,3,4,5,6,7,14,28),
#   c(1,2,3,4,5,6,7,14,21,28,42),
#   c(1,2,3,4,5,6,7,14,21,28,42,56),
#   c(1,3,5,7),
#   c(1,7),
#   c(1,7,14,28),
#   c(1,7,28,56),
#   c(1,7,14,21,28,42,56),
#   c(7),
#   c(7,28),
#   c(7,14,21),
#   c(7,28,56),
#   c(7,14,21,28),
#   c(14,28),
#   c(28,56)
# )
# 
# mean_lag_sets_1 <- list(
#   c(),
#   c(1),
#   c(1,2),
#   c(1,2,3),
#   c(1,2,3,4,5,6,7),
#   c(1,2,3,4,5,6,7,14,28),
#   c(1,2,3,4,5,6,7,14,21,28,42),
#   c(1,2,3,4,5,6,7,14,21,28,42,56),
#   c(1,3,5,7),
#   c(1,7),
#   c(1,7,14,28),
#   c(1,7,28,56),
#   c(1,7,14,21,28,42,56),
#   c(7),
#   c(7,28),
#   c(7,14,21),
#   c(7,28,56),
#   c(7,14,21,28),
#   c(14,28),
#   c(28,56)
# )

ar_lag_sets_1 <- list(
  c(1)

)

mean_lag_sets_1 <- list(
  c(1)
)

# Create the grid of hand-picked configurations.
# Using I() will preserve the list elements in each cell.
param_grid_lags <- expand.grid(
  ar_lags = I(ar_lag_sets_1),
  mean_lags = I(mean_lag_sets_1),
  stringsAsFactors = FALSE
)

# Define candidate lag values for AR and Mean
lag_values <- c(1, 2, 3, 4, 5, 5, 6, 7, 14, 21, 28, 35, 42, 49, 56)
# Concatenate for AR and Mean so that we have a total of 30 positions
# The first 15 positions correspond to AR and the next 15 to Mean.
candidate_lags <- c(lag_values, lag_values)
n <- length(candidate_lags)  # n = 30

# Parameters for our design
n_pool <- 1000   # Size of the random pool (increase for better coverage)
n_design <- 80   # Number of configurations you want to keep

set.seed(123)  # For reproducibility

# Generate a pool of random binary configurations (each row is one configuration)
candidate_configs <- matrix(rbinom(n_pool * n, 1, 0.5), nrow = n_pool, ncol = n)

# Function to compute the Hamming distance between two binary vectors
hamming_distance <- function(x, y) {
  sum(x != y)
}

# Greedy selection:
# Start with a randomly chosen configuration,
# then iteratively add the candidate that maximizes the minimum Hamming distance
selected_indices <- integer(n_design)
selected_indices[1] <- sample(1:n_pool, 1)
remaining_indices <- setdiff(1:n_pool, selected_indices[1])

for (i in 2:n_design) {
  # For each remaining candidate, compute its minimum Hamming distance to the already selected ones.
  min_dists <- sapply(remaining_indices, function(j) {
    candidate <- candidate_configs[j, ]
    min(sapply(selected_indices[1:(i - 1)], function(idx) {
      hamming_distance(candidate_configs[idx, ], candidate)
    }))
  })
  
  # Choose the candidate that maximizes this minimum distance
  best_idx <- remaining_indices[which.max(min_dists)]
  selected_indices[i] <- best_idx
  remaining_indices <- setdiff(remaining_indices, best_idx)
}

# The final design is the set of selected configurations.
final_design <- candidate_configs[selected_indices, ]

# Function to convert a binary row (length = 30) into a list with AR and Mean lags.
# The first 15 elements are for AR; the next 15 are for Mean.
convert_config <- function(binary_row, lag_values) {
  # For AR: select lags where binary indicator is 1
  ar_selected <- lag_values[as.logical(binary_row[1:15])]
  # For Mean: select lags where binary indicator is 1
  mean_selected <- lag_values[as.logical(binary_row[16:30])]
  return(list(ar_lags = ar_selected, mean_lags = mean_selected))
}

# Apply the function to each row of your final_design matrix
# (Assume final_design has been created as in your code)
design_list <- apply(final_design, 1, convert_config, lag_values = lag_values)

# Convert the list into a data frame with list columns
df_design <- data.frame(
  ar_lags = I(lapply(design_list, function(x) x$ar_lags)),
  mean_lags = I(lapply(design_list, function(x) x$mean_lags))
)

# Combine the two designs (rows will be stacked)
combined_design <- rbind(param_grid_lags, df_design)

# View the combined parameter grid
print(combined_design)




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
  
  
  # # Save
  # saveRDS(param_grid_lags, file = paste0("param_grid_lags_",loc_id,".rds"))
  
  # Return
  param_grid_lags
}

# # Start multisession
# num_cores <- detectCores() - 1
# print(num_cores)
# plan(multisession, workers = num_cores)
# for (loc_id in restaurants_by_coverage[1:6]) {
# 
#   # Rprof("profile_output.out")
#   param_grid_lags <- parallelize_garch_models(fit_func = fit_and_cv,
#                                               df = df_all_daily, # df_all_intervention_period
#                                               loc_id = loc_id,
#                                               outcome = outcome,
#                                               predictors = predictors,
#                                               ar_lag_sets = ar_lag_sets_1,
#                                               mean_lag_sets = mean_lag_sets_1)
#   # Rprof(NULL)
# 
#   saveRDS(param_grid_lags, file = paste0("param_grid_lags_entire_data_",loc_id,".rds"))
# 
# }
# 
# plan(sequential)

fit_and_select_forward <- function(df, loc_id, outcome, predictors, 
                                   # initial candidate pools for each class:
                                   initial_AR   = c(1, 2, 7, 28),
                                   initial_Mean = c(1, 7, 14, 28),
                                   # predetermined (full) sequences for updates:
                                   full_AR   = c(1, 2, 3, 4, 5, 6, 7, 14, 21, 28, 35, 42, 49, 56),
                                   full_Mean = c(1, 2, 3, 4, 5, 6, 7, 14, 21, 28, 35, 42, 49, 56)) {
  
  # Initialize the selected lags (empty at start)
  selected_AR   <- c()
  selected_Mean <- c()
  
  # Build the unified candidate pool as a list of candidates (each with type and lag)
  candidates <- list()
  for(lag in initial_AR) {
    candidates[[length(candidates) + 1]] <- list(type = "AR", lag = lag)
  }
  for(lag in initial_Mean) {
    candidates[[length(candidates) + 1]] <- list(type = "Mean", lag = lag)
  }
  
  best_error <- Inf
  improvement <- TRUE
  
  while(0 < length(candidates) && (length(selected_AR) + length(selected_Mean)) < 10 && improvement) {
    improvement <- FALSE
    # Evaluate each candidate by adding it to the current model and computing CV error.
    candidate_errors <- sapply(candidates, function(candidate) {
      if(candidate$type == "AR") {
        new_AR   <- sort(unique(c(selected_AR, candidate$lag)))
        new_Mean <- selected_Mean
      } else {
        new_AR   <- selected_AR
        new_Mean <- sort(unique(c(selected_Mean, candidate$lag)))
      }
      # fit_and_cv_INGARCH is assumed to return the CV error for a given INGARCH model
      error_val <- fit_and_cv(df, loc_id, outcome, predictors, new_AR, new_Mean)
      # model <- fit_nbar_model(df, outcome, predictors, new_AR, new_Mean)
      # res <- residuals(model)
      # error_val <- sum(res^2) / length(res)
      
      return(error_val)
    })
    
    # Find the candidate (AR or Mean) with the minimum error
    best_candidate_idx   <- which.min(candidate_errors)
    best_candidate_error <- candidate_errors[best_candidate_idx]
    
    if(best_candidate_error < best_error) {
      improvement <- TRUE
      best_error <- best_candidate_error
      chosen_candidate <- candidates[[best_candidate_idx]]
      
      # Update the selected set based on the candidate type.
      if(chosen_candidate$type == "AR") {
        selected_AR <- sort(unique(c(selected_AR, chosen_candidate$lag)))
      } else {
        selected_Mean <- sort(unique(c(selected_Mean, chosen_candidate$lag)))
      }
      
      # Remove the chosen candidate from the unified candidate pool.
      candidates <- candidates[-best_candidate_idx]
      
      # Now update the candidate pool on the chosen side by adding the next available lag.
      if(chosen_candidate$type == "AR") {
        next_candidate <- NA
        # Look in full_AR for the smallest lag greater than the chosen one that isn’t already selected or in the pool.
        for(lag in full_AR[full_AR > chosen_candidate$lag]) {
          ar_candidates <- sapply(candidates, function(cand) {
            if(cand$type == "AR") cand$lag else NA
          })
          ar_candidates <- ar_candidates[!is.na(ar_candidates)]
          if(!(lag %in% selected_AR) && !(lag %in% ar_candidates)) {
            next_candidate <- lag
            break
          }
        }
        if(!is.na(next_candidate)) {
          candidates[[length(candidates) + 1]] <- list(type = "AR", lag = next_candidate)
        }
      } else if(chosen_candidate$type == "Mean") {
        next_candidate <- NA
        for(lag in full_Mean[full_Mean > chosen_candidate$lag]) {
          mean_candidates <- sapply(candidates, function(cand) {
            if(cand$type == "Mean") cand$lag else NA
          })
          mean_candidates <- mean_candidates[!is.na(mean_candidates)]
          if(!(lag %in% selected_Mean) && !(lag %in% mean_candidates)) {
            next_candidate <- lag
            break
          }
        }
        if(!is.na(next_candidate)) {
          candidates[[length(candidates) + 1]] <- list(type = "Mean", lag = next_candidate)
        }
      }
      
      message("Added ", chosen_candidate$type, " lag: ", chosen_candidate$lag,
              ". Selected AR: ", paste(selected_AR, collapse = ", "),
              " | Selected Mean: ", paste(selected_Mean, collapse = ", "))
      message("Current candidate pool:")
      for (cand in candidates) {
        message(cand$type, ": ", cand$lag)
      }
    } else {
      message("No candidate improved the CV error. Stopping selection.")
      improvement <- FALSE
    }
  }
  
  message("Final selected lags: AR: ", paste(selected_AR, collapse = ", "),
          "; Mean: ", paste(selected_Mean, collapse = ", "))
  return(list(cv_error = best_error, AR = selected_AR, Mean = selected_Mean))
}

# fit_and_select_forward(df_all_intervention_period %>% 
#                          filter(location_id == "SRQS8F7JWA9MZ"), 
#                        "SRQS8F7JWA9MZ", 
#                        outcome, 
#                        predictors)



safe_forward_selection <- function(df, 
                                   loc_id, 
                                   outcome, 
                                   predictors) {
  tryCatch(
    {param_grid_lags_fs <- fit_and_select_forward(df %>% filter(location_id == loc_id), 
                                                 loc_id, 
                                                 outcome, 
                                                 predictors)
    saveRDS(param_grid_lags_fs, file = paste0("param_grid_lags_forward_selection_",loc_id,".rds"))
    list(success = TRUE, result = param_grid_lags_fs)}, 
    error = function(e) {
      message("Forward selection failed or timed out for location ", loc_id, ": ", e$message)
      list(success = FALSE, error_message = e$message)
      })
}


parallelize_forward_selection <- function(df,
                                          location_ids,
                                          outcome,
                                          predictors,
                                          plan_cores = 12) {
  
  # Set up the parallel plan with the desired number of cores
  plan(multisession, workers = plan_cores)
  
  # Use future_map to run safe_forward_selection for each location in parallel
  future_map(
    location_ids,
    ~ safe_forward_selection(df, .x, outcome, predictors),
    .options = furrr_options(seed = TRUE)  # for reproducibility
  )
  
  # Optionally return to sequential processing
  plan(sequential)
}

parallelize_forward_selection(df_all_daily, 
                              restaurants_by_coverage[1:10],
                              outcome,
                              predictors)

# summaryRprof("profile_output.out")
# param_grid_lags
# param_grid_lags[which.min(unlist(param_grid_lags$cv_results)),]
# 
# param_grid_lags

#           ar_lags         mean_lags
# 31      7, 14, 28            7
# cv_results
# 31   5281.302

# list_of_param_grids <- list()
# list_of_best_params <- list()
# for (loc_id in restaurants_by_coverage[1:6]) {
#   param_grid_lags <- readRDS(paste0("param_grid_lags_",loc_id,".rds"))
#   list_of_param_grids[[loc_id]] <- param_grid_lags
#   best_params <- param_grid_lags[which.min(unlist(param_grid_lags$cv_results)),]
#   list_of_best_params[[loc_id]] <- best_params
# }
# 
# list_of_param_grids
# list_of_best_params