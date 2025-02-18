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

# Parallel
library(furrr)
library(future)
library(purrr)

source("modeling_functions.R")

## ===== Data, Predictors, Outcome =====

df_all_daily <- read_parquet("data/3_palate_data_parquet_modeling/all_locations_daily.parquet")

glimpse(df_all_daily)

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

df_all_daily <- df_all_daily %>%
  left_join(cpi_food_away, by = c("year", "month")) %>%
  mutate(
    vegan_price_real = vegan_window_avg / (Value / cpi_base),
    meat_price_real = meat_window_avg / (Value / cpi_base)
  ) %>%
  standardize_data()

df_loc <- df_all_daily %>% 
  filter(location_id == "SRQS8F7JWA9MZ")
outcome    <- "vegan_outcome"
predictors <- c("meat_window_avg", 
                #"day_of_week_cat", 
                #"month_cat", 
                #"season", 
                "year"
)

ar_lags    <- c(1,7,14,21)
mean_lags  <- c()

process_models(df_all_daily,
               loc = "SRQS8F7JWA9MZ",
               outcome = outcome,
               predictors = predictors,
               model_type = "nbar",
               ar_lags = ar_lags,
               mean_lags = mean_lags,
               sample = FALSE,
               standardize = FALSE,
               train_frac = 0.8)


initial_train_days <- 1000      # for example, use the first 100 days for initial training
test_days  <- 30               # forecast 30 days ahead in each fold


# # Define a grid of parameter combinations as a list.
# # Each element is a list with its own settings and a name.
# param_grid <- list(
#   list(
#     ar_lags    = c(1),
#     mean_lags  = c(),  # no past mean lags
#     predictors = c("meat_window_avg", "day_of_week_cat", "month_cat", "season", "year"),
#     model_name = "AR1_MEANnone_PRED1"
#   ),
#   list(
#     ar_lags    = c(1),
#     mean_lags  = c(1),  # one-lag past mean
#     predictors = c("meat_window_avg", "day_of_week_cat", "month_cat", "season", "year"),
#     model_name = "AR1_MEAN1_PRED1"
#   ),
#   list(
#     ar_lags    = c(1),
#     mean_lags  = c(),  # no past mean lags
#     predictors = c("meat_window_avg", "day_of_week_cat", "season", "year"),
#     model_name = "AR1_MEANnone_PRED2"
#   ),
#   list(
#     ar_lags    = c(1),
#     mean_lags  = c(1),  # one-lag past mean
#     predictors = c("meat_window_avg", "day_of_week_cat", "season", "year"),
#     model_name = "AR1_MEAN1_PRED2"
#   )
# )
# 
# # Set up parallel processing.
# plan(multisession)
# 
# 
# grid_search_summary <- future_map_dfr(param_grid, function(params) {
#   message("Running grid search for: ", params$model_name)
#   
#   cv_res <- walk_forward_cv_nbar(
#     df = df_loc,
#     outcome = outcome,
#     predictors = params$predictors,
#     initial_train_days = initial_train_days,
#     test_days = test_days,
#     ar_lags = params$ar_lags,
#     mean_lags = params$mean_lags
#   )
#   
#   overall_rmse <- rmse(cv_res$actual, cv_res$forecast)
#   
#   tibble(
#     model_name = params$model_name,
#     overall_rmse = overall_rmse
#   )
# })
# 
# print(grid_search_summary)