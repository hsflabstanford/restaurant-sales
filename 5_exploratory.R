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
# library(sandwich)
# library(lmtest)
library(MASS)
library(bayesforecast)

df_all_daily <- read_parquet("data/3_palate_data_parquet_modeling/all_locations_daily.parquet") %>%
  process_predictors() %>%
  mutate(
    month = month(created_at),
    year  = year(created_at)
  )

cpi_food_away <- read.csv("data/inflation.csv") %>%
  filter(Period != "S01" & Period != "S02") %>%
  mutate(
    month = as.numeric(sub("M", "", Period)),  
    date = as.Date(paste(Year, month, "01", sep = "-")),
    year = year(date),
    month = month(date)
  ) %>% dplyr::select(year, month, Value)
 
df_ts <- df_all_daily %>%
  mutate(date_interval = date(created_at)) %>%
  as_tsibble(key = location_id, index = date_interval) %>%
  dplyr::select(date_interval, vegan_outcome)

# Define your base period
base_cpi_year <- 2018
base_cpi_month <- 1

# Extract the base CPI value from your inflation data
base_cpi <- cpi_food_away %>%
  filter(year == base_cpi_year, month == base_cpi_month) %>%
  pull(Value) %>%
  first()

# Adjust prices for inflation: convert nominal prices to real (base-period) dollars
df_all_daily <- df_all_daily %>%
  left_join(cpi_food_away, by = c("year", "month")) %>%
  mutate(
    # Use the ratio: (base CPI / current CPI)
    cpi_factor = base_cpi / Value,
    vegan_price_real = vegan_window_avg * cpi_factor,
    meat_price_real = meat_window_avg * cpi_factor
  )


## ===== Moving Average Analysis =====

df_ts %>%
  filter(location_id == 'SRQS8F7JWA9MZ') %>%
  mutate(
    `7-MA` = slider::slide_dbl(vegan_outcome, 
                                mean,
                                .before = 3, 
                                .after = 3, 
                                .complete = TRUE),
    `21-MA` = slider::slide_dbl(vegan_outcome, 
                                mean,
                                .before = 10, 
                                .after = 10, 
                                .complete = TRUE),
    `35-MA` = slider::slide_dbl(vegan_outcome, 
                                mean,
                                .before = 17, 
                                .after = 17, 
                                .complete = TRUE)
  ) %>%
  autoplot(vegan_outcome) +
  geom_line(aes(y = `7-MA`), colour = "#F5AE00", size=1, alpha=.7) +
  geom_line(aes(y = `21-MA`), colour = "#15FE00", size=1, alpha=.7) +
  geom_line(aes(y = `35-MA`), colour = "#F50E00", size=1, alpha=.7) +
  labs(y = "Vegan Count",
       title = "Moving Average")


## ===== STL Decomposition =====

df_ts %>%
  filter(location_id == 'SRQS8F7JWA9MZ') %>%
  fabletools::model(
    STL(vegan_outcome ~ trend(window = 30) + season(window = "periodic"), robust = TRUE)) %>%
  components() %>%
  autoplot()


## ===== Collinearity Analysis =====

view_prices <- function(loc_id, agg=TRUE) {

  if (agg) {
    df_all_daily <- df_all_daily %>%
      filter(location_id == loc_id) %>%
      mutate(week_start = floor_date(created_at, "week")) %>%
      group_by(week_start) %>%
      summarise(
        vegan_window_avg = mean(vegan_window_avg, na.rm = TRUE),
        vegan_price_real = mean(vegan_price_real, na.rm = TRUE),
        meat_window_avg = mean(meat_window_avg, na.rm = TRUE),
        meat_price_real = mean(meat_price_real, na.rm = TRUE)
      ) %>%
      pivot_longer(
        cols = c(vegan_window_avg, vegan_price_real, meat_window_avg, meat_price_real),
        names_to = "price_type",
        values_to = "price"
      )
  }
  else {
    df_all_daily <- df_all_daily %>%
      filter(location_id == loc_id) %>%
      mutate(week_start = floor_date(created_at, "day")) %>%
      group_by(week_start) %>%
      summarise(
        vegan_window_avg = mean(vegan_window_avg, na.rm = TRUE),
        vegan_price_real = mean(vegan_price_real, na.rm = TRUE),
        meat_window_avg = mean(meat_window_avg, na.rm = TRUE),
        meat_price_real = mean(meat_price_real, na.rm = TRUE)
      ) %>%
      pivot_longer(
        cols = c(vegan_window_avg, vegan_price_real, meat_window_avg, meat_price_real),
        names_to = "price_type",
        values_to = "price"
      )
  }
  
  ggplot(df_all_daily, aes(x = week_start, y = price, color = price_type)) +
    geom_line(size = 0.5, alpha = 0.7) +
    scale_color_manual(
      values = c(
        "vegan_window_avg"  = "green", 
        "vegan_price_real"  = "lightgreen", 
        "meat_window_avg"   = "red", 
        "meat_price_real"   = "pink"
      ),
      labels = c(
        "vegan_window_avg" = "Vegan Window Avg",
        "vegan_price_real" = "Vegan Price Real",
        "meat_window_avg"  = "Meat Window Avg",
        "meat_price_real"  = "Meat Price Real"
      )
    ) +
    labs(
      x = "Date",
      y = "Real Price",
      color = "Price Type",
      title = "Real Price of Vegan/Meat Items Over Time (Weekly)"
    ) +
    theme_minimal()

}

view_prices("SRQS8F7JWA9MZ", FALSE)
cor(df_all_daily %>% filter(location_id == "SRQS8F7JWA9MZ") %>% dplyr::select(vegan_window_avg,
                                                                              vegan_price_real,
                                                                              meat_window_avg,
                                                                              meat_price_real,
                                                                              date))
view_prices("2HRX9P6HKXA8V")
cor(df_all_daily %>% filter(location_id == "2HRX9P6HKXA8V") %>% dplyr::select(vegan_window_avg,
                                                                              vegan_price_real,
                                                                              meat_window_avg,
                                                                              meat_price_real,
                                                                              date))
view_prices("JHDN7CF1C03X5")
cor(df_all_daily %>% filter(location_id == "JHDN7CF1C03X5") %>% dplyr::select(vegan_window_avg,
                                                                              vegan_price_real,
                                                                              meat_window_avg,
                                                                              meat_price_real,
                                                                              date))
view_prices('78AY09MVJVTYE')
cor(df_all_daily %>% filter(location_id == '78AY09MVJVTYE') %>% dplyr::select(vegan_window_avg,
                                                                              vegan_price_real,
                                                                              meat_window_avg,
                                                                              meat_price_real,
                                                                              date))



