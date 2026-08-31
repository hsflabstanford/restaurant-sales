# Public packages
import numpy as np
import pandas as pd
from pandas import DateOffset
import pyarrow

import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
import matplotlib.cm as cm
import matplotlib.patches as mpatches
from mpl_toolkits.axes_grid1.inset_locator import inset_axes
from matplotlib.ticker import FuncFormatter
import seaborn as sns

import unicodedata
from tqdm import tqdm
import time
import itertools
import math
import os
import ast
from pathlib import Path
import pickle
import re
import gc
import tabulate
import yaml
from IPython import get_ipython
from IPython.display import display, Markdown

import scipy as sp
import statsmodels.api as sm
import statsmodels.formula.api as smf
from statsmodels.tsa.arima.model import ARIMA
import sklearn as sk
from sklearn.preprocessing import StandardScaler
    
# Custom packages
from foodcast.tools.coverage_functions import (
    plot_time_series, plot_time_series_subset, coverage_calculator,
    identify_time_gaps, plot_gaps_heatmap)
from foodcast.tools.labeling_functions import (
    fully_relabel_and_consolidate, relabel_items, recategorize_items, title_keep_ids,
    rename_items, rename_items_by_modifications, remove_numbers,
    to_dish_time_series, infer_active_days, strict_bridge_fill, 
    plot_dish_time_series, plot_boolean_time_series)
# from foodcast.tools.benchmarks import ParetoAnalysis as pa
# from foodcast.tools.benchmarks import AccuracyCalculation as ac
# from foodcast.tools.integrity_fixes import DataFixer as fix, DataExporter as exporter

# Set directory to project root
def find_project_root(start: Path = Path().absolute()) -> Path:
    for parent in start.parents:
        if (parent / "README.md").exists(): return parent
    return start 

#PROJECT_ROOT = Path(__file__).resolve().parents[2]
PROJECT_ROOT = find_project_root()

BASE_DIR = PROJECT_ROOT / "data"
DATA_DIR_1 = BASE_DIR / '1_data_parquet'
DATA_DIR_2 = BASE_DIR / '2_data_parquet_cleaned'
DATA_DIR_3 = BASE_DIR / '3_data_parquet_relabeled'
DATA_DIR_4 = BASE_DIR / '4_data_parquet_modeling'
DATA_DIR_3_1 = DATA_DIR_3 / '1_rule_relabeled'
DATA_DIR_3_2 = DATA_DIR_3 / '2_consolidated'
DATA_DIR_3_3 = DATA_DIR_3 / '3_combined_no_prelabeled_drinks'
DATA_DIR_3_4 = DATA_DIR_3 / '4_ai_labeled'
DATA_DIR_3_5 = DATA_DIR_3 / '5_only_food'
DATA_DIR_3_6 = DATA_DIR_3 / '6_only_dinein'
DATA_DIR_3_7 = DATA_DIR_3 / '7_truly_consolidated'
DATA_DIR_3_8 = DATA_DIR_3 / '8_with_menu_counts'
DATA_DIR_3_pre_1 = DATA_DIR_3 / 'used_for_ai_labeling' / '1_rule_labeled'
DATA_DIR_3_pre_2 = DATA_DIR_3 / 'used_for_ai_labeling' / '2_consolidated'
DATA_DIR_3_pre_3 = DATA_DIR_3 / 'used_for_ai_labeling' / '3_combined_no_prelabeled_drinks'


def return_dir():
    dir = (BASE_DIR, 
           DATA_DIR_1, 
           DATA_DIR_2, 
           DATA_DIR_3, 
           DATA_DIR_4,
           (DATA_DIR_3_1, 
           DATA_DIR_3_2, 
           DATA_DIR_3_3, 
           DATA_DIR_3_4, 
           DATA_DIR_3_5, 
           DATA_DIR_3_6,
           DATA_DIR_3_7,
           DATA_DIR_3_8,
           (DATA_DIR_3_pre_1, 
           DATA_DIR_3_pre_2,
           DATA_DIR_3_pre_3)))
    return dir

# Monkey patching
pd.DataFrame.print = lambda df: print(df.to_string())
pd.Series.print = lambda s: print(s.to_string())
pd.Index.print = lambda idx: print(idx.to_series().reset_index(drop=True).to_string())
def modifs(df, item): 
    df = df.assign(bool_mask = lambda df: df.item_name == item)
    if df.bool_mask.any():
        df.loc[df.bool_mask][['item_name','item_modifications']].value_counts().print()
    else: 
        print(f"Item '{item}' not found!") 
pd.DataFrame.modifs = lambda df, item: modifs(df, item)
    
def notebook_settings():
    """
    DOES THE EQUIVALENT OF THIS:

    pd.options.mode.copy_on_write = True
    %matplotlib inline
    %config InlineBackend.close_figures=True
    
    pd.set_option('display.max_rows', 100)
    %load_ext autoreload
    %autoreload 2
    """
    
    # Pandas settings
    pd.options.mode.copy_on_write = True # preemptively set new Pandas option
    pd.set_option('display.max_rows', 100)

    # “InlineBackend.close_figures = True” without magic
    try:
        from matplotlib_inline.config import InlineBackend
        InlineBackend.instance().close_figures = True
    except ModuleNotFoundError:
        # Falls back silently outside Jupyter
        pass

    # --- Only run if we’re *inside* IPython -------------------------------
    ip = get_ipython()
    if ip is None:
        return      # plain‑Python interpreter → nothing else to do

    # Replicate the magics
    ip.run_line_magic('matplotlib', 'inline')
    ip.run_line_magic('load_ext', 'autoreload')
    ip.run_line_magic('autoreload', '2')

def load_loc_ids():
    # List of restaurants by 4 month coverage
    location_ids_by_coverage = pd.read_csv(DATA_DIR_3 / 'restaurants_by_4m_coverage.csv')['location_id'].tolist()
    return location_ids_by_coverage

def load_static():
    # Static data about the restaurants
    location_ids_by_coverage = load_loc_ids()
    locations = pd.read_csv(DATA_DIR_3 / 'locations.csv', index_col='location_id').loc[location_ids_by_coverage] # Restaurant details
    before_after_details_true = pd.read_csv(DATA_DIR_3 / 'before_after_details_true.csv', index_col='location_id', parse_dates=['cross_over_date']).loc[location_ids_by_coverage] # True Promotional items (30 rows)
    items_tagged = pd.read_parquet(DATA_DIR_2 / 'items_tagged.parquet') # Menu items for all restaurants: for matching plant-based labels with orders
    customers = pd.read_parquet(DATA_DIR_2 / 'customers.parquet') # Specific customer information: for matching customers with orders
    return locations, before_after_details_true, items_tagged, customers

def load_timezones():
    timezones = pd.read_csv(DATA_DIR_3 / 'timezones.csv', index_col='location_id')['timezone'].to_dict()
    return timezones

def load_all_res_2():
    # Time series sales data for each restaurant
    location_ids_by_coverage = load_loc_ids()
    timezones = load_timezones()
    sales_and_menu_data = {}
    for loc_id in tqdm(location_ids_by_coverage):
        if loc_id == 'VLZX7K2M9QD4T':
            filename = 'VLZX7K2M9QD4T.parquet'
            df = pd.read_parquet(DATA_DIR_3_2 / filename)
            sales_and_menu_data[loc_id] = df
        else:
            filename = f'{loc_id}_sales_and_menu.parquet'
            df = pd.read_parquet(DATA_DIR_2 / 'orders_item_level' / filename)
            sales_and_menu_data[loc_id] = df.tz_convert(timezones[loc_id])
    return sales_and_menu_data

def load_one_res_2(loc_id):
    timezones = load_timezones()
    if loc_id == 'VLZX7K2M9QD4T':
        filename = 'VLZX7K2M9QD4T.parquet'
        df = pd.read_parquet(DATA_DIR_3_2 / filename)
        
    else:
        filename = f'{loc_id}_sales_and_menu.parquet'
        df = pd.read_parquet(DATA_DIR_2 / 'orders_item_level' / filename).tz_convert(timezones[loc_id])
    return df    

def load_all_res_3_2_con():
    location_ids_by_coverage = load_loc_ids()
    sales_and_menu_data = {}
    for loc_id in tqdm(location_ids_by_coverage):
        if loc_id == 'VLZX7K2M9QD4T':
            filename = 'VLZX7K2M9QD4T.parquet'
            df = pd.read_parquet(DATA_DIR_3_2 / filename)
        elif f'{loc_id}_sales_and_menu.parquet' in os.listdir(DATA_DIR_3_2):
            filename = f'{loc_id}_sales_and_menu.parquet'
            df = pd.read_parquet(DATA_DIR_3_2 / filename)
        else:
            filename = f'{loc_id}_sales_and_menu.parquet'
            df = pd.read_parquet(DATA_DIR_2 / 'orders_item_level' / filename)
        sales_and_menu_data[loc_id] = df
    return sales_and_menu_data

def load_all_res_3_4_ai():
    location_ids_by_coverage = load_loc_ids()
    data = {}
    for loc_id in tqdm(location_ids_by_coverage):
        df = pd.read_parquet(DATA_DIR_3_4 / f'{loc_id}.parquet')
        data[loc_id] = df
    return data

def load_one_res_3_4_ai(loc_id):
    df = pd.read_parquet(DATA_DIR_3_4 / f'{loc_id}.parquet')
    return df

def load_all_res_3_6_dinein():
    location_ids_by_coverage = load_loc_ids()
    data = {}
    for loc_id in tqdm(location_ids_by_coverage):
        df = pd.read_parquet(DATA_DIR_3_6 / f'{loc_id}.parquet')
        data[loc_id] = df
    return data

def load_one_res_3_6_dinein(loc_id):
    df = pd.read_parquet(DATA_DIR_3_6 / f'{loc_id}.parquet')
    return df

def load_one_res_3_7_truly_consolidated(loc_id):
    df = pd.read_parquet(DATA_DIR_3_7 / f'{loc_id}.parquet')
    return df

def load_all_res_3_7_truly_consolidated():
    data = {}
    location_ids_by_coverage = load_loc_ids()
    for loc_id in tqdm(location_ids_by_coverage):
        # if loc_id == location_ids_by_coverage[0]:
        #     df = pd.read_parquet(DATA_DIR_3_6 / f'{loc_id}.parquet')
        # else:
        df = pd.read_parquet(DATA_DIR_3_7 / f'{loc_id}.parquet')
        data[loc_id] = df
    return data

def load_all_res_3_8_menu():
    location_ids_by_coverage = load_loc_ids()
    data = {}
    for loc_id in tqdm(location_ids_by_coverage):
        df = pd.read_parquet(DATA_DIR_3_8 / f'{loc_id}.parquet')
        data[loc_id] = df
    return data

def load_gaps():
    # Import from pickle
    time_differences = pd.read_pickle(DATA_DIR_3 / 'time_differences.pkl')
    time_differences_details = pd.read_pickle(DATA_DIR_3 / 'time_differences_details.pkl')
    return time_differences, time_differences_details

__all__ = ['np', 'pd', 'DateOffset', 'pyarrow',  'yaml',
           'plt', 'mcolors', 'cm', 'mpatches', 'inset_axes', 'FuncFormatter', 'sns', 
           'tqdm', 'itertools', 'math', 'os', 're', 'gc', 'pickle','ast','Path', 'tabulate', 'display', 'Markdown', 'unicodedata',
           'sp', 'sm', 'smf', 'ARIMA', 'StandardScaler', 
           'plot_time_series', 'plot_time_series_subset', 'coverage_calculator',
           'identify_time_gaps', 'plot_gaps_heatmap', 
           'fully_relabel_and_consolidate', 'relabel_items', 'recategorize_items', 'title_keep_ids',
           'rename_items', 'rename_items_by_modifications', 'remove_numbers', 
           'to_dish_time_series', 'infer_active_days', 'strict_bridge_fill',
           'plot_dish_time_series','plot_boolean_time_series',
           'find_project_root', 'PROJECT_ROOT',
           'return_dir', 'notebook_settings',
           'load_loc_ids', 'load_static', 'load_timezones', 
           'load_all_res_2', 'load_one_res_2', 'load_all_res_3_2_con', 
           'load_all_res_3_4_ai', 'load_one_res_3_4_ai',
           'load_all_res_3_6_dinein', 'load_one_res_3_6_dinein',
            'load_one_res_3_7_truly_consolidated',
           'load_all_res_3_7_truly_consolidated',
           'load_all_res_3_8_menu',
           'load_gaps',
           'BASE_DIR', 'DATA_DIR_2', 'DATA_DIR_3']