# Processing and visualizing
library(fpp3) # tibble, dplyr, tidyr, lubridate, ggplot2, tsibble, tsibbledata, feasts, fable
library(tidyverse)
library(arrow)
library(skimr)
library(shiny)
library(grid)
library(gridExtra)
library(png)
library(conflicted)
c("select", "filter") %>% walk(~ conflict_prefer(.x, "dplyr"))
c("year", "month") %>% walk(~ conflict_prefer(.x, "lubridate"))

# Modeling
library(tscount)
library(sandwich)
library(lmtest)
library(MASS)
library(bayesforecast)

# Custom
source("tools/modeling_functions.R")



# ─────────────────────────────────────────────────────────────
# Step 1: Set-up
# ─────────────────────────────────────────────────────────────

# ===== Data =====

before_after_details_true <- read.csv("data/before_after_details_true.csv")

bad_restaurants <- c(
  "AQD04SM0J92WA", "LBMCPAYT7W36V", "L3XS7WSJ4AJA3", "1G5AJ17XCH2A8",
  "3AXDVZJYN9DRS", "MS8R16DY0JQAM", "N0PC58FB2XAZ3", "ADPFRN3QZRCXK",
  "WJA3YCD4QBWRX", "0RJH3FFPYBPEY", "LZ5MR1TS37E7W"
)

restaurants_by_coverage <- read.csv("data/3_data_parquet_relabeled/restaurants_by_4m_coverage.csv") %>%
  filter(!(location_id %in% bad_restaurants)) %>%
  filter(!(location_id %in% c("75WYSXR9QBK5M",
                              "V3Q26BHF3SE2H",
                              "CB2KHY1C2G9PT",
                              "LFZFT3VASXPED",
                              "LQ5EH4BKGV61T"))) %>%
  pull(location_id)

df_all_daily <- read_parquet("data/3_palate_data_parquet_modeling/all_locations_daily_weather_inflation.parquet")

df_all_daily %>% 
  filter(location_id == "L69HYJ4Y3TR91") %>% 
  dplyr::select(created_at, inflation) %>% 
  ggplot(aes(x = created_at, y = inflation)) + 
  geom_line()


# ===== Subset Data =====

num_weeks_before <- 25
num_weeks_after <- 17

# Filter each restaurants to k months before to k months after the promo date in before_after_details_true
df_all_intervention_period <- df_all_daily %>%
  left_join(before_after_details_true %>%
              mutate(cross_over_date = as.Date(cross_over_date)),
            by = "location_id") %>%
  group_by(location_id) %>%
  filter(created_at >= (cross_over_date %m-% weeks(num_weeks_before)) &
           created_at <= (cross_over_date %m+% weeks(num_weeks_after))) %>%
  ungroup()


# ===== Predictors & Outcomes =====

predictors <- c(
  "vegan_price_real",
  "meat_price_real",
  "day_of_week_cat",
  "weekend",
  "month_cat",
  "season",
  "year",
  "inflation",
  "temp",
  "precip"
)

outcomes <- c("nonvegan_outcome", "vegan_outcome")

data_types <- c("entire", "intervention")


# ─────────────────────────────────────────────────────────────
# Step 2: Retrieve AR/mean lag options
# ─────────────────────────────────────────────────────────────

restaurant_lag_options <- list()
for (loc_id in restaurants_by_coverage[1:6]) {
  
  # Read parameters
  param_grid_entire <- readRDS(paste0("validation_results/", "param_grid_lags_", loc_id, ".rds"))
  param_grid_intervention <- readRDS(paste0("validation_results/param_grid_lags_", loc_id, ".rds"))
  best_params_entire <- param_grid_entire[which.min(unlist(param_grid_entire$cv_results)), ]
  best_params_intervention <- param_grid_intervention[which.min(unlist(param_grid_intervention$cv_results)), ]
  
  ar_lags <- best_params_entire$ar_lags[[1]]
  mean_lags <- best_params_entire$mean_lags[[1]]
  
  lag_combo_list <- list(
    ar = ar_lags,
    mean = mean_lags,
    cv = best_params_entire$cv_results[[1]]
  )
  
  # Create lag combination string
  ar_str <- if (!is.null(ar_lags)) {paste("AR:", paste(ar_lags, collapse = ","))} else {"AR: none"}
  mean_str <- if (!is.null(mean_lags)) {paste("Mean:", paste(mean_lags, collapse = ","))} else {"Mean: none"}
  lag_combo <- paste(ar_str, mean_str)
  
  # Build nested list for each restaurant
  restaurant_lag_options[[loc_id]] <- list()
  for (outcome in outcomes) {
    restaurant_lag_options[[loc_id]][[outcome]] <- list()
    for (data_type in data_types) {
      restaurant_lag_options[[loc_id]][[outcome]][[data_type]] <- setNames(
        list(lag_combo_list),
        lag_combo
      )
    }
  }
}

# Create default options for restaurants without optimized parameters
default_lag_options <- list()
for (outcome in outcomes) {
  default_lag_options[[outcome]] <- list()
  for (data_type in data_types) {
    default_lag_options[[outcome]][[data_type]] <- list(
      "AR: 1 Mean: 1" = list(
        ar = c(1),
        mean = c(1),
        cv = NA
      )
    )
  }
}


# ===============================
#       Run and Store Models
# ===============================

# ===== Loop Over All Locations and Store Visuals =====

results_list <- list()


for (loc in restaurants_by_coverage) {
  results_list[[loc]] <- list()
  options <- restaurant_lag_options[[loc]]
  lag_options <- if (!is.null(options)) {options} else {default_lag_options}
  intervention_date <- before_after_details_true %>% 
    filter(location_id == loc) %>%
    pull(cross_over_date)
  
  for (outcome in outcomes) {
    results_list[[loc]][[outcome]] <- list()
    
    for (data_type in data_types) {
      results_list[[loc]][[outcome]][[data_type]] <- list()

      for (lag_combo in names(lag_options[[outcome]][[data_type]])) {
        
        model_path <- file.path(
          "modeling_results/grid_search",
          paste0(loc, "_", data_type, "_", outcome, "_model.rds"))
        diag_path <- file.path(
          "modeling_results/grid_search",
          paste0(loc, "_", data_type, "_", outcome, "_diagplot.png"))
        pred_path <- file.path(
          "modeling_results/grid_search",
          paste0(loc, "_", data_type, "_", outcome, "_predplot.png"))
        
        if (file.exists(model_path) && file.exists(diag_path) && file.exists(pred_path)) {
          res <- list(
            model = readRDS(model_path),
            diag_plot = grid::rasterGrob(readPNG(diag_path), interpolate = TRUE),
            pred_plot = grid::rasterGrob(readPNG(pred_path), interpolate = TRUE))
          
          cat("Retrieved | Restaurant:", loc, "Outcome:", outcome,
              "| Data:", data_type, "| Lags:", lag_combo, "\n")}
        
        else {
          cat("Processing | Restaurant:", loc, "Outcome:", outcome,
              "| Data:", data_type, "| Lags:", lag_combo, "\n")
          
          data_to_use <- if (data_type == "entire") {df_all_daily} else {df_all_intervention_period}
          ar_lags <- lag_options[[outcome]][[data_type]][[lag_combo]][['ar']]
          mean_lags <- lag_options[[outcome]][[data_type]][[lag_combo]][['mean']]
          
          res <- process_models(
            data_to_use,
            loc = loc,
            outcome = outcome,
            predictors = predictors,
            date = intervention_date,
            ar_lags = ar_lags,
            mean_lags = mean_lags,
            model_type = "nbar",
            sample = FALSE,
            standardize = TRUE,
            train_frac = 0.7)}
        
        results_list[[loc]][[outcome]][[data_type]][[lag_combo]] <- res
        
        # Save results if needed
        save <- TRUE
        if (save) {
          
          saveRDS(res$model, file = model_path)
          
          png(diag_path, width = 2400, height = 1600, res = 300)
          grid.draw(res$diag_plot)
          dev.off()
          
          png(pred_path, width = 2400, height = 1600, res = 300)
          grid.draw(res$pred_plot)
          dev.off()}
        
      }
    }
  }
}



# ===============================
#           Run Server
# ===============================

# ===== Shiny App UI and Server =====

ui <- fluidPage(
  titlePanel("Restaurant Sales Model Dashboard"),
  sidebarLayout(
    sidebarPanel(
      
      # Restaurant selection
      selectInput("restaurant_id", "Choose a restaurant:",
                  choices = restaurants_by_coverage,
                  selected = restaurants_by_coverage[1]),
      
      # Outcome selection
      selectInput("outcome", "Choose outcome:",
                  choices = outcomes,
                  selected = outcomes[1]),
      
      # Data type selection
      selectInput("data_type", "Choose data period:",
                  choices = data_types,
                  selected = data_types[1]),
      
      # Lag combination selection
      uiOutput("lag_combo_ui")
    ),
    mainPanel(
      h3(textOutput("restaurant_info")),
      plotOutput("selected_plot")
    )
  )
)

server <- function(input, output, session) {
  
  # Get available lag combinations based on selected outcome and data type
  available_lag_combos <- reactive({
    if (!is.null(restaurant_lag_options[[input$restaurant_id]])) {
      names(restaurant_lag_options
            [[input$restaurant_id]]
            [[input$outcome]]
            [[input$data_type]])}
    else {
      names(default_lag_options
            [[input$outcome]]
            [[input$data_type]])}})
  
  # Render UI for lag combination selection
  output$lag_combo_ui <- renderUI({
    selectInput("lag_combo", "Choose lag combination:",
                choices = available_lag_combos(),
                selected = available_lag_combos()[1])
  })
  
  # Display restaurant information
  output$restaurant_info <- renderText({
    
    if (!is.null(restaurant_lag_options[[input$restaurant_id]])) {
      lag_options <- restaurant_lag_options[[input$restaurant_id]][[input$outcome]][[input$data_type]]
    } else {
      lag_options <- default_lag_options[[input$outcome]][[input$data_type]]
    }
    
    cv_value <- lag_options[[input$lag_combo]][["cv"]]
    
    paste("Restaurant:", input$restaurant_id,
          "\n| Outcome:", input$outcome,
          "\n| Data:", input$data_type,
          "\n| Lags:", input$lag_combo,
          "\n| CV:", cv_value)
  })
  
  # Display the selected plot
  output$selected_plot <- renderPlot({
    selected_plot <- (results_list
                      [[input$restaurant_id]]
                      [[input$outcome]]
                      [[input$data_type]]
                      [[input$lag_combo]]
                      [['pred_plot']])
    grid::grid.draw(selected_plot)
  }, height = 600)
}

shinyApp(ui = ui, server = server)

