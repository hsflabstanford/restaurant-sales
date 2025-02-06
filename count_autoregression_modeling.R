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
  )
}

# fit NB model with given outcome and predictors
fit_nb_model <- function(df, outcome, predictors) {
  formula_str <- paste(outcome, "~", paste(predictors, collapse = " + "))
  MASS::glm.nb(as.formula(formula_str), data = df)
}

# Fit NB model with AR terms
fit_nbar_model <- function(df, outcome, predictors) {
  # Create time series object (weekly frequency assumed)
  outcome_ts <- ts(df[[outcome]]) # , frequency = 7
  # Convert predictors to a numeric matrix using model.matrix
  xreg <- if (!is.null(predictors)) {
    model.matrix(~ . - 1, data = df[, predictors])
  } else {
    NULL
  }
  # Fit tsglm with AR lags 1 to 6 (past_obs=6), no past_mean term
  tsglm(outcome_ts, 
        model = list(past_obs = c(), past_mean = c()), 
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
diag_plots <- function(model, train_weekly, test_weekly, loc) {
  
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
    theme_minimal()
  
  # Test weekly obs vs pred plot
  p_test <- ggplot(test_weekly, aes(x = week)) +
    geom_line(aes(y = obs, color = "obs")) +
    geom_line(aes(y = pred, color = "pred")) +
    ggtitle("Test weekly: obs vs pred") +
    labs(x = "Week", y = "Count") +
    scale_color_manual(values = c("obs" = "blue", "pred" = "red")) +
    theme_minimal()
  
  # Arrange plots in a grid
  gridExtra::grid.arrange(
    gridExtra::arrangeGrob(p_acf, p_pacf, p_res, p_train, p_test, ncol = 3),
    top = grid::textGrob(paste("Diagnostic Plots:", loc), gp = grid::gpar(fontsize = 16, fontface = "bold"))
  )
}

process_models <- function(df, loc, model_type="nb", sample=FALSE, standardize=TRUE, train_frac=0.5) {
  
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
  if (model_type == "nbar") {model <- fit_nbar_model(train_df, outcome, predictors)}
  
  # Aggregate to weekly sums for train and test (use dates from original df)
  train_weekly <- agg_weekly(train_df, outcome, model = model)
  test_weekly  <- agg_weekly(test_df, outcome, model = model)
  
  # Show diagnostic plots: ACF, train weekly obs vs pred, test weekly obs vs pred
  diag_grob <- diag_plots(model, train_weekly, test_weekly, loc)
  
  return(list(model = model, diag_plot = diag_grob))
}


## ===== Data, Predictors, Outcome =====

setwd("C:/Users/Jared/Desktop/HSFL/restaurant-sales")

df_all_daily <- read_parquet("data/3_palate_data_parquet_modeling/all_locations_daily.parquet")

df_all_daily

# df_all_daily <- df_all_daily %>%
#   slice(round(nrow(df_all_daily)/2)-10000:round(nrow(df_all_daily)/2)+10000)

predictors <- c("vegan_window_avg",
                "vegetarian_window_avg",
                "meat_window_avg",
                "day_of_week",
                #"weekend",
                "day_of_month",
                "month",
                "season",
                "date")

outcome <- "vegan_outcome"


## ===== Loop Over All Locations and Store Visuals =====

# 19 location IDs
location_ids <- c(
  'SRQS8F7JWA9MZ',
  #'2HRX9P6HKXA8V',
  #'JHDN7CF1C03X5',
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
  cat("Processing location:", loc, "\n")
  
  res <- process_models(df_all_daily, loc = loc, model_type = "nbar", 
                        sample = FALSE, standardize = TRUE, train_frac = 0.5)
  
  results_list[[loc]] <- res$model
  plot_list[[loc]] <- res$diag_plot
  
  # Save the diagnostic plot as a PNG file
  png_filename <- file.path("modeling_results", paste0(loc, "_diagnostics.png"))
  png(png_filename, width = 1200, height = 800)
  grid.draw(res$diag_plot)
  dev.off()
  
  # Save the model object as an RDS file
  rds_filename <- file.path("modeling_results", paste0(loc, "_model.rds"))
  saveRDS(res$model, file = rds_filename)
}


## ===== Shiny App UI and Server =====

# (The UI remains unchanged.)
ui <- fluidPage(
  titlePanel("Dashboard: Select a Restaurant Location"),
  sidebarLayout(
    sidebarPanel(
      selectInput("plot_key", "Choose a restaurant ID:", 
                  choices = names(plot_list), selected = names(plot_list)[1])
    ),
    mainPanel(
      h3(textOutput("restaurant_id")),
      plotOutput("selected_plot")
    )
  )
)

# In the server we now call grid.draw() on the stored grob
server <- function(input, output, session) {
  
  output$restaurant_id <- renderText({
    paste("Restaurant Location ID:", input$plot_key)
  })
  
  output$selected_plot <- renderPlot({
    # Create a header grob with the location ID.
    header_grob <- grid::textGrob("",
                                  gp = grid::gpar(fontsize = 16, fontface = "bold"))
    # Arrange the header above the diagnostic plot.
    combined_grob <- gridExtra::arrangeGrob(header_grob, plot_list[[input$plot_key]],
                                            ncol = 1, heights = c(0.1, 0.9))
    grid::grid.draw(combined_grob)
  })
}


## ===== Launch the Shiny App =====

shinyApp(ui = ui, server = server)