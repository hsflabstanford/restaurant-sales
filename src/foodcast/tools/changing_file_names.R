# # Set the folder path
# folder <- "D:/My Stuff/HSFL/restaurant-sales-testing/modeling_results/grid_search"

# # First part: Insert nonvegan_outcome before last underscore
# insert_str <- "nonvegan_outcome"
# all_entries <- list.files(folder, full.names = TRUE)
# files <- all_entries[file.info(all_entries)$isdir == FALSE]
# base_names <- basename(files)

# new_base_names <- sub(
#   "^(.+)_([^_]+)$",
#   paste0("\\1_", insert_str, "_\\2"),
#   base_names)
# new_files <- file.path(folder, new_base_names)
# file.rename(files, new_files)

# # Second part: Remove nonvegan_outcome that was just inserted
# all_entries <- list.files(folder, full.names = TRUE)
# files <- all_entries[file.info(all_entries)$isdir == FALSE]
# base_names <- basename(files)

# original_base_names <- sub(
#   paste0("_", insert_str, "_([^_]+)$"),  # Match the pattern we added
#   "_\\1",  # Replace with just the last segment
#   base_names)
# original_files <- file.path(folder, original_base_names)
# file.rename(files, original_files)