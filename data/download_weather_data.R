# Load packages
library(httr)
library(readr)
library(jsonlite)
library(tidyverse)

# ===============================
#      Weather Data from API
# ===============================

# ====== Location 1 =========

# Define parameters for Toronto
station_id <- 31688
timeframe <- 2
for (year in 2019:2023) {
  
  url <- paste0("https://climate.weather.gc.ca/climate_data/bulk_data_e.html?",
                "format=csv&stationID=", station_id,
                "&Year=", year, 
                "&timeframe=", timeframe,
                "&submit=Download+Data")
  response <- GET(url)
  
  if (status_code(response) == 200) {
    weather_data <- read_csv(content(response, "text", encoding = "UTF-8"), show_col_types = FALSE)
    file_name <- paste0("data/weather_data/weather_data_", station_id, "_", year, ".csv")
    # write_csv(weather_data, file_name)
    print(paste("Downloaded:", file_name))} 
  else {
    print(paste("Failed for", year, "- Status Code:", status_code(response)))
  }
  
  # Pause to avoid overloading the server
  Sys.sleep(2)
}


# ====== Locations 7-19, excluding some =========

# Note: locations 2-6 were retrieved manually

# View retrievable datasets
base_url <- "https://www.ncei.noaa.gov/cdo-web/api/v2/datasets"

query_params <- list(
  datasetid = "GHCND",
  datatypeid = paste(datatype_ids, collapse = ","),
  locationid = location_id,
  startdate = start_date,
  enddate = end_date,
  limit = limit
)

response <- GET(url = base_url,
                add_headers(token = api_token),
                query = query_params)

# Establish url for data
base_url <- "https://www.ncei.noaa.gov/cdo-web/api/v2/data"

# List of cities and their corresponding location IDs
cities <- list(
  "pittsburgh" = "CITY:US420030",
  "cleveland" = "CITY:US390035",
  "brentwood" = "CITY:US470104",
  "los_angeles" = "CITY:US060037",
  "miami" = "CITY:US120086",
  "denver" = "CITY:US080046",
  "atlanta" = "CITY:US130012",
  "greensboro" = "CITY:US370100",
  "washington_dc" = "CITY:US110001"
)

# Parameters
datatype_ids <- c("TMAX", "TMIN")
start_date <- "2023-01-01"
end_date <- "2023-01-31"
limit <- 1000

# Fetch data for each city
for (city in names(cities)) {
  location_id <- cities[[city]]
  
  query_params <- list(
    datasetid = "GHCND",
    datatypeid = paste(datatype_ids, collapse = ","),
    locationid = location_id,
    startdate = start_date,
    enddate = end_date,
    limit = limit
  )
  response <- GET(url = base_url,
                  add_headers(token = api_token),
                  query = query_params)
  
  if (status_code(response) == 200) {
    data <- fromJSON(content(response, as = "text", encoding = "UTF-8"))
    if ("results" %in% names(data)) {
      # Convert to dataframe
      weather_data <- as.data.frame(data$results)
      # Save to CSV
      write.csv(weather_data, paste0(city, ".csv"), row.names = FALSE)
    }
  }
}

print("Data retrieval complete.")