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

from tqdm import tqdm
import time
import itertools
import math
import os
from pathlib import Path
import re
import gc
import tabulate
from IPython import get_ipython
from IPython.display import display, Markdown

import scipy as sp
import statsmodels.api as sm
import statsmodels.formula.api as smf
from statsmodels.tsa.arima.model import ARIMA
import sklearn as sk
from sklearn.preprocessing import StandardScaler

# Custom packages
from tools.coverage_functions import plot_time_series, plot_time_series_subset
from tools.labeling_functions import fully_relabel_and_consolidate, plot_dish_time_series, rename_items
# from tools.benchmarks import ParetoAnalysis as pa
# from tools.benchmarks import AccuracyCalculation as ac
# from tools.integrity_fixes import DataFixer as fix, DataExporter as exporter

# Set directory to project root
def find_project_root(start: Path = Path().absolute()) -> Path:
    for parent in start.parents:
        if (parent / "requirements.txt").exists(): return parent
    return start 

BASE_DIR = Path('data')
DATA_DIR_1 = BASE_DIR / '2_palate_data_parquet_cleaned'
DATA_DIR_2 = BASE_DIR / '4_palate_data_parquet_relabeled'

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
    location_ids_by_coverage = pd.read_csv(DATA_DIR_2 / 'restaurants_by_4m_coverage.csv')['location_id'].tolist()
    return location_ids_by_coverage

def load_static():
    # Static data about the restaurants
    location_ids_by_coverage = load_loc_ids()
    locations = pd.read_csv(DATA_DIR_2 / 'locations.csv', index_col='location_id').loc[location_ids_by_coverage] # Restaurant details
    before_after_details_true = pd.read_csv(DATA_DIR_2 / 'before_after_details_true.csv', index_col='location_id', parse_dates=['cross_over_date']).loc[location_ids_by_coverage] # True Promotional items (30 rows)
    items_tagged = pd.read_parquet(DATA_DIR_1 / 'items_tagged.parquet') # Menu items for all restaurants: for matching plant-based labels with orders
    customers = pd.read_parquet(DATA_DIR_1 / 'customers.parquet') # Specific customer information: for matching customers with orders
    return locations, before_after_details_true, items_tagged, customers

def load_timezones():
    timezones = pd.read_csv(BASE_DIR / 'timezones.csv', index_col='location_id')['timezone'].to_dict()
    return timezones

def load_sales():
    # Time series sales data for each restaurant
    location_ids_by_coverage = load_loc_ids()
    timezones = load_timezones()
    sales_and_menu_data = {}
    for loc_id in tqdm(location_ids_by_coverage):
        if loc_id == 'VLZX7K2M9QD4T':
            filename = 'VLZX7K2M9QD4T.parquet'
            df = pd.read_parquet(DATA_DIR_2 / 'consolidated' / filename)
            sales_and_menu_data[loc_id] = df
        else:
            filename = f'{loc_id}_sales_and_menu.parquet'
            df = pd.read_parquet(DATA_DIR_1 / 'orders_item_level' / filename)
            sales_and_menu_data[loc_id] = df.tz_convert(timezones[loc_id])
    return sales_and_menu_data

def load_single_restaurant(loc_id):
    timezones = load_timezones()
    if loc_id == 'VLZX7K2M9QD4T':
        filename = 'VLZX7K2M9QD4T.parquet'
        df = pd.read_parquet(DATA_DIR_2 / 'consolidated' / filename)
        
    else:
        filename = f'{loc_id}_sales_and_menu.parquet'
        df = pd.read_parquet(DATA_DIR_1 / 'orders_item_level' / filename).tz_convert(timezones[loc_id])
    return df    

def load_gaps():
    # Import from pickle
    time_differences = pd.read_pickle(DATA_DIR_1 / 'time_differences.pkl')
    time_differences_details = pd.read_pickle(DATA_DIR_1 / 'time_differences_details.pkl')
    return time_differences, time_differences_details

__all__ = ['np', 'pd', 'DateOffset', 'pyarrow', 
           'plt', 'mcolors', 'cm', 'mpatches', 'inset_axes', 'FuncFormatter', 'sns', 
           'tqdm', 
           'itertools', 'math', 'os', 're', 'Path', 'tabulate', 'display', 'Markdown', 
           'sm', 'smf', 'ARIMA', 'StandardScaler', 
           'plot_time_series', 'plot_time_series_subset', 'fully_relabel_and_consolidate', 'plot_dish_time_series', 'rename_items',
           'find_project_root', 'notebook_settings',
           'load_loc_ids', 'load_static', 'load_timezones', 'load_sales', 'load_single_restaurant', 'load_gaps', 'BASE_DIR', 'DATA_DIR_1', 'DATA_DIR_2']