# Load packages
library(tidyverse)
library(arrow)
library(conflicted)
conflict_prefer("select", "dplyr")
conflict_prefer("filter", "dplyr")
source("src/foodcast/tools/modeling_functions.R")
library(timeDate)
library(slider)

# ─────────────────────────────────────────────────────────────
#          Weather Data
# ─────────────────────────────────────────────────────────────

all_weather_data <- read_csv(file.path('data','weather_data','finalized_weather_data','weather_data.csv'))

# ─────────────────────────────────────────────────────────────
#          Inflation Data
# ─────────────────────────────────────────────────────────────

# --- Read and Format ---

# Process inflation data
cpi_food_away <- read.csv("data/inflation_data/inflation.csv") %>%
  filter(Period != "S01" & Period != "S02") %>% # remove half year stats
  mutate(
    month = as.numeric(sub("M", "", Period)),  
    date = as.Date(paste(Year, month, "01", sep = "-")),
    year = year(date),
    month = month(date)
  ) %>% 
  dplyr::select(year, month, Value) %>%
  identity()

# --- Calculate ---

# Set up a reference year
base_year <- 2018
base_month <- 1
cpi_base <- cpi_food_away %>% 
  filter(year == base_year & month == base_month) %>% 
  pull(Value) %>%
  identity()


# ─────────────────────────────────────────────────────────────
#          Holidays, Join, and Export
# ─────────────────────────────────────────────────────────────

direc1 <- "data/4_data_parquet_modeling/"

direc2_all <- sub("\\.parquet$", "", list.files(paste0(direc1,'aggregated'), pattern="\\.parquet$", recursive=TRUE))
for (direc2 in direc2_all[!grepl("transactions", direc2_all)]){
  directory <- paste0(direc1, 'aggregated/', direc2, ".parquet")

  # Join inflation and weather data with main data
  df_all_daily <- read_parquet(directory) %>%
    process_predictors() %>% # apply custom processing function
    mutate(
      new_years = as.integer(month == 12 & day_of_month == 31),
      valentines = as.integer(month == 2 & day_of_month == 14),
      easter = as.integer(date == as.Date(Easter(year))),
      cinco = as.integer(month == 5 & day_of_month == 5),
      july_fourth = as.integer(month == 7 & day_of_month == 4),
      thanksgiving = as.integer(date == as.Date(USThanksgivingDay(year))),
      christmas = as.integer(month == 12 & day_of_month == 25),
      mlk = as.integer(date == as.Date(USMLKingsBirthday(year))),
      pres = as.integer(date == as.Date(USPresidentsDay(year))),
      mem = as.integer(date == as.Date(USMemorialDay(year))),
      labor = as.integer(date == as.Date(USLaborDay(year))),
      columbus = as.integer(date == as.Date(USColumbusDay(year))),
      vet = as.integer(date == as.Date(USVeteransDay(year)))
    ) %>%
    group_by(location_id) %>%
    mutate(is_any_holiday = (christmas + 
                            thanksgiving +
                            #cinco +
                            july_fourth #+ 
                            #new_years + 
                            #easter + 
                              #valentines +
                              #mlk +
                              #pres +
                              #mem +
                              #labor +
                              #columbus +
                              #vet
    ),
    holiday_window = slide_index_dbl(.x = is_any_holiday,
                                    .i = date,
                                    .f = ~ as.numeric(any(.x == 1)),
                                    .before = 3,
                                    .after = 3)) %>%
    ungroup() %>%
    left_join(cpi_food_away, by = c("year", "month")) %>%
    mutate(
      # Main prices
      vegan_price_real = vegan_window_avg_item_price / (Value / cpi_base), # inflation-adjusted
      vegetarian_price_real = vegetarian_window_avg_item_price / (Value / cpi_base),
      meat_price_real = meat_window_avg_item_price / (Value / cpi_base),
      
      # Proportion analysis prices
      breakfast_p_price_real = breakfast_p_window_avg_item_price / (Value / cpi_base),
      textured_p_price_real = textured_p_window_avg_item_price / (Value / cpi_base),
      untextured_p_price_real = untextured_p_window_avg_item_price / (Value / cpi_base),
      chicken_p_price_real = chicken_p_window_avg_item_price / (Value / cpi_base),
      dairy_p_price_real = dairy_p_window_avg_item_price / (Value / cpi_base),
      egg_p_price_real = egg_p_window_avg_item_price / (Value / cpi_base),

      # Targeted analysis prices
      breakfast_price_real = breakfast_window_avg_item_price / (Value / cpi_base),
      textured_price_real = textured_window_avg_item_price / (Value / cpi_base),
      untextured_price_real = untextured_window_avg_item_price / (Value / cpi_base),
      chicken_price_real = chicken_window_avg_item_price / (Value / cpi_base),
      dairy_price_real = dairy_window_avg_item_price / (Value / cpi_base),

      # T2 prices
      breakfast_t2_price_real = breakfast_t2_window_avg_item_price / (Value / cpi_base),
      textured_t2_price_real = textured_t2_window_avg_item_price / (Value / cpi_base),
      untextured_t2_price_real = untextured_t2_window_avg_item_price / (Value / cpi_base),
      chicken_t2_price_real = chicken_t2_window_avg_item_price / (Value / cpi_base),
      dairy_t2_price_real = dairy_t2_window_avg_item_price / (Value / cpi_base),
      inflation = Value) %>% 
    { print(dim(.)); . } %>%
    #mutate(created_at_date = as.Date(created_at)) %>%
    #left_join(all_weather_data, by = c("location_id", "created_at_date"="created_at")) %>%
    left_join(all_weather_data, by = c("location_id", "created_at")) %>%
    { print(dim(.)); . } %>% # check that merge was done correctly
    group_by(location_id) %>%
    fill(temp, precip, .direction = "downup") %>%  # forward fill
    ungroup() %>%
    identity()

  # Export
  write_parquet(df_all_daily, paste0(direc1, 'external_variables/', str_replace(direc2, 'all_locations_daily', 'finalized'), ".parquet"))
  #write_parquet(df_all_daily, paste0(direc1, 'external_variables/', str_replace(direc2, 'all_locations_transactions', 'finalized_transactions'), ".parquet"))
  ## Check columns with NAs
  # df_all_daily %>% summarise(across(everything(), ~ sum(is.na(.)))) %>% select(where(~ . > 0)) %>% t()

  ## Check size of data
  # df_all_daily %>% group_by(location_id) %>% summarize(count(.)) %>% print(n=31)

  # ─────────────────────────────────────────────────────────────
  #          Visualize
  # ─────────────────────────────────────────────────────────────

  df_all_daily %>%
    group_by(
      #year,
      month,
      day_of_month) %>%
    summarize(nonvegan_outcome=mean(nonvegan_outcome),holiday_window=mean(holiday_window)) %>%
    ggplot(aes(x=as.Date(ISOdate(2020,month,day_of_month)), 
              y=nonvegan_outcome,
              color=factor(holiday_window)
              )) + 
    geom_line() +
    theme_minimal() +
    #facet_wrap( ~ year, scales = "free_y") +
    aes(color = holiday_window) +
    scale_color_gradient(low = "gray", high = "red")

  df_all_daily %>%
    tsibble(index = date, 
            key = location_id
            ) %>%
    gg_season(nonvegan_outcome, period = "year") +
    aes(color = factor(holiday_window)) +
    labs(title = "Non-Vegan Outcomes Over Time",
        x = "Date",
        y = "Non-Vegan Outcomes") +
    theme_minimal() +
    scale_color_manual(values = c("0"="gray","1"="red")) +
    theme(legend.position = "bottom")


  # ─────────────────────────────────────────────────────────────
  #          Visualize Cropped Data
  # ─────────────────────────────────────────────────────────────

  plot_vegan <- function(loc_id, d1, d2){
    
    promo_datetime <- read.csv('data/3_data_parquet_relabeled/before_after_details_true.csv') %>% 
      filter(location_id == loc_id) %>% 
      pull(cross_over_date) %>%
      as.Date(format = "%Y-%m-%d") %>%
      floor_date(unit="week")
    df_all_daily %>% 
      filter(location_id != loc_id | d1 < date & date < d2) %>%
      filter(location_id == loc_id) %>% 
      group_by(week = date %>% floor_date(unit = "week")) %>%
      summarize(vegan_outcome = vegan_outcome %>% sum()) %>%
      ggplot(aes(x = week, y = vegan_outcome)) +
      geom_line() +
      geom_vline(xintercept = promo_datetime, linetype = "dashed", color = "red") +
      theme_minimal() +
      theme(legend.position = "bottom") +
      scale_x_date(date_labels = "%Y-%m", date_breaks = "6 month") %>%
      identity()
  }

  plot_nonvegan <- function(loc_id, d1, d2){
    
    promo_datetime <- read.csv('data/3_data_parquet_relabeled/before_after_details_true.csv') %>% 
      filter(location_id == loc_id) %>% 
      pull(cross_over_date) %>%
      as.Date(format = "%Y-%m-%d") %>%
      floor_date(unit="week")
    df_all_daily %>% 
      filter(location_id != loc_id | d1 < date & date < d2) %>%
      filter(location_id == loc_id) %>% 
      group_by(week = date %>% floor_date(unit = "week")) %>%
      summarize(nonvegan_outcome = nonvegan_outcome %>% sum()) %>%
      ggplot(aes(x = week, y = nonvegan_outcome)) +
      geom_line() +
      geom_vline(xintercept = promo_datetime, linetype = "dashed", color = "red") +
      theme_minimal() +
      theme(legend.position = "bottom") +
      scale_x_date(date_labels = "%Y-%m", date_breaks = "6 month") %>%
      identity()
  }

  loc_id <- "2HRX9P6HKXA8V"
  plot_vegan(loc_id, '2019-01-01', '2021-05-01')
  loc_id <- "JHDN7CF1C03X5"
  # plot_vegan(loc_id, '2019-04-01', '2023-06-01')
  plot_nonvegan(loc_id, '2019-04-01', '2023-06-01')
  loc_id <- "EMBVNVD207CC6"
  plot_vegan(loc_id, '2016-06-01', '2022-09-01')
  loc_id <- "LBZEEFSBJNB3Z"
  plot_nonvegan(loc_id, '2021-09-01', '2023-07-01')
  loc_id <- "CB2KHY1C2G9PT"
  plot_vegan(loc_id, '2020-06-01', '2023-04-01')
  plot_nonvegan(loc_id, '2020-06-01', '2023-04-01')
  loc_id <- "LFZFT3VASXPED"
  plot_vegan(loc_id, '2021-10-01', '2022-11-01')
  plot_nonvegan(loc_id, '2021-10-01', '2022-11-01')
  loc_id <- "75WYSXR9QBK5M"
  # plot_vegan(loc_id, '2019-01-01', '2023-06-01')
  plot_nonvegan(loc_id, '2022-05-01', '2023-07-01')


}

