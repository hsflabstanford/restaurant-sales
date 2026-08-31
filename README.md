# Introducing Plant Based Analogs to Restaurants

Using restaurant sales data from Palate to determine if introducing plant-based
analogs reduces consumption of animal-based foods.

---

# Reproducing

## Setup

- Install [Miniconda](https://docs.conda.io/en/latest/miniconda.html) and R 4.4.2.
- Clone the repo and `cd` into it.
- Create and activate the Python environment:
  - Linux / macOS: `conda env create -f env/environment_linux.yml` then `conda activate palate1`
  - Windows: `conda env create -f env\environment_windows.yml` then `conda activate base`
- Install the project package: `pip install -e .`
- Linux / macOS only, install the notebook stack: `pip install pickleshare ipytest ipykernel nbconvert nbformat jupyter_client`
- Set up R, from the repo root, in `R`:
  - `renv::activate()`
  - `renv::restore()`
- Check it worked:
  - `python -c "import pandas, pyarrow, foodcast; print(pandas.__version__, pyarrow.__version__)"` → `2.1.3 14.0.1`
  - `Rscript -e 'packageVersion("arrow")'` → `18.1.0.1`

## Run

Top to bottom. Sources entering from the side are shown on the right.

```
  0_data_excel/                          raw vendor exports
        |  1_preprocessing.ipynb
        v
  1_data_parquet/  ......................  1.1_encoding_errors.ipynb
        |  2_cleaning.ipynb                  writes 1.1_data_excel_redone/,
        v  <--------------------------.      read back by 2_cleaning
  2_data_parquet_cleaned/  .............  3.1_data_coverage.ipynb
        |                                    writes before_after_details_true.csv
        |  labeling_1/loc*.ipynb   <-------  remapping/*.yaml
        |  labeling_2/loc*.ipynb   <-------  hand-built vegan/vegetarian/meat lists
        v
  1_rule_relabeled/ -> 2_consolidated/
        |  4.1_joining_customers.ipynb
        v
  3_combined_no_prelabeled_drinks/
        |
     ===|=== AI labeling — committed as source, NOT re-run ===
        v
  4_ai_labeled/
        |  4_modeling_prep.ipynb
        v
  5_only_food/ -> 6_only_dinein/ -> 7_truly_consolidated/   (+ dish_counts/)
        |  4.0_modeling_prep_2.ipynb  <----  dish_labels/     (manual, Tier 1)
        v                                    dish_labels_t2/  (AI, Tier 2)
  4_data_parquet_modeling/aggregated/
        |  5_add_weather_inflation_holidays.R
        |        ^
        |        `--------------------------  5_format_weather_and_inflation_data.R
        v                                       (weather_data/ + inflation.csv)
  external_variables/finalized*  ------------>  analysis repo
```

Run every `loc*.ipynb` in `labeling_1/`, then every one in `labeling_2/`.

## Check

- `git status --porcelain -- data/`
- Clean means you reproduced it.
- If files show as modified, see "Comparing output" below before assuming
  anything changed.

---

# Notes

## What is not re-run

- **AI labels** — `4_ai_labeled/`, `dish_labels_t2/`, `ai_grouping/` come from an
  LLM and are committed as source.
- **Model fits** — posterior draws are committed so plots and tables regenerate
  without refitting.

## Environment

- Versions are pinned because they change results. `pandas 2.2` changes 13
  columns of output with no error; `pandas 3.x` corrupts count columns.
- `environment_linux.yml` pins only the analysis libraries, which is why the
  notebook stack is a separate install. `environment_windows.yml` is a full
  Anaconda export and already has it.
- R must be 4.4.2. On earlier R, `MASS` in the lockfile requires >= 4.4.0 and
  nothing installs after it.
- Run `renv::restore()` with the project active — plain `R` or `Rscript` from the
  repo root, never `Rscript --vanilla`. Under `--vanilla` the `.Rprofile` is
  skipped, renv compares against your system library, and reports "already
  synchronized" over an empty project library.

## Running the notebooks

- The working directory must be the repo root. `1_preprocessing` does not
  `chdir` for itself.
- Headless: `jupyter nbconvert --to notebook --execute --output-dir /tmp/out <notebook>`,
  or `nbclient` with `resources={"metadata": {"path": "<repo root>"}}`.

## Comparing output

- Parquet is not byte-stable. Row order within equal keys varies between runs.
- Compare values, not bytes: sort by `location_id` and `date`, then compare
  column by column.
- `__index_level_0__` is a parquet index artifact, not a variable. Ignore it.

## Known issues

- `%store` caches persist in `~/.ipython` across sessions and can be stale. If a
  notebook fails on a key that looks wrong, delete
  `~/.ipython/profile_default/db/autorestore`.
- `loc8`, `loc9` and several Tier-2 labeling notebooks fail in diagnostic cells
  that run after their data writes. Their output is correct.
- `3.1_data_coverage` uses a `before_after_details` that no cell assigns.

## Status

Verified end to end: 21 of 21 output files reproduce, 0 real columns differ.

Full pipeline detail is in the analysis repo's `publication/PIPELINE.md`.
