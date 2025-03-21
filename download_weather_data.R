# Load packages
library(httr)
library(readr)
library(jsonlite)
library(tidyverse)

# Define parameters
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
      # Convert to DataFrame
      weather_data <- as.data.frame(data$results)
      
      # Save to CSV
      write.csv(weather_data, paste0(city, ".csv"), row.names = FALSE)
    }
  }
}

print("Data retrieval complete.")



ar_lag_sets_1 <- list(
  #c(),
  c(1),
  c(1,2),
  #c(1,2,3),
  #c(1,2,3,4,5,6,7),
  c(1,2,3,4,5,6,7,14,28),
  c(1,2,3,4,5,6,7,14,21,28,42),
  c(1,2,3,4,5,6,7,14,21,28,42,56),
  c(1,3,5,7),
  #c(1,7),
  c(1,7,14,28),
  c(1,7,28,56),
  c(1,7,14,21,28,42,56),
  c(7),
  c(7,28),
  c(7,14,21),
  c(7,28,56),
  c(7,14,21,28),
  c(14,28),
  c(28,56)
)

mean_lag_sets_1 <- list(
  #c(),
  c(1),
  #c(1,2),
  #c(1,2,3),
  #c(1,2,3,4,5,6,7),
  #c(1,2,3,4,5,6,7,14,28),
  #c(1,2,3,4,5,6,7,14,21,28,42),
  c(1,2,3,4,5,6,7,14,21,28,42,56),
  #c(1,3,5,7),
  #c(1,7),
  c(1,7,14,28),
  c(1,7,28,56),
  #c(1,7,14,21,28,42,56),
  c(7),
  #c(7,28),
  c(7,14,21),
  c(7,28,56),
  c(7,14,21,28),
  c(14,28),
  c(28,56)
)

length(ar_lag_sets_1)
length(mean_lag_sets_1)

fit_and_select_forward <- function(df, loc_id, outcome,
                                           # initial candidate pools for each class:
                                           initial_AR   = c(1, 2, 7, 28),
                                           initial_Mean = c(1, 7, 14, 28),
                                           # predetermined (full) sequences for updates:
                                           full_AR   = c(1, 2, 3, 7, 28),
                                           full_Mean = c(1, 7, 14, 21, 28, 35)) {
  # Initialize the selected lags (empty at start)
  selected_AR   <- c()
  selected_Mean <- c()
  
  # Build the unified candidate pool as a list of candidates (each with type and lag)
  candidates <- list()
  for(lag in initial_AR) {
    candidates[[length(candidates) + 1]] <- list(type = "AR", lag = lag)
  }
  for(lag in initial_Mean) {
    candidates[[length(candidates) + 1]] <- list(type = "Mean", lag = lag)
  }
  
  best_error <- Inf
  improvement <- TRUE
  
  while(0 < length(candidates) && improvement) {
    improvement <- FALSE
    # Evaluate each candidate by adding it to the current model and computing CV error.
    candidate_errors <- sapply(candidates, function(candidate) {
      if(candidate$type == "AR") {
        new_AR   <- sort(unique(c(selected_AR, candidate$lag)))
        new_Mean <- selected_Mean
      } else {
        new_AR   <- selected_AR
        new_Mean <- sort(unique(c(selected_Mean, candidate$lag)))
      }
      # fit_and_cv_INGARCH is assumed to return the CV error for a given INGARCH model
      error_val <- fit_and_cv_INGARCH(df, loc_id, outcome, new_AR, new_Mean)
      return(error_val)
    })
    
    # Find the candidate (AR or Mean) with the minimum error
    best_candidate_idx   <- which.min(candidate_errors)
    best_candidate_error <- candidate_errors[best_candidate_idx]
    
    if(best_candidate_error < best_error) {
      improvement <- TRUE
      best_error <- best_candidate_error
      chosen_candidate <- candidates[[best_candidate_idx]]
      
      # Update the selected set based on the candidate type.
      if(chosen_candidate$type == "AR") {
        selected_AR <- sort(unique(c(selected_AR, chosen_candidate$lag)))
      } else {
        selected_Mean <- sort(unique(c(selected_Mean, chosen_candidate$lag)))
      }
      
      # Remove the chosen candidate from the unified candidate pool.
      candidates <- candidates[-best_candidate_idx]
      
      # Now update the candidate pool on the chosen side by adding the next available lag.
      if(chosen_candidate$type == "AR") {
        next_candidate <- NA
        # Look in full_AR for the smallest lag greater than the chosen one that isn’t already selected or in the pool.
        for(lag in full_AR[full_AR > chosen_candidate$lag]) {
          ar_candidates <- sapply(candidates, function(cand) {
            if(cand$type == "AR") cand$lag else NA
          })
          ar_candidates <- ar_candidates[!is.na(ar_candidates)]
          if(!(lag %in% selected_AR) && !(lag %in% ar_candidates)) {
            next_candidate <- lag
            break
          }
        }
        if(!is.na(next_candidate)) {
          candidates[[length(candidates) + 1]] <- list(type = "AR", lag = next_candidate)
        }
      } else if(chosen_candidate$type == "Mean") {
        next_candidate <- NA
        for(lag in full_Mean[full_Mean > chosen_candidate$lag]) {
          mean_candidates <- sapply(candidates, function(cand) {
            if(cand$type == "Mean") cand$lag else NA
          })
          mean_candidates <- mean_candidates[!is.na(mean_candidates)]
          if(!(lag %in% selected_Mean) && !(lag %in% mean_candidates)) {
            next_candidate <- lag
            break
          }
        }
        if(!is.na(next_candidate)) {
          candidates[[length(candidates) + 1]] <- list(type = "Mean", lag = next_candidate)
        }
      }
      
      message("Added ", chosen_candidate$type, " lag: ", chosen_candidate$lag,
              ". Selected AR: ", paste(selected_AR, collapse = ", "),
              " | Selected Mean: ", paste(selected_Mean, collapse = ", "))
      message("Current candidate pool:")
      for (cand in candidates) {
        message(cand$type, ": ", cand$lag)
      }
    } else {
      message("No candidate improved the CV error. Stopping selection.")
      improvement <- FALSE
    }
  }
  
  message("Final selected lags: AR: ", paste(selected_AR, collapse = ", "),
          "; Mean: ", paste(selected_Mean, collapse = ", "))
  return(list(cv_error = best_error, AR = selected_AR, Mean = selected_Mean))
}


