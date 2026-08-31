# Anonymisation

Restaurants are identified only by a 13-character code. Dish names are kept
deliberately — they carry the signal the analysis is about.

## What was removed

| | |
|---|---|
| trading name | one restaurant was identified by name in filenames, code, item text and inside parquet values. Replaced throughout current files and history with `VLZX7K2M9QD4T`. |
| location | `city`, `state`, `zip_code` and 25 `neighborhood_*` demographic columns dropped from `locations.csv`, so they no longer propagate into the modelling data. |

The location columns mattered more than the name. City plus zip plus
`cuisine` plus `restaurant_type` identifies a venue immediately, and all 28
columns were being merged wholesale into
`4_data_parquet_modeling/**` and shipped downstream.

## Why removing them changes no result

They were never modelled:

- `model_scripts/ingarch_scripts/1_data_ingarch.R` and
  `ingarch_scripts_customer_gaussian_iid/1_data_gaussian_iid.R` both do
  `select(-contains("neighborhood"))`.
- Numeric predictors are chosen by `where(is.numeric & n_distinct > 12)` minus
  exposure and outcome columns. `city`, `state` and `restaurant_type` are
  character, and `zip_code` is stored as a string, so none can enter.
- `aggregate_customer_data.R` carries them only through `first()`, and its
  column list is an `intersect()`, so it tolerates their absence.

## What is kept, and why

`cuisine` and `restaurant_type` stay. They are already published in the
descriptive tables as anonymised phrases — "Greek rotisserie chain", "German
sausage grill" — so removing them from the data would not conceal anything the
paper does not already state.

Dish names stay. `item_name` is the unit of analysis; the labels, the
alt-protein categories and the counts are all built from it.

## What still identifies, and the limit of this

A determined reader with the dish names, the cuisine and the introduction dates
could plausibly identify a venue. This is de-identification, not anonymity: the
direct identifiers and the geography are gone, the behavioural detail the study
is about is not.
