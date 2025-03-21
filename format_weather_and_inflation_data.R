# Load packages
library(tidyverse)

# Process all weather files sequentially using pipes
loc1_weather_data <- 2019:2023 %>%
  map_dfr(~ {
    file_path <- paste0("data/weather_data/weather_data_31688_", .x, ".csv")
    read.csv(file_path, fileEncoding = "UTF-8") %>%
      select(Year, Month, Day, Mean.Temp...C., Total.Precip..mm.) %>%
      transmute(
        temp = Mean.Temp...C.,
        precip = Total.Precip..mm.,
        created_at = as.Date(paste(Year, Month, Day, sep = "-")),
        location_id = "SRQS8F7JWA9MZ"
      ) %>%
      group_by(location_id) %>%
      fill(temp, precip, .direction = "down") %>%  # Forward fill
      ungroup() %>%
      identity()
  })


# Define file paths and corresponding location IDs
weather_files <- list(
  "data/weather_data/3958615.csv" = "2HRX9P6HKXA8V",
  "data/weather_data/3958622.csv" = "JHDN7CF1C03X5",
  "data/weather_data/3958625.csv" = "L69HYJ4Y3TR91",
  "data/weather_data/3958626.csv" = "ED5J990H5VAZT",
  "data/weather_data/3958627.csv" = "W8T41JZK0ZMEP"
)
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


clean_weather <- function(col) {
  col %>%
    str_remove("[Ts]+$") %>%
    if_else(. == "", NA, .) %>%
    as.numeric()
}

weather_set <- map_dfr(names(weather_files), ~ read.csv(.x) %>%
                         distinct(DATE, DailyAverageDryBulbTemperature, DailyPrecipitation) %>%
                         transmute(
                           temp = DailyAverageDryBulbTemperature %>% clean_weather(),
                           precip = DailyAverageDryBulbTemperature %>% clean_weather(),
                           created_at = as.Date(DATE),
                           location_id = weather_files[[.x]]) %>%
                         drop_na())

weather_set_2 <- map_dfr(names(weather_files_2), ~ read.csv(.x) %>%
                           pivot_wider(names_from = datatype, values_from = value) %>%
                           select(date, TMAX, TMIN, PRCP) %>%
                           drop_na() %>%
                           transmute(
                             temp = (TMAX + TMIN) / 2,
                             precip = PRCP,
                             created_at = as.Date(date),
                             location_id = weather_files_2[[.x]]))

all_weather_data <- bind_rows(loc1_weather_data, weather_set, weather_set_2)