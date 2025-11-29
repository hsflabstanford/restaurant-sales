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
#          Weather Data Processing
# ─────────────────────────────────────────────────────────────

# --- Section 1: Toronto Data ---

cat("Processing Toronto (Location 1 and 13) data...\n")

# Location ID is subbed in later script for location 13
process_toronto_file <- function(loc_id, year) {
    file_path <- file.path("data", "weather_data", paste0("weather_data_31688_", year, ".csv"))
    if (!file.exists(file_path)) {
      cat("  Warning: File not found -", file_path, "\n")
      return(tibble(temp = numeric(), 
                    precip = numeric(), 
                    created_at = as.Date(character()), 
                    location_id = character()))
    }
    read.csv(file_path, fileEncoding = "UTF-8", stringsAsFactors = FALSE) %>%
      dplyr::select(Year, Month, Day, Mean.Temp...C., Total.Precip..mm.) %>%
      transmute(
        temp = Mean.Temp...C.,
        precip = Total.Precip..mm.,
        created_at = as.Date(paste(Year, Month, Day, sep = "-"), format = "%Y-%m-%d"),
        location_id = loc_id
      ) %>%
      # # Handle potential NAs before filling if needed
      # group_by(location_id) %>%
      # fill(temp, precip, .direction = "down") %>% # Forward fill
      # ungroup() %>%
      identity()
}

params <- crossing(
  loc_id = c("SRQS8F7JWA9MZ"#, 
  #"CB2KHY1C2G9PT"
  ), # Location IDs for Toronto
  year = 2019:2023
)

toronto_weather_data <- pmap_dfr(
    params, 
    process_toronto_file
  ) %>% 
  # Apply fill after combining all years for this location if needed
  group_by(location_id) %>%
  fill(temp, precip, .direction = "down") %>% # Forward fill
  ungroup() %>%
  identity()


# --- Section 2: New National Oceanic and Atmospheric Administration (NOAA) Data ----

cat("Processing NOAA Station data...\n")

# Excludes Toronto IDs and Newcomb ID: loc1, loc13, loc 20 
# (SRQS8F7JWA9MZ, CB2KHY1C2G9PT, LFZFT3VASXPED)
noaa_files_to_ids <- list(
  "data/weather_data/san_francisco_ca.csv" = "VLZX7K2M9QD4T",
  "data/weather_data/leavenworth_wa.csv" = "2HRX9P6HKXA8V",
  "data/weather_data/cape_girardeau_mo.csv" = "JHDN7CF1C03X5",
  "data/weather_data/ashburn_va.csv" = "L69HYJ4Y3TR91",
  "data/weather_data/beaverton_or.csv" = "ED5J990H5VAZT",
  "data/weather_data/erie_pa.csv" = "W8T41JZK0ZMEP"#,
  # "data/weather_data/pittsburgh_pa.csv" = "EMBVNVD207CC6",
  # "data/weather_data/cleveland_oh.csv" = "C0BE4NDSW26QN",
  # "data/weather_data/honolulu_hi.csv" = "75WYSXR9QBK5M",
  # "data/weather_data/arbutus_md.csv" = "V3Q26BHF3SE2H",
  # "data/weather_data/brentwood_ca.csv" = "LBZEEFSBJNB3Z",
  # "data/weather_data/los_angeles_ca.csv" = "SAFK7ND1HR6XS",
  # "data/weather_data/miami_fl.csv" = "S8MT0YGD2KTN9",
  # "data/weather_data/denver_co.csv" = "1SQPTEGYPH0GA",
  # "data/weather_data/atlanta_ga.csv" = "9XKJD8DQTH559",
  # "data/weather_data/greensboro_nc.csv" = "LQ5EH4BKGV61T",
  # "data/weather_data/washington_dc.csv" = "78AY09MVJVTYE"
)

process_noaa_file <- function(file_path, loc_id) {
  cat(" Reading:", file_path, "for ID:", loc_id, "\n")
  if (!file.exists(file_path)) {
    cat("  Warning: File not found -", file_path, "\n")
    return(tibble(temp = numeric(), 
                  precip = numeric(), 
                  created_at = as.Date(character()), 
                  location_id = character()))
  }
  read.csv(file_path, stringsAsFactors = FALSE) %>%
    dplyr::select(date, datatype, value) %>%
    # Pivot to wide format: one row per date, columns for TMAX, TMIN, PRCP
    pivot_wider(names_from = datatype, values_from = value) %>%
    # Add missing columns with NA if they don't exist after pivot
    { if (!"TMAX" %in% names(.)) .$TMAX <- NA_real_ else . } %>%
    { if (!"TMIN" %in% names(.)) .$TMIN <- NA_real_ else . } %>%
    { if (!"PRCP" %in% names(.)) .$PRCP <- NA_real_ else . } %>%
    dplyr::select(date, TMAX, TMIN, PRCP) %>%
    drop_na(TMAX, TMIN) %>%
    # Calculate avg temp and rename cols
    transmute(
      temp = (TMAX + TMIN) / 2,
      precip = PRCP,
      created_at = as.Date(date), # Assumes 'date' column is 'YYYY-MM-DD'
      location_id = loc_id
    ) %>%
    drop_na(temp, precip) %>%
    identity()
}

noaa_weather_data <- map2_dfr(
  names(noaa_files_to_ids),  # Pass file paths
  noaa_files_to_ids,         # Pass corresponding IDs
  process_noaa_file          # Apply the function
)


# --- Section 3: Newcomb Data ----

cat("Processing Newcomb (Location 20) data...\n")

# Define file path and location ID for Newcomb
newcomb_file <- file.path("data", "weather_data", "newcomb.csv")
newcomb_id <- "LFZFT3VASXPED"
process_toronto_file
if (!file.exists(newcomb_file)) {
  cat("Warning: Newcomb file not found -", newcomb_file, "\n")
  newcomb_weather_data <- tibble(temp = numeric(), 
                                 precip = numeric(), 
                                 created_at = as.Date(character()), 
                                 location_id = character())
} else {
  newcomb_weather_data <- read.csv(newcomb_file, stringsAsFactors = FALSE) %>%
  dplyr::select(Date, Temp_Max_C, Temp_Min_C, Precipitation_mm) %>%
  transmute(
    temp = (Temp_Max_C + Temp_Min_C) / 2,
    precip = Precipitation_mm,
    created_at = as.Date(Date), # Assumes 'Date' column is 'YYYY-MM-DD'
    location_id = newcomb_id
  ) %>%
  drop_na(temp, precip) %>%
  identity()
}


# ===============================
#          Combine Data
# ===============================

print("Combining all processed weather datasets...")

all_weather_data <- bind_rows(
  toronto_weather_data,  
  noaa_weather_data#,      
  #newcomb_weather_data,
)


# ===============================
#          Verification
# ===============================

print("Combined data summary:")
print(summary(all_weather_data))
print("Dimensions of combined data:")
print(dim(all_weather_data))
print("Unique location IDs in final combined data:")
print(all_weather_data %>% pull(location_id) %>% unique())
print("Tail of combined data:")
print(tail(all_weather_data))

cat("Weather data processing complete.\n")


# ===============================
#          Fixing Large Gaps
# ===============================

target_id <- "1SQPTEGYPH0GA"
target_start_date <- as.Date("2013-04-02") # Inclusive start date based on > 2013-04-01
target_end_date <- as.Date("2014-01-30")   # Inclusive end date based on < 2014-01-31
source_start_date <- as.Date("2014-04-02") # Inclusive start date based on > 2014-04-01
source_end_date <- as.Date("2015-01-30")   # Inclusive end date based on < 2015-01-31

cat("Replacing data for location:", target_id, "\n")
cat(" Target date range:", format(target_start_date), "to", format(target_end_date), "\n")
cat(" Source date range:", format(source_start_date), "to", format(source_end_date), "\n")

# --- 1. Isolate the Source Data ---
# Get the data from the year after that will be used for replacement
source_data <- all_weather_data %>%
  dplyr::filter(location_id == target_id,
         created_at >= source_start_date,
         created_at <= source_end_date)

cat("Number of source data rows found:", nrow(source_data), "\n")

# --- 2. Shift Dates of Source Data Back by One Year ---
# Create the replacement data block with dates adjusted to match the target year
replacement_data <- source_data %>%
  mutate(
    # Subtract exactly one year using lubridate for accuracy (handles leap years)
    created_at = created_at %m-% years(1)
  ) %>%
  # Ensure we only keep essential columns to avoid conflicts
  dplyr::select(location_id, created_at, temp, precip)

cat("Number of replacement data rows prepared:", nrow(replacement_data), "\n")

# --- 3. Remove the Original Target Data ---
# Filter the main dataset to EXCLUDE the specific rows we are about to replace
all_weather_data_before_replacement <- all_weather_data %>%
  filter(!(location_id == target_id &
             created_at >= target_start_date &
             created_at <= target_end_date))

original_rows <- nrow(all_weather_data)
rows_before_replacement <- nrow(all_weather_data_before_replacement)
rows_removed <- original_rows - rows_before_replacement
cat("Number of original rows removed for", target_id, "in target range:", rows_removed, "\n")
# Simple sanity check: rows removed should ideally match rows in replacement_data
if(rows_removed != nrow(replacement_data)) {
  cat("Warning: Number of rows removed doesn't match number of replacement rows. Check date ranges.\n")
}

# --- 4. Combine the datasets ---
# Bind the data excluding the target range with the new replacement data
all_weather_data_new <- bind_rows(
  all_weather_data_before_replacement,
  replacement_data
) %>%
  arrange(location_id, created_at)

cat("Total rows after combining:", nrow(all_weather_data_new), "\n")
# Final sanity check: should be close to original_rows if date ranges matched well
if(nrow(all_weather_data_new) != original_rows) {
  cat("Warning: Final row count differs from original. Review logic if difference is large.\n")
}

# --- 5. Verification ---
# Check a few dates within the replaced range for the target ID
verification_data <- all_weather_data_new %>%
  filter(location_id == target_id,
         created_at >= target_start_date,
         created_at <= target_start_date + days(5)) # Check first few days

cat("\nVerification: First few rows of replaced data for", target_id, ":\n")
print(verification_data)
all_weather_data <- all_weather_data_new # Update the main weather data to the new version

all_weather_data %>% 
  group_by(location_id) %>%
  summarize(nonna_temp = sum(!is.na(temp)), # Count of non-NA temp values
            nonna_precip = sum(!is.na(precip)), # Count of non-NA precip values
            .groups = 'drop') %>%
  identity()

all_weather_data %>%
  filter(location_id == noaa_files_to_ids[[16]]) %>% # Replace number with different IDs
  ggplot(aes(x = created_at, y = temp, color = location_id)) +
  geom_line() +
  labs(title = "Temperature Over Time by Location",
       x = "Date",
       y = "Temperature (°C)") +
  theme_minimal() +
  theme(legend.position = "bottom") +
  scale_x_date(date_labels = "%Y-%m", date_breaks = "1 month")


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
#direc2 <- "customer/all_locations_daily_customers"
direc2 <- "all_locations_daily"
directory <- paste0(direc1, direc2, ".parquet")

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
    vegan_price_real = vegan_window_avg_item_price / (Value / cpi_base), # inflation-adjusted
    vegetarian_price_real = vegetarian_window_avg_item_price / (Value / cpi_base),
    meat_price_real = meat_window_avg_item_price / (Value / cpi_base),
    breakfast_price_real = breakfast_window_avg_item_price / (Value / cpi_base),
    textured_price_real = textured_window_avg_item_price / (Value / cpi_base),
    untextured_price_real = untextured_window_avg_item_price / (Value / cpi_base),
    inflation = Value
  ) %>% 
  { print(dim(.)); . } %>%
  left_join(all_weather_data, by = c("location_id", "created_at")) %>%
  { print(dim(.)); . } %>% # check that merge was done correctly
  group_by(location_id) %>%
  fill(temp, precip, .direction = "downup") %>%  # forward fill
  ungroup() %>%
  identity()

# Export
write_parquet(df_all_daily, paste0(direc1, direc2, "_weather_inflation.parquet"))

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

