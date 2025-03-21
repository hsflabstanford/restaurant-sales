# Processing and visualizing
library(fpp3) # tibble, dplyr, tidyr, lubridate, ggplot2, tsibble, tsibbledata, feasts, fable
library(tidyverse)
library(arrow)
library(skimr)
library(shiny)
library(grid)
library(gridExtra)
library(conflicted)
c("select","filter") %>% walk(~ conflict_prefer(.x, "dplyr"))
c("year","month") %>% walk(~ conflict_prefer(.x, "lubridate"))

# Modeling
library(tscount)
library(sandwich)
library(lmtest)
library(MASS)
library(bayesforecast)

# Custom
source("tools/modeling_functions.R")


# ===============================
#             Set Up
# ===============================

# ===== Data =====

before_after_details_true <- read.csv("data/before_after_details_true.csv")

bad_restaurants <- c('AQD04SM0J92WA','LBMCPAYT7W36V','L3XS7WSJ4AJA3','1G5AJ17XCH2A8','3AXDVZJYN9DRS','MS8R16DY0JQAM','N0PC58FB2XAZ3','ADPFRN3QZRCXK','WJA3YCD4QBWRX','0RJH3FFPYBPEY','LZ5MR1TS37E7W')

restaurants_by_coverage <- read.csv('data/2_palate_data_parquet_cleaned/restaurants_by_4m_coverage.csv') %>%
  filter(!(location_id %in% bad_restaurants)) %>%
  filter(!(location_id %in% c("75WYSXR9QBK5M", 
                              "V3Q26BHF3SE2H", 
                              "CB2KHY1C2G9PT", 
                              "LFZFT3VASXPED"))) %>%
  pull(location_id)

df_all_daily <- read_parquet("data/3_palate_data_parquet_modeling/all_locations_daily_weather_inflation.parquet")


# ===== Subset Data =====

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


# ===== Predictors & Outcome =====

outcome <- "nonvegan_outcome"

predictors <- c(
  "vegan_price_real",
  "meat_price_real",
  "day_of_week_cat",
  "weekend",
  "month_cat",
  "season",
  "year",
  "inflation"#,
  #"temp",
  #"precip"
)


# ===============================
#       AR/Mean Lag options
# ===============================

#list_of_best_params_intervention <- list()
list_of_best_params_entire <- list()

# # Loop over restaurant IDs (here using the first 6 in restaurants_by_coverage)
# for (loc_id in restaurants_by_coverage) {
#   # Read intervention-specific parameter grid
#   file_intervention <- paste0("param_grid_lags_", loc_id, ".rds")
#   param_grid_intervention <- readRDS(file_intervention)
#   best_params_intervention <- param_grid_intervention[which.min(unlist(param_grid_intervention$cv_results)), ]
#   list_of_best_params_intervention[[loc_id]] <- best_params_intervention
# }

# Loop over restaurant IDs (here using the first 6 in restaurants_by_coverage)
for (loc_id in restaurants_by_coverage[1:6]) {
  # Read entire-data parameter grid
  file_entire <- paste0("param_grid_lags_", loc_id, ".rds")
  param_grid_entire <- readRDS(file_entire)
  best_params_entire <- param_grid_entire[which.min(unlist(param_grid_entire$cv_results)), ]
  list_of_best_params_entire[[loc_id]] <- best_params_entire
}
list_of_best_params_entire
# Initialize the restaurant lag options list
restaurant_lag_options <- list()

# Populate restaurant lag options based on best params
for (loc_id in restaurants_by_coverage) {
  best_params_intervention <- list_of_best_params_intervention[[loc_id]]
  best_params_entire <- list_of_best_params_entire[[loc_id]]
  
  # Create AR lag options for both sources
  ar_lag_options <- list()
  # if (!is.null(best_params_intervention$ar_lags[[1]]) && length(best_params_intervention$ar_lags[[1]]) > 0) {
  #   ar_lag_options[["intervention_data"]] <- best_params_intervention$ar_lags[[1]]
  # }
  if (!is.null(best_params_entire$ar_lags[[1]]) && length(best_params_entire$ar_lags[[1]]) > 0) {
    ar_lag_options[["entire_data"]] <- best_params_entire$ar_lags[[1]]} 
  else {
    ar_lag_options[["entire_data"]] <- numeric(0)}
  
  # Create Mean lag options for both sources
  mean_lag_options <- list()
  # if (!is.null(best_params_intervention$mean_lags[[1]]) && length(best_params_intervention$mean_lags[[1]]) > 0) {
  #   mean_lag_options[["intervention_data"]] <- best_params_intervention$mean_lags[[1]]
  # }
  if (!is.null(best_params_entire$mean_lags[[1]]) && length(best_params_entire$mean_lags[[1]]) > 0) {
    mean_lag_options[["entire_data"]] <- best_params_entire$mean_lags[[1]]} 
  else {
    mean_lag_options[["entire_data"]] <- numeric(0)}

  # Store the options in the main list for this restaurant location
  restaurant_lag_options[[loc_id]] <- list(ar = ar_lag_options, mean = mean_lag_options)
  
}

# For any restaurant not defined in restaurant_lag_options, use a default set.
default_lag_options <- list(
  ar   = list("1" = c(1)),
  mean = list("1" = c(1))
)


# ===============================
#       Run and Store Models
# ===============================

# ===== Loop Over All Locations and Store Visuals =====

results_list <- list()
plot_list <- list()
pred_plot_list <- list()

for(loc in restaurants_by_coverage[1:6]) {
  
  # If the location doesn't have specific options, use defaults
  lag_options <- if (!is.null(restaurant_lag_options[[loc]])) {
    restaurant_lag_options[[loc]]} 
  else {
    default_lag_options}
  
  results_list[[loc]] <- list()
  plot_list[[loc]] <- list()
  for(ar_label in names(lag_options$ar)) {
    for(mean_label in names(lag_options$mean)) {
      
      cat("Processing location:", loc, 
          "with AR lags:", ar_label, 
          "and Mean lags:", mean_label, "\n")
      
      res <- process_models(
        df_all_daily, 
        loc         = loc, 
        outcome     = outcome,
        predictors  = predictors,
        ar_lags     = lag_options$ar[[ar_label]], 
        mean_lags   = lag_options$mean[[mean_label]],
        model_type  = "nbar", 
        sample      = FALSE, 
        standardize = TRUE, 
        train_frac  = 0.7
      )
      
      # Create a combined label for both AR and mean lags
      combined_label <- paste0("AR: ", ar_label, " | Mean: ", mean_label)
      
      # Store results in the nested lists
      results_list[[loc]][[combined_label]] <- res$model
      plot_list[[loc]][[combined_label]] <- res$diag_plot
      pred_plot_list[[loc]] <- res$pred_plot
      
      
      # Save the diagnostic plot as a PNG file (with loc, AR, and mean lag labels in the name)
      png_filename <- file.path("modeling_results", paste0("gs_optimal_",loc, "_pred_plot.png"))
      png(png_filename, width = 1200, height = 800)
      grid.draw(res$pred_plot)
      dev.off()

      # Save the model object as an RDS file
      rds_filename <- file.path("modeling_results", paste0("gs_optimal_",loc, "_model.rds"))
      saveRDS(res$model, file = rds_filename)
      
    }
  }
}


# ===============================
#           Run Server
# ===============================

## ===== Shiny App UI and Server =====

# ui <- fluidPage(
#   titlePanel("Dashboard: Select a Restaurant Location"),
#   sidebarLayout(
#     sidebarPanel(
#       selectInput("restaurant_id", "Choose a restaurant ID:",
#                   choices = restaurants_by_coverage, selected = restaurants_by_coverage[1]),
#       # Use UI outputs for lag options so they update based on the selected restaurant
#       uiOutput("ar_lags_ui"),
#       uiOutput("mean_lags_ui")
#     ),
#     mainPanel(
#       h3(textOutput("restaurant_info")),
#       plotOutput("selected_plot")
#     )
#   )
# )
# 
# server <- function(input, output, session) {
# 
#   # A reactive expression to retrieve the lag options for the selected restaurant
#   restaurant_options <- reactive({
#     if (!is.null(restaurant_lag_options[[input$restaurant_id]])) {
#       restaurant_lag_options[[input$restaurant_id]]
#     } else {
#       default_lag_options
#     }
#   })
# 
#   # Render UI for AR lag selection based on the selected restaurant
#   output$ar_lags_ui <- renderUI({
#     selectInput("ar_lags", "Choose AR lag set:",
#                 choices = names(restaurant_options()$ar),
#                 selected = names(restaurant_options()$ar)[1])
#   })
# 
#   # Render UI for Mean lag selection based on the selected restaurant
#   output$mean_lags_ui <- renderUI({
#     selectInput("mean_lags", "Choose Mean lag set:",
#                 choices = names(restaurant_options()$mean),
#                 selected = names(restaurant_options()$mean)[1])
#   })
# 
#   output$restaurant_info <- renderText({
#     paste("Restaurant Location ID:", input$restaurant_id,
#           "| AR lag set:", input$ar_lags,
#           "| Mean lag set:", input$mean_lags)
#   })
# 
#   output$selected_plot <- renderPlot({
#     # Construct the combined label to access the correct plot
#     combined_label <- paste0("AR: ", input$ar_lags, " | Mean: ", input$mean_lags)
#     selected_plot <- plot_list[[ input$restaurant_id ]][[ combined_label ]]
#     grid::grid.draw(selected_plot)
#   })
# }
# 
# shinyApp(ui = ui, server = server)
