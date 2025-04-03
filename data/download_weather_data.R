# Load packages

library(readr)
library(jsonlite)
library(tidyverse)
library(httr)

# ===============================
#      Weather Data from API
# ===============================

# ====== Location SRQS8F7JWA9MZ ========= 

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


# ====== Location LFZFT3VASXPED =========  

# --- Parameters for the API Request ---
latitude <- -38.16       # Approximate latitude for Newcomb, VIC
longitude <- 144.39      # Approximate longitude for Newcomb, VIC
start_date <- "2013-01-01" # Start date (inclusive)
end_date <- "2023-12-31"   # End date (inclusive)
daily_vars <- "temperature_2m_max,temperature_2m_min,precipitation_sum" # Desired variables
timezone <- "Australia/Melbourne" # Timezone for daily aggregation
csv_filename <- "data/weather_data/newcomb.csv" # Name for the output CSV file

# --- Construct the API URL ---
api_base_url <- "https://archive-api.open-meteo.com/v1/archive"
api_url <- paste0(api_base_url,
                  "?latitude=", latitude,
                  "&longitude=", longitude,
                  "&start_date=", start_date,
                  "&end_date=", end_date,
                  "&daily=", daily_vars,
                  "&timezone=", timezone)

# --- Make the API Request and Process Response ---
print("Requesting data from Open-Meteo...")
print(paste("URL:", api_url))

tryCatch({
  # Make the GET request using httr
  response <- GET(api_url)
  
  # Check for HTTP errors
  stop_for_status(response)
  
  # Get the raw text content of the response
  json_text <- content(response, as = "text", encoding = "UTF-8") #<<< Get raw text
  
  # Explicitly parse the JSON text using jsonlite
  weather_data_list <- jsonlite::fromJSON(json_text, simplifyVector = TRUE) #<<< Use fromJSON
  
  # --- Structure the Data ---
  if (!is.null(weather_data_list$daily) && length(weather_data_list$daily) > 0) {
    
    # --- DIAGNOSTICS: Inspect the structure BEFORE trying to make a data frame ---
    print("--- Structure of the 'daily' element after fromJSON: ---") # <<< Add diagnostic
    str(weather_data_list$daily)                                      # <<< Add diagnostic str()
    # --- End Diagnostics ---
    
    # Check if all expected elements exist
    expected_elements <- c("time", strsplit(daily_vars, ",")[[1]])
    elements_present <- names(weather_data_list$daily)
    all_elements_exist <- all(expected_elements %in% elements_present)
    
    if (!all_elements_exist) {
      missing_elements <- setdiff(expected_elements, elements_present)
      stop(paste("API response's 'daily' list is missing expected data fields:", paste(missing_elements, collapse=", ")))
    }
    
    # Check lengths are consistent
    list_lengths <- sapply(weather_data_list$daily, length)
    if (length(unique(list_lengths)) != 1) {
      print("Warning: Elements within the 'daily' list have different lengths!")
      print(list_lengths)
      stop("Inconsistent lengths in daily data prevent data frame creation.")
    }
    num_days <- unique(list_lengths) # Get the number of days/rows expected
    
    
    # --- Explicitly Construct the Data Frame --- 
    print("Attempting to explicitly construct data frame...")
    tryCatch({
      weather_df <- data.frame(
        Date = as.Date(weather_data_list$daily$time),
        Temp_Max_C = weather_data_list$daily$temperature_2m_max,
        Temp_Min_C = weather_data_list$daily$temperature_2m_min,
        Precipitation_mm = weather_data_list$daily$precipitation_sum
        # Add other variables here if you requested more, matching the names from daily_vars
      )
      print("Successfully constructed data frame.")
      
      # --- Verification and CSV Writing (moved inside this tryCatch) ---
      if (nrow(weather_df) == num_days && ncol(weather_df) == length(expected_elements)) {
        print("Data frame dimensions seem correct.")
        print("First few rows of the weather data frame:")
        print(head(weather_df))
        print("Last few rows of the weather data frame:")
        print(tail(weather_df))
        print(paste("Dimensions of the data frame:", paste(dim(weather_df), collapse = " x ")))
        
        # --- Write Data Frame to CSV File ---
        print(paste("Writing data frame to:", csv_filename))
        tryCatch({
          write.csv(weather_df, file = csv_filename, row.names = FALSE, quote = TRUE)
          print("Successfully wrote data to CSV.")
        }, error = function(e_csv) {
          print(paste("Error writing CSV file:", e_csv$message))
        })
        # --- End of CSV Writing ---
        
      } else {
        print("Error: Constructed data frame has unexpected dimensions.")
        print(paste("Expected dimensions:", num_days, "x", length(expected_elements)))
        print(paste("Actual dimensions:", paste(dim(weather_df), collapse = " x ")))
      }
      
    }, error = function(e_df){
      print(paste("Error during explicit data frame construction:", e_df$message))
      # Show the structure again if construction failed
      print("--- Structure of 'daily' element when construction failed: ---")
      str(weather_data_list$daily)
    })
    # --- End of Explicit Construction ---
    
  } else {
    print("Error: 'daily' data block not found, is NULL, or is empty in the API response.")
    print("--- Structure of parsed API response (weather_data_list): ---")
    str(weather_data_list) # Show structure if daily is missing/empty
  }
  
}, error = function(e) {
  # Handle errors
  print(paste("An error occurred:", e$message))
  if (exists("response")) {
    print(paste("HTTP Status Code:", status_code(response)))
    # print(content(response, as = "text", encoding = "UTF-8")) # Uncomment for deep debug
  }
})




# ======  All Other Locations ========= 

api_token <- readLines("weather_token.txt", n = 1)
dataset_id <- "GHCND"
datatype_ids <- c("TMAX", "TMIN", "PRCP")
start_date <- as.Date("2013-01-01")
end_date <- as.Date("2024-01-01") # Inclusive end date for API calls
limit <- 1000
max_attempts <- 5
retry_delay_sec <- 5
inter_request_delay_sec <- 0.2

# --- API Setup ---
base_url <- "https://www.ncei.noaa.gov/cdo-web/api/v2/data"
req_headers <- add_headers(token = api_token)

# --- New Station Mapping ---
# Maps the desired output filename to the NOAA GHCND Station ID
stations_map <- list(
  "leavenworth_wa.csv" = "GHCND:USC00454659",
  "cape_girardeau_mo.csv" = "GHCND:USW00003935",
  "ashburn_va.csv" = "GHCND:USW00093738",
  "beaverton_or.csv" = "GHCND:USW00024229",
  "erie_pa.csv" = "GHCND:USW00014860",
  "pittsburgh_pa.csv" = "GHCND:USW00094823",
  "cleveland_oh.csv" = "GHCND:USW00014820",
  "honolulu_hi.csv" = "GHCND:USW00022521",
  "arbutus_md.csv" = "GHCND:USW00093721",
  "brentwood_ca.csv" = "GHCND:USW00023174",
  "los_angeles_ca.csv" = "GHCND:USW00023174",
  "miami_fl.csv" = "GHCND:USW00012839",
  "denver_co.csv" = "GHCND:USW00003017",
  "atlanta_ga.csv" = "GHCND:USW00013874",
  "greensboro_nc.csv" = "GHCND:USW00013722",
  "washington_dc.csv" = "GHCND:USW00013743"
)

# --- Date Sequence ---
date_sequence <- unique(c(seq(from = start_date, to = end_date, by = "year"), end_date + 1))

# --- Main Loop: Iterate over the station map ---
# Use the names of the list (filenames) to iterate
for (target_filename in names(stations_map)) {
  station_id <- stations_map[[target_filename]] # Get the station ID using the filename key
  
  cat("===================================================\n")
  cat("Processing Station:", station_id, " (for file:", target_filename, ")\n")
  cat("===================================================\n")
  
  all_station_chunks_list <- list()
  
  # --- Chunk Loop ---
  for (i in 1:(length(date_sequence) - 1)) {
    chunk_start <- date_sequence[i]
    chunk_end <- min(date_sequence[i + 1] - 1, end_date)
    if (chunk_start > chunk_end) next
    
    chunk_start_str <- format(chunk_start, "%Y-%m-%d")
    chunk_end_str <- format(chunk_end, "%Y-%m-%d")
    cat("\n--- Processing Chunk: ", chunk_start_str, "to", chunk_end_str, "---\n")
    
    current_offset <- 1
    total_records_in_chunk <- 1 # Initialize to trigger loop entry
    chunk_pages_list <- list()
    
    # --- Pagination Loop ---
    while (current_offset <= total_records_in_chunk) {
      query_params <- list(
        datasetid = dataset_id,
        datatypeid = paste(datatype_ids, collapse = ","),
        stationid = station_id, # *** Use stationid instead of locationid ***
        startdate = chunk_start_str,
        enddate = chunk_end_str,
        limit = limit,
        offset = current_offset,
        units = "metric"
      )
      
      attempt <- 1
      success <- FALSE
      page_data_df <- NULL
      
      # --- Retry Loop ---
      while (attempt <= max_attempts && !success) {
        tryCatch({
          response <- GET(url = base_url, req_headers, query = query_params)
          status <- status_code(response)
          cat("  Offset:", current_offset, "| Attempt:", attempt, "| Status:", status, "\n")
          
          if (status == 200) {
            response_text <- content(response, as = "text", encoding = "UTF-8")
            parsed_data <- fromJSON(response_text, simplifyDataFrame = TRUE)
            
            # Update total count if this is the first successful call for the chunk
            if (total_records_in_chunk == 1 && !is.null(parsed_data$metadata$resultset$count)) {
              total_records_in_chunk <- as.numeric(parsed_data$metadata$resultset$count)
              cat("  Offset:", current_offset, "| Total records reported for chunk:", total_records_in_chunk, "\n")
              if (total_records_in_chunk == 0) {
                cat("  Offset:", current_offset, "| Info: Total records for chunk is 0. Stopping pagination.\n")
                current_offset <- total_records_in_chunk + 1
                success <- TRUE
                break # Exit retry loop
              }
            } else if (total_records_in_chunk == 1 && is.null(parsed_data$metadata$resultset$count)) {
              total_records_in_chunk <- current_offset + limit - 1
              cat("  Offset:", current_offset, "| Warning: Could not determine total record count. Proceeding page by page.\n")
            }
            
            # Extract Results - Check for > 0 rows
            if (!is.null(parsed_data$results) && is.data.frame(parsed_data$results) && nrow(parsed_data$results) > 0) {
              page_data_df <- parsed_data$results
              cat("  Offset:", current_offset, "| Retrieved", nrow(page_data_df), "valid data rows for this page.\n")
            } else {
              page_data_df <- NULL
              cat("  Offset:", current_offset, "| Info: No data rows returned in 'results' for this page.\n")
            }
            success <- TRUE
            
          } else if (status == 503) {
            cat("  Offset:", current_offset, "| 503 Service Unavailable. Retrying in", retry_delay_sec, "seconds...\n")
            attempt <- attempt + 1
            Sys.sleep(retry_delay_sec)
          } else {
            cat("  Offset:", current_offset, "| Error: Received HTTP status", status, ". Stopping retries for this page.\n")
            error_content <- content(response, as = "text", encoding = "UTF-8")
            cat("  Error Details:", substr(error_content, 1, 500), "...\n")
            success <- FALSE
            break
          }
        }, error = function(e) {
          cat("  Offset:", current_offset, "| Error during GET request on attempt", attempt, ":", e$message, "\n")
          attempt <- attempt + 1
          if (attempt <= max_attempts) Sys.sleep(retry_delay_sec)
        }) # End tryCatch
      } # End Retry Loop
      
      # Add page data if successful and has rows
      if (success && !is.null(page_data_df)) {
        chunk_pages_list[[length(chunk_pages_list) + 1]] <- page_data_df
      } else if (!success) {
        cat("  Offset:", current_offset, "| Failed to retrieve data for this page after", max_attempts, "attempts. Breaking pagination for chunk.\n")
        break # Exit pagination loop for this chunk if a page fails hard
      }
      
      # Increment offset or exit loop based on total count
      if (success && total_records_in_chunk > 0) {
        current_offset <- current_offset + limit
      } else if (!success) {
        break # Ensure exit if retry loop failed
      }
      # Loop condition (current_offset <= total_records_in_chunk) handles the rest
      
      # Only sleep if we are going to make another request
      if (current_offset <= total_records_in_chunk) {
        Sys.sleep(inter_request_delay_sec)
      }
      
    } # End Pagination Loop
    
    # Combine pages for the current chunk
    if (length(chunk_pages_list) > 0) {
      complete_chunk_data <- bind_rows(chunk_pages_list)
      if (nrow(complete_chunk_data) > 0) {
        all_station_chunks_list[[length(all_station_chunks_list) + 1]] <- complete_chunk_data
        cat("--- Chunk", chunk_start_str, "to", chunk_end_str, "completed. Added", nrow(complete_chunk_data), "records to station total. ---\n")
      } else {
        cat("--- Chunk", chunk_start_str, "to", chunk_end_str, "completed, but bind_rows resulted in 0 rows. ---\n")
      }
    } else {
      cat("--- Chunk", chunk_start_str, "to", chunk_end_str, "yielded no data rows across all pages. ---\n")
    }
  } # End Chunk Loop
  
  # --- Combine all chunks for the station and write file ---
  if (length(all_station_chunks_list) > 0) {
    final_station_data <- bind_rows(all_station_chunks_list)
    
    if (nrow(final_station_data) > 0) {
      cat("\nTotal records with data retrieved for station", station_id, ":", nrow(final_station_data), "\n")
      # Output file path uses the key from the stations_map directly
      file_path <- file.path("data", "weather_data", target_filename)
      dir.create(dirname(file_path), showWarnings = FALSE, recursive = TRUE)
      tryCatch({
        write.csv(final_station_data, file_path, row.names = FALSE)
        cat("Data for station", station_id, "successfully saved to", file_path, "\n\n")
      }, error = function(e) {
        cat("Error writing CSV file for station", station_id, "to", file_path, ":", e$message, "\n\n")
      })
    } else {
      cat("\nWarning: Combined data for station", station_id, "has 0 rows after binding chunks. No CSV file written.\n\n")
    }
  } else {
    cat("\nWarning: No data chunks with rows were successfully retrieved for station:", station_id, ". No CSV file written.\n\n")
  }
  
} # End Station Loop

cat("===================================================\n")
cat("          Data retrieval script complete.\n")
cat("===================================================\n")