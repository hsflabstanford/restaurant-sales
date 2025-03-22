# Load packages
library(tidyverse)
library(arrow)
source("tools/modeling_functions")

# ===============================
#          Weather Data
# ===============================

# ====== Location 1 =========

# Process all weather files
loc1_weather_data <- 2019:2023 %>%
  map_dfr(~ { # tilda is an anonymous function, .x is its argument
    file_path <- paste0("data/weather_data/weather_data_31688_", .x, ".csv")
    read.csv(file_path, fileEncoding = "UTF-8") %>%
      select(Year, Month, Day, Mean.Temp...C., Total.Precip..mm.) %>%
      transmute(
        temp = Mean.Temp...C.,
        precip = Total.Precip..mm.,
        created_at = as.Date(paste(Year, Month, Day, sep = "-")),
        location_id = "SRQS8F7JWA9MZ" # location 1 id
      ) %>%
      group_by(location_id) %>%
      fill(temp, precip, .direction = "down") %>%  # forward fill
      ungroup() %>%
      identity()
  })

# ====== Locations 2-6 =========

# Define file paths and corresponding location IDs
weather_files <- list(
  "data/weather_data/3958615.csv" = "2HRX9P6HKXA8V",
  "data/weather_data/3958622.csv" = "JHDN7CF1C03X5",
  "data/weather_data/3958625.csv" = "L69HYJ4Y3TR91",
  "data/weather_data/3958626.csv" = "ED5J990H5VAZT",
  "data/weather_data/3958627.csv" = "W8T41JZK0ZMEP"
)

# T for trace amounts needs to be removed
clean_weather <- function(col) {
  col %>%
    str_remove("[Ts]+$") %>%
    if_else(. == "", NA, .) %>%
    as.numeric()
}

# Rename daily averages to temp and precip
weather_set <- map_dfr(names(weather_files), ~ read.csv(.x) %>% # tilda is an anonymous function, .x is its argument
                         distinct(DATE, DailyAverageDryBulbTemperature, DailyPrecipitation) %>%
                         transmute(
                           temp = DailyAverageDryBulbTemperature %>% clean_weather(), # apply cleaning method
                           precip = DailyAverageDryBulbTemperature %>% clean_weather(),
                           created_at = as.Date(DATE),
                           location_id = weather_files[[.x]]) %>% # index list at file name to get location id
                         drop_na())

# ====== Locations 7-19, excluding some =========

# Secondary files were retrieved with API, so the formatting is different
weather_files_2 <- list(
  "data/weather_data/pittsburgh.csv" = "EMBVNVD207CC6",
  "data/weather_data/cleveland.csv" = "C0BE4NDSW26QN",
  #"data/weather_data/arbutus.csv" = "V3Q26BHF3SE2H",
  "data/weather_data/brentwood.csv" = "LBZEEFSBJNB3Z",
  "data/weather_data/los_angeles.csv" = "SAFK7ND1HR6XS",
  "data/weather_data/miami.csv" = "S8MT0YGD2KTN9",
  #"data/weather_data/newcomb.csv" = "LFZFT3VASXPED",
  "data/weather_data/denver.csv" = "1SQPTEGYPH0GA",
  "data/weather_data/atlanta.csv" = "9XKJD8DQTH559",
  "data/weather_data/greensboro.csv" = "LQ5EH4BKGV61T",
  "data/weather_data/washington_dc.csv" = "78AY09MVJVTYE"
)

# Again rename daily averages to temp and precip, taking average from min and max
weather_set_2 <- map_dfr(names(weather_files_2), ~ read.csv(.x) %>% # tilda is an anonymous function, .x is its argument
                           pivot_wider(names_from = datatype, values_from = value) %>%
                           select(date, TMAX, TMIN, PRCP) %>%
                           drop_na() %>%
                           transmute(
                             temp = (TMAX + TMIN) / 2,
                             precip = PRCP,
                             created_at = as.Date(date),
                             location_id = weather_files_2[[.x]]))


# Combine

all_weather_data <- bind_rows(loc1_weather_data, weather_set, weather_set_2)



# ===============================
#          Inflation Data
# ===============================

# ====== Read and Format =========

# Process inflation data
cpi_food_away <- read.csv("data/inflation.csv") %>%
  filter(Period != "S01" & Period != "S02") %>% # remove half year stats
  mutate(
    month = as.numeric(sub("M", "", Period)),  
    date = as.Date(paste(Year, month, "01", sep = "-")),
    year = year(date),
    month = month(date)
  ) %>% 
  select(year, month, Value) %>%
  identity()

# Set up a reference year
base_year <- 2018
base_month <- 1
cpi_base <- cpi_food_away %>% 
  filter(year == base_year & month == base_month) %>% 
  pull(Value) %>%
  identity()

# ====== Join and Write =========

# Join inflation and weather data with main data
df_all_daily <- read_parquet("data/3_palate_data_parquet_modeling/all_locations_daily.parquet") %>%
  process_predictors() %>% # apply custom processing function
  left_join(cpi_food_away, by = c("year", "month")) %>%
  mutate(
    vegan_price_real = vegan_window_avg / (Value / cpi_base), # inflation-adjusted
    meat_price_real = meat_window_avg / (Value / cpi_base),
    inflation = Value
  ) %>% 
  { print(dim(.)); . } %>%
  left_join(all_weather_data, by = c("location_id", "created_at")) %>%
  { print(dim(.)); . } %>% # check that merge was done correctly
  group_by(location_id) %>%
  fill(temp, precip, .direction = "downup") %>%  # forward fill
  ungroup() %>%
  identity()

write_parquet(df_all_daily, "data/3_palate_data_parquet_modeling/all_locations_daily_weather_inflation.parquet")

