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

source("modeling_functions.R")


## ===== Data, Predictors, Outcome =====

df_all_daily <- read_parquet("data/3_palate_data_parquet_modeling/all_locations_daily.parquet") %>%
  standardize_data()

glimpse(df_all_daily)

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

outcome <- "vegan_outcome"


## ===== Define AR Lag Options =====

ar_lags_options <- list(
  "0"           = c(),
  #"1"           = c(1),
  #"1,2"         = c(1,2),
  "1,2,3"       = c(1,2,3),
  #"1,7"         = c(1,7),
  #"1,7,14"      = c(1,7,14),
  #"1,2,7"       = c(1,2,7),
  "1,2,3,7,14"  = c(1,2,3,7,14),
  "1,2,3,7,14,21"  = c(1,2,3,7,14,21)
)

mean_lags_options <- list(
  "0"           = c()
)


## ===== Loop Over All Locations and Store Visuals =====

# 19 location IDs
location_ids <- c(
  'SRQS8F7JWA9MZ',
  '2HRX9P6HKXA8V',
  'JHDN7CF1C03X5',
  'L69HYJ4Y3TR91',
  'ED5J990H5VAZT',
  'W8T41JZK0ZMEP',
  'EMBVNVD207CC6',
  'C0BE4NDSW26QN',
  '75WYSXR9QBK5M',
  'V3Q26BHF3SE2H',
  'LBZEEFSBJNB3Z',
  'SAFK7ND1HR6XS',
  'CB2KHY1C2G9PT',
  'S8MT0YGD2KTN9',
  'LFZFT3VASXPED',
  '1SQPTEGYPH0GA',
  '9XKJD8DQTH559',
  'LQ5EH4BKGV61T',
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
                          outcome = outcome,
                          predictors = predictors,
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


## ===== Shiny App UI and Server =====

# (The UI remains unchanged.)
ui <- fluidPage(
  titlePanel("Dashboard: Select a Restaurant Location"),
  sidebarLayout(
    sidebarPanel(
      selectInput("restaurant_id", "Choose a restaurant ID:", 
                  choices = names(plot_list), selected = names(plot_list)[1]),
      selectInput("ar_lags", "Choose AR lag set:", 
                  choices = names(ar_lags_options), selected = names(ar_lags_options)[1])
    ),
    mainPanel(
      h3(textOutput("restaurant_id")),
      plotOutput("selected_plot")
    )
  )
)

# In the server we now call grid.draw() on the stored grob
server <- function(input, output, session) {
  
  output$display_info <- renderText({
    paste("Restaurant Location ID:", input$restaurant_id,
          "| AR lag set:", input$ar_lags)
  })
  
  # output$restaurant_id <- renderText({
  #   paste("Restaurant Location ID:", input$restaurant_id)
  # })
  
  output$selected_plot <- renderPlot({
    # Retrieve the appropriate plot based on user selection.
    selected_plot <- plot_list[[ input$restaurant_id ]][[ input$ar_lags ]]
    
    # Optionally add a header or other annotations here.
    grid::grid.draw(selected_plot)
  })
}


## ===== Launch the Shiny App =====

shinyApp(ui = ui, server = server)
