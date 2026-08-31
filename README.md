# Introducing Plant Based Analogs to Restaurants

Using restaurant sales data from Palate to determine if introducing plant-based
analogs reduces consumption of animal-based foods.

---

## Reproducing the pipeline

This runs from the raw exports to `data/4_data_parquet_modeling/external_variables/`,
which is the data handed to the analysis repo. It has been verified end to end:
**21 of 21 output files reproduce, 0 real columns differ.**

Two things are deliberately **not** re-run:

- **AI labels** (`4_ai_labeled/`, `dish_labels_t2/`, `ai_grouping/`). These come
  from an LLM and are treated as committed source.
- **Model fits.** Posterior draws are committed so plots and tables regenerate
  without refitting.

### 1. Python environment

The pinned versions matter. `pandas 2.2` changes 13 columns of output without
raising an error, and `pandas 3.x` corrupts count columns outright.

**Linux / macOS**
```bash
conda env create -f env/environment_linux.yml    # creates "palate1"
conda activate palate1
pip install -e .                                 # the foodcast package itself
pip install pickleshare ipytest ipykernel nbconvert nbformat jupyter_client
```

**Windows**
```powershell
conda env create -f env\environment_windows.yml
conda activate base
pip install -e .
pip install pickleshare ipytest ipykernel nbconvert nbformat jupyter_client
```

`environment_windows.yml` is a full Anaconda export and already contains the
notebook stack; on Linux/macOS the four extra packages are needed because
`environment_linux.yml` pins only the analysis libraries.

Verify:
```bash
python -c "import pandas, pyarrow, foodcast; print(pandas.__version__, pyarrow.__version__)"
# expect 2.1.3 14.0.1   (or 2.2.2 16.1.0 on the Windows env)
```

### 2. R environment

`renv.lock` pins **R 4.4.2**. Earlier R will fail: `MASS` in the lockfile
requires >= 4.4.0 and nothing installs after it.

**All platforms** — install R 4.4.2 (from CRAN, or `conda create -n r442 -c conda-forge r-base=4.4.2 r-renv`), then from the repo root:

```r
renv::activate()      # creates renv/activate.R, which .Rprofile expects
renv::restore()       # installs all 210 pinned packages
```

Run these **with the project active** — i.e. plain `R` or `Rscript` from the repo
root, never `Rscript --vanilla`. Under `--vanilla` the `.Rprofile` is skipped,
`renv` compares the lockfile against your system library, and reports
"already synchronized" while the project library stays empty.

Verify:
```r
packageVersion("arrow")   # expect 18.1.0.1
```

### 3. Run the stages, in order

All notebooks must run with the **repo root** as the working directory.
`1_preprocessing` does not `chdir` for itself.

```
scripts/1_preprocessing.ipynb            0_data_excel     -> 1_data_parquet
scripts/1.1_encoding_errors.ipynb                         -> 1.1_data_excel_redone
scripts/2_cleaning.ipynb                 1_data_parquet   -> 2_data_parquet_cleaned
scripts/3.1_data_coverage.ipynb                           -> before_after_details_true.csv
scripts/labeling/labeling_1/loc*.ipynb   cleaned          -> 1_rule_relabeled, 2_consolidated
scripts/labeling/labeling_2/loc*.ipynb   (current pass — see note)
scripts/4.1_joining_customers.ipynb      2_consolidated   -> 3_combined_no_prelabeled_drinks
   ---- AI labelling happened here; 4_ai_labeled/ is committed, do not re-run ----
scripts/4_modeling_prep.ipynb            4_ai_labeled     -> 5_only_food, 6_only_dinein,
                                                             7_truly_consolidated, dish_counts
scripts/4.0_modeling_prep_2.ipynb        stage 7 + labels -> aggregated/
scripts/5_format_weather_and_inflation_data.R             -> weather_data.csv
scripts/5_add_weather_inflation_holidays.R                -> external_variables/finalized*
```

**Run `labeling_2` after `labeling_1`.** `labeling_2` is the current pass and
writes the 18-column `dish_counts`; `labeling_1` is its predecessor and writes 3.
Stopping after `labeling_1` makes `4.0_modeling_prep_2` fail with a missing
`sausage_dishes_count` column.

Headless, on any platform:
```bash
jupyter nbconvert --to notebook --execute --allow-errors \
  --output-dir /tmp/nbout scripts/1_preprocessing.ipynb
```
or drive `nbclient` with `resources={"metadata": {"path": "<repo root>"}}`.

### 4. Check the result

Parquet is not byte-stable — row order within equal keys varies between runs, so
compare **values**, not bytes:

```bash
git status --porcelain -- data/
```

Clean means identical to the committed data. If files show as modified, sort by
`location_id` and `date` and compare column by column before concluding anything
changed. `__index_level_0__` is a parquet index artifact, not a variable; ignore
it in comparisons.

### Known issues

- `%store` caches persist in `~/.ipython` across sessions and can be stale. If a
  notebook fails on a key that looks wrong, clear
  `~/.ipython/profile_default/db/autorestore`.
- `loc8`, `loc9` and several Tier-2 labeling notebooks were developed
  interactively and still fail in diagnostic cells that run **after** their data
  writes. Their output is correct.
- `3.1_data_coverage` uses a `before_after_details` that no cell assigns.

Full detail, including what is on the pipeline path and what is exploration,
is in the analysis repo's `publication/PIPELINE.md`.
