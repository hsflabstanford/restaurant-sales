# ## ===== Testing Rolling Forecast Function =====
#
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
# 
# # Display diagnostic plots for the rolling forecast residuals.
# diag_plots_rolling(test_df, outcome, loc = "SRQS8F7JWA9MZ", ar_label = "1")
# 
# 
#  