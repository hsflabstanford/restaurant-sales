# Load packages
library(tidyverse)
library(arrow)
library(conflicted)
conflict_prefer("select", "dplyr")
conflict_prefer("filter", "dplyr")
source("tools/modeling_functions.R")

# ===============================
#          Weather Data Processing
# ===============================

# -------------------------------
# --- Section 1: Toronto Data ---
# -------------------------------
cat("Processing Toronto (Location 1 and 13) data...\n")
# Assuming you have location ID SRQS8F7JWA9MZ and CB2KHY1C2G9PT for Toronto (added as a copy when binding rows).
# This block processes SRQS8F7JWA9MZ based on the old structure.
# If  needs different processing, it needs its own block.
loc1_weather_data <- 2019:2023 %>% # Example years, adjust if needed
  map_dfr(~ {
    # Construct file path based on the old pattern for this specific ID
    file_path <- file.path("data", "weather_data", paste0("weather_data_31688_", .x, ".csv"))
    # Check if file exists before attempting to read
    if (file.exists(file_path)) {
      read.csv(file_path, fileEncoding = "UTF-8", stringsAsFactors = FALSE) %>%
        # Ensure dplyr::select is used if other packages might mask 'select'
        dplyr::select(Year, Month, Day, Mean.Temp...C., Total.Precip..mm.) %>%
        transmute(
          temp = Mean.Temp...C.,
          precip = Total.Precip..mm.,
          created_at = as.Date(paste(Year, Month, Day, sep = "-"), format = "%Y-%m-%d"),
          location_id = "SRQS8F7JWA9MZ" # Hardcoded ID for this specific source
        ) %>%
        # Handle potential NAs before filling if needed
        # group_by(location_id) %>%
        # fill(temp, precip, .direction = "down") %>% # Forward fill
        # ungroup() %>%
        identity() # Keep the data frame structure
    } else {
      # Return an empty tibble/df with the correct structure if file is missing
      cat("Warning: File not found -", file_path, "\n")
      tibble(temp = numeric(), precip = numeric(), created_at = as.Date(character()), location_id = character())
    }
  }) %>%
  # Apply fill after combining all years for this location if needed
  group_by(location_id) %>%
  fill(temp, precip, .direction = "down") %>% # Forward fill NAs
  ungroup()

# Add processing for the *other* Toronto ID (CB2KHY1C2G9PT) if it exists
# and has a different source/format. If it uses the *new* NOAA format,
# it should be included in the `noaa_files_to_ids` map below instead.

# ---------------------------------
# --- Section 2: New NOAA Data ----
# (Replaces old Locations 2-19 processing)
# ---------------------------------
cat("Processing NOAA Station data...\n")

# --- Mapping: New NOAA Filenames to Original Location IDs ---
# Excludes Toronto IDs (SRQS8F7JWA9MZ, CB2KHY1C2G9PT) and Newcomb (LFZFT3VASXPED)
# as they are handled separately.
noaa_files_to_ids <- list(
  "data/weather_data/leavenworth_wa.csv" = "2HRX9P6HKXA8V",
  "data/weather_data/cape_girardeau_mo.csv" = "JHDN7CF1C03X5",
  "data/weather_data/ashburn_va.csv" = "L69HYJ4Y3TR91",
  "data/weather_data/beaverton_or.csv" = "ED5J990H5VAZT",
  "data/weather_data/erie_pa.csv" = "W8T41JZK0ZMEP",
  "data/weather_data/pittsburgh_pa.csv" = "EMBVNVD207CC6",
  "data/weather_data/cleveland_oh.csv" = "C0BE4NDSW26QN",
  "data/weather_data/honolulu_hi.csv" = "75WYSXR9QBK5M",
  "data/weather_data/arbutus_md.csv" = "V3Q26BHF3SE2H",
  "data/weather_data/brentwood_ca.csv" = "LBZEEFSBJNB3Z",
  "data/weather_data/los_angeles_ca.csv" = "SAFK7ND1HR6XS",
  "data/weather_data/miami_fl.csv" = "S8MT0YGD2KTN9",
  "data/weather_data/denver_co.csv" = "1SQPTEGYPH0GA",
  "data/weather_data/atlanta_ga.csv" = "9XKJD8DQTH559",
  "data/weather_data/greensboro_nc.csv" = "LQ5EH4BKGV61T",
  "data/weather_data/washington_dc.csv" = "78AY09MVJVTYE"
)

# --- Processing Function for NOAA Data ---
process_noaa_file <- function(file_path, loc_id) {
  cat(" Reading:", file_path, "for ID:", loc_id, "\n")
  if (!file.exists(file_path)) {
    cat("  Warning: File not found -", file_path, "\n")
    # Return empty tibble with correct structure
    return(tibble(temp = numeric(), precip = numeric(), created_at = as.Date(character()), location_id = character()))
  }
  tryCatch({
    read.csv(file_path, stringsAsFactors = FALSE) %>%
      # Ensure essential columns exist from the API download
      # The API script should have downloaded 'date', 'datatype', 'value'
      dplyr::select(date, datatype, value) %>%
      # Pivot to wide format: one row per date, columns for TMAX, TMIN, PRCP
      pivot_wider(names_from = datatype, values_from = value) %>%
      # Ensure required columns exist after pivoting (handle cases where a datatype might be missing for a day)
      # Add missing columns with NA if they don't exist after pivot
      { if (!"TMAX" %in% names(.)) .$TMAX <- NA_real_ else . } %>%
      { if (!"TMIN" %in% names(.)) .$TMIN <- NA_real_ else . } %>%
      { if (!"PRCP" %in% names(.)) .$PRCP <- NA_real_ else . } %>%
      # Select the pivoted columns needed for calculation/output
      dplyr::select(date, TMAX, TMIN, PRCP) %>%
      # Remove rows where essential TMAX/TMIN/PRCP are NA *before* calculating temp
      # Keep rows if only PRCP is NA, but remove if TMAX or TMIN is NA for temp calculation
      drop_na(TMAX, TMIN) %>% # Keep rows even if PRCP is NA at this stage
      # Calculate avg temp, rename cols, convert date, add ID
      transmute(
        # Temp calculation requires TMAX and TMIN (units should be metric from API call)
        temp = (TMAX + TMIN) / 2,
        # Precipitation (units should be metric from API call - mm)
        precip = PRCP,
        created_at = as.Date(date), # Assumes 'date' column is 'YYYY-MM-DD'
        location_id = loc_id      # Assign the ID from the map
      ) %>%
      # Final check: remove rows where final temp or precip is NA
      # This handles NAs in PRCP or if temp calculation resulted in NA
      drop_na(temp, precip) %>%
      identity()
  }, error = function(e) {
    cat("  Error processing file:", file_path, "-", e$message, "\n")
    # Return empty tibble on error
    return(tibble(temp = numeric(), precip = numeric(), created_at = as.Date(character()), location_id = character()))
  })
}

# --- Apply processing to all NOAA files ---
noaa_weather_data <- map2_dfr(
  names(noaa_files_to_ids),  # Pass file paths
  noaa_files_to_ids,         # Pass corresponding IDs
  process_noaa_file          # Apply the function
)

# --------------------------------
# --- Section 3: Newcomb Data ----
# --------------------------------
cat("Processing Newcomb (Location 20) data...\n")

# Define file path and location ID for Newcomb
newcomb_file <- file.path("data", "weather_data", "newcomb.csv") # Use file.path for robustness
newcomb_id <- "LFZFT3VASXPED"

# Process Newcomb weather data (assuming Open-Meteo format)
if (file.exists(newcomb_file)) {
  newcomb_weather_data <- read.csv(newcomb_file, stringsAsFactors = FALSE) %>%
    # Select the columns we need to avoid issues if extra columns exist
    dplyr::select(Date, Temp_Max_C, Temp_Min_C, Precipitation_mm) %>%
    # Calculate average temp, rename precip, convert date, add ID
    transmute(
      temp = (Temp_Max_C + Temp_Min_C) / 2,
      precip = Precipitation_mm,
      created_at = as.Date(Date), # Assumes 'Date' column is 'YYYY-MM-DD'
      location_id = newcomb_id
    ) %>%
    # Remove rows where final temp or precip is NA
    drop_na(temp, precip) %>%
    identity() # Consistent style
} else {
  cat("Warning: Newcomb file not found -", newcomb_file, "\n")
  newcomb_weather_data <- tibble(temp = numeric(), precip = numeric(), created_at = as.Date(character()), location_id = character())
}


# ===============================
#          Combine Data
# ===============================

print("Combining all processed weather datasets...")

# Combine the three datasets
# Ensure all contributing data frames exist, even if empty with the right structure
all_weather_data <- bind_rows(
  loc1_weather_data,      # Toronto (Old Format)
  noaa_weather_data,      # Locations processed from new NOAA files
  newcomb_weather_data,    # Newcomb (Open-Meteo Format)
  loc1_weather_data %>% mutate(location_id = "CB2KHY1C2G9PT")
)

# ===============================
#          Verification
# ===============================
print("Combined data summary:")
print(summary(all_weather_data))
print("Dimensions of combined data:")
print(dim(all_weather_data))
print("Unique location IDs in final combined data:")
# Use `pull` to get the vector of IDs for unique()
print(unique(pull(all_weather_data, location_id)))
print("Tail of combined data:")
print(tail(all_weather_data))

cat("Weather data processing complete.\n")

# ===============================
#          Fixing Large Gaps
# ===============================

# --- Define Parameters ---
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
  filter(location_id == target_id,
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
  # Arrange for consistency
  arrange(location_id, created_at)

cat("Total rows after combining:", nrow(all_weather_data_new), "\n")
# Final sanity check: should be close to original_rows if date ranges matched well
if(nrow(all_weather_data_new) != original_rows) {
  cat("Warning: Final row count differs from original. Review logic if difference is large.\n")
}

# --- 5. Verification (Optional but recommended) ---
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
  filter(location_id == noaa_files_to_ids[[17]]) %>%
  ggplot(aes(x = created_at, y = temp, color = location_id)) +
  geom_line() +
  labs(title = "Temperature Over Time by Location",
       x = "Date",
       y = "Temperature (°C)") +
  theme_minimal() +
  theme(legend.position = "bottom") +
  scale_x_date(date_labels = "%Y-%m", date_breaks = "1 month")

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
  dplyr::select(year, month, Value) %>%
  identity()

# Set up a reference year
base_year <- 2018
base_month <- 1
cpi_base <- cpi_food_away %>% 
  filter(year == base_year & month == base_month) %>% 
  pull(Value) %>%
  identity()

# ====== Join and Write =========

df_all_daily %>% glimpse()

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

