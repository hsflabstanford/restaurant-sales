library(tidyverse)

bad_restaurants <- c('AQD04SM0J92WA','LBMCPAYT7W36V','L3XS7WSJ4AJA3','1G5AJ17XCH2A8','3AXDVZJYN9DRS','MS8R16DY0JQAM','N0PC58FB2XAZ3','ADPFRN3QZRCXK','WJA3YCD4QBWRX','0RJH3FFPYBPEY','LZ5MR1TS37E7W')

restaurants_by_coverage <- read.csv('data/2_palate_data_parquet_cleaned/restaurants_by_4m_coverage.csv') %>%
  filter(!(location_id %in% bad_restaurants)) %>%
  filter(!(location_id %in% c("75WYSXR9QBK5M",
                              "V3Q26BHF3SE2H",
                              "CB2KHY1C2G9PT",
                              "LFZFT3VASXPED",
                              "LQ5EH4BKGV61T"))) %>%
  pull(location_id)

data_types <- c("entire", "intervention")

outcomes <- c("nonvegan_outcome", "vegan_outcome")

combos <- expand_grid(restaurants_by_coverage, data_types, outcomes)

list_of_models <- combos %>% pmap(~ readRDS(paste0("modeling_results/grid_search/", ..1, "_", ..2, "_", ..3, "_model.rds")))

model_df <- combos %>%
  rename(location_id = restaurants_by_coverage,
         data_type = data_types,
         outcome = outcomes) %>%
  mutate(model = list_of_models)

restaurants_by_coverage

model <- model_df %>% 
  filter(location_id == "LBZEEFSBJNB3Z") %>%
  filter(data_type == "entire") %>%
  filter(outcome == "nonvegan_outcome") %>%
  pull(model) %>%
  pluck(1) %>%
  identity()

model %>% 
  coef() %>%
  round(3) %>%
  enframe(name = "coef", value = "estimate") %>%
  arrange(estimate %>% desc) %>%
  print(n=34)
