# Public packages
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from tqdm import tqdm
import math
import os
import re
import tabulate
from IPython.display import display, Markdown



def coverage_calculator(loc_id, df, promos, freqs=['W-MON','D','12H','6H'], periods=['all','4mo','bef','b2m','aft','a2m']):

    # Remove duplicates orders to count distinct number of orders
    df = df.drop_duplicates('order_id')

    # Identify necessary dates
    first_date = df.index[0]
    last_date = df.index[-1]
    promo_datetime = promos.loc[loc_id, 'cross_over_date'] # Identify introduction date
    two_months_before = promo_datetime - pd.DateOffset(days=60) # Two months before the promotional introduction date
    two_months_after = promo_datetime + pd.DateOffset(days=60) # Two months after the promotional introduction date

    # All time period options
    all_periods = {'all':(first_date, last_date),
                '4mo':(two_months_before, two_months_after),
                'bef':(first_date, promo_datetime),
                'b2m':(two_months_before, promo_datetime),
                'aft':(promo_datetime, last_date),
                'a2m':(promo_datetime, two_months_after)}

    # Filter to chosen time periods for iterating
    periods_to_use = {}
    for period in periods:
        periods_to_use[period] = all_periods[period]

    # Initialize container to aggregate for summary
    row = {'loc_id': loc_id}
    for qualifier, (beginning, end) in periods_to_use.items():
        
        # Unpack beginning and end dates to determine the actual data within the period
        period = df.loc[beginning:end]
        
        # Calculate total
        row[f'{qualifier}_order'] = period.shape[0]

        # Resample the time series for every frequency
        for freq in freqs:

            # Number of active weeks within the bounds, and then before and after
            resampled_data = period.resample(freq).size()
            active_total_at_freq = (0 < resampled_data).sum()

            if 'W' in freq:
                end = end + pd.DateOffset(weeks=1)

            # Possible periods
            possible = pd.date_range(beginning, end, freq=freq, ambiguous=True, inclusive='left')
            possible_total = possible.shape[0]
            if 'H' in freq and beginning.utcoffset() > end.utcoffset():
                possible_total -= 1
            
            # Calculate data coverage (when the restaurant is active) as a fraction of the total possible days
            coverage_ratio = active_total_at_freq / possible_total
            rounded_coverage_ratio = float(int(round(100*coverage_ratio)))/100

            # Other simple stats
            rounded_mean = round(np.mean(resampled_data))
            rounded_sd = round(np.std(resampled_data))

            # Store
            # row[f'{qualifier}_{freq}'] = active_total_at_freq
            row[f'{qualifier}_{freq[:3]}_cover'] = rounded_coverage_ratio
            # row[f'{qualifier}_{freq}_mean'] = rounded_mean 
            # row[f'{qualifier}_{freq}_sd'] = rounded_sd

    return row


def plot_time_series(loc_id, df, promos, max_ylim=0, freq='D', subset=True):

    
    # Turn auto display
    plt.ioff()

    # Filter to plant-based items and resample
    plant_based = df.query('is_plant_based == "Yes"')
    promo_datetime = pd.to_datetime(promos.loc[loc_id, 'cross_over_date']).tz_localize('UTC')
    two_months_before = promo_datetime - pd.DateOffset(months=2)
    two_months_after = promo_datetime + pd.DateOffset(months=2)

    # Resample to specified frequency
    plant_based = plant_based.resample(freq)[['item_quantity']].sum()
    all_items = df.resample(freq)[['item_quantity']].sum()

    # Compute ratios and handle missing data
    all_items.replace(0, np.nan, inplace=True)
    plant_based_ratio = plant_based / all_items

    # Subset for the specified time range
    if subset:
        plant_based_ratio = plant_based_ratio[two_months_before:two_months_after]
        all_items = all_items[two_months_before:two_months_after]

    # Identify ends of contiguous data chunks
    is_contiguous = plant_based_ratio.notna()
    shift_plus = is_contiguous.shift(1, fill_value=False)
    shift_minus = is_contiguous.shift(-1, fill_value=False)
    start_points = is_contiguous & ~shift_plus
    end_points = is_contiguous & ~shift_minus

    # Plotting
    fig, ax = plt.subplots(1, 2, figsize=(16, 4))  # Creates a single subplot
    ax1, ax2 = ax

    ## Plot 1

    # Main plot
    ax1.plot(plant_based_ratio.index, plant_based_ratio, marker='o', markersize=1, linewidth=2, label='Plant-Based Items Fraction')

    # Adding dots for the start and end of each contiguous chunk
    ax1.plot(plant_based_ratio[start_points].index, plant_based_ratio[start_points], linewidth=0, color='#2fb7bf', markersize=5, marker='o', label='Start Extant Data')
    ax1.plot(plant_based_ratio[end_points].index, plant_based_ratio[end_points], linewidth=0, color='#1f77c4', markersize=5, marker='o', label='End Extant Data')

    # Promo date line
    ax1.axvline(x=promo_datetime, color='red', linestyle='--', label='Promo Date')

    # Ticks and limits
    xticks = pd.date_range(promo_datetime - pd.DateOffset(days=60), periods=10, freq="15D")
    if subset:
        ax1.set_xticks(ticks=xticks)
        ax1.set_xticklabels(labels=xticks.date, rotation=70)
        ax1.set_xlim(promo_datetime - pd.DateOffset(days=60), promo_datetime + pd.DateOffset(days=60))
    ax1.set_ylim(0, 1)

    # Axis and title
    ax1.set_title(f'Plant-Based Items Fraction for {loc_id}')
    ax1.set_ylabel('Ratio')
    ax1.set_xlabel('Date')
    ax1.legend()

    ## Plot 2

    # Main plot
    ax2.plot(all_items.index, all_items, linewidth=2, color='orange', marker='o', markersize=1, label='Total Item Quantity')

    # Extra details, adding dots to the edge of non-missing data
    ax2.axvline(x=promo_datetime, color='red', linestyle='--', label='Promo Date')

    # Adding dots for the start and end of each contiguous chunk
    ax2.plot(all_items[start_points].index, all_items[start_points], linewidth=0, color='#ff8500', markersize=5, marker='o', label='Start Extant Data')
    ax2.plot(all_items[end_points].index, all_items[end_points], linewidth=0, color='#ffa500', markersize=5, marker='o', label='End Extant Data')

    # Ticks and limits
    xticks = pd.date_range(promo_datetime - pd.DateOffset(days=60), periods=10, freq="15D")
    if subset:
        ax2.set_xticks(ticks=xticks)
        ax2.set_xticklabels(labels=xticks.date, rotation=70)
        ax2.set_xlim(promo_datetime - pd.DateOffset(days=60), promo_datetime + pd.DateOffset(days=60))
    ax2.set_ylim(0, max(max_ylim, all_items['item_quantity'].max()))

    # Axis and title
    ax2.set_title(f'Total Item Quantity Sold for {loc_id}')
    ax2.set_ylabel('Quantity')
    ax2.set_xlabel('Date')
    ax2.legend()

    return fig


def plot_time_spacing(loc_id, time_differences, colorbar_max):

    fig, ax = plt.subplots(figsize=(10, 5))

    # Assuming time_differences[loc_id] is a valid 2D array and using pandas DataFrame
    dat = time_differences[loc_id].T.iloc[:,1:]  # Converting to DataFrame if not already one

    full_columns = np.arange(24)

    dat = dat.reindex(columns=full_columns)

    norm = plt.Normalize(vmin=0, vmax=colorbar_max)

    cax = ax.imshow(dat, cmap='viridis', norm=norm)  # Display the data as an image

    # Adding a color bar
    fig.colorbar(cax, ax=ax)

    # Loop over data dimensions and create text annotations for each cell
    num_rows, num_cols = dat.shape
    for i in range(num_rows):
        for j in range(num_cols):
            # Only annotate if the value is not NaN
            if dat.iloc[i, j] == dat.iloc[i, j]:
                # Rounded value if not NaN
                rounded_value = round(100 * dat.iloc[i, j]) // 100
                ax.text(j, i, str(rounded_value), ha='center', va='center', color='w', fontsize=8)

    # Assigning labels for each column with the days of the week
    days_of_week = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    # Setting x-axis ticks to be centered on each column
    ax.set_yticks(np.arange(num_rows))

    ax.set_yticklabels(days_of_week)

    # # Ensuring the labels are displayed at the top
    # ax.xaxis.set_ticks_position('top')

    ax.set_xticks(np.arange(1, 24))
    ax.set_xticklabels(np.arange(1, 24))
    ax.set_xlim(.5,23.5)

    ax.set_title('Number of Gaps in the Data of a Given Duration')
    ax.set_xlabel('Gap Duration in Hours')
    ax.set_ylabel('Day of the Week')

    plt.show()