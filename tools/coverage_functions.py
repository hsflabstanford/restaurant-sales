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


def resample_time_series(
    df, 
    column='item_quantity',
    freq='D',
    exposure=None, 
    truncate=False,
    offset=60):
    
    # Time window
    if exposure:
        two_months_before = exposure - pd.DateOffset(days=offset)
        two_months_after = exposure + pd.DateOffset(days=offset)

    # Resample to specified frequency and handle missing data
    resampled_data = (df
                      .resample(freq)
                      [[column]]
                      .sum()
                      .replace(0, np.nan)
                      .pipe(lambda df: df.loc[two_months_before:two_months_after] if exposure and truncate else df))

    return resampled_data


def identify_time_series_contiguous(resampled_data):

    # Identify ends of contiguous data chunks
    is_present = resampled_data.notna()
    is_present_backward = is_present.shift(1, fill_value=False) # pulls past values forward
    is_present_forward = is_present.shift(-1, fill_value=False) # pulls future values backward
    
    # Start and end points
    start_indicators = is_present & ~is_present_backward # start if present and not present before
    end_indicators = is_present & ~is_present_forward # end if present and not present after
    start_points = resampled_data[start_indicators]
    end_points = resampled_data[end_indicators]
    
    return start_points, end_points


def plot_time_series(
    df, 
    column='item_quantity',
    title='Total Item Quantity Sold',
    freq='D',
    exposure=None, 
    truncate=False,
    offset=60,
    max_ylim=0,
    color='orange',
    color_start='#ff8500',
    color_end='#ffb500'):

    # Identify starts and ends of contiguous chunks
    resampled_data = resample_time_series(
        df, 
        column=column,
        freq=freq,
        exposure=exposure,
        truncate=truncate,
        offset=offset)
    
    start_points, end_points = identify_time_series_contiguous(resampled_data)

    # Plotting
    fig, ax = plt.subplots(1, 1, figsize=(16, 4)) 
    ax.plot(resampled_data.index, 
            resampled_data.values, 
            linewidth=2, color=color, marker='o', markersize=1, label=column.replace('_', ' ').title())
    ax.axvline(x=exposure, color='red', linestyle='--', label='Promo Date') if exposure else None # conditional

    # Adding dots for the start and end of each contiguous chunk
    ax.plot(start_points.index, 
            start_points.values, 
            linewidth=0, color=color_start, markersize=5, marker='o', label='Start Extant Data')
    ax.plot(end_points.index, 
            end_points.values, 
            linewidth=0, color=color_end, markersize=5, marker='o', label='End Extant Data')

    # Ticks and limits
    ax.set_xlim(resampled_data.index.min(), resampled_data.index.max()) if truncate else None # conditional
    ax.set_ylim(0, max(max_ylim, resampled_data[column].max()))

    # Axis and title
    loc_id = df['location_id'].iloc[0] if 'location_id' in df.columns else ''
    ax.set_title(title + f' for {loc_id}')
    ax.set_ylabel(column.replace('_', ' ').title())
    ax.set_xlabel('Date')
    ax.legend()

    return fig


def plot_time_series_subset(
    df, 
    column1='item_quantity',
    title1='Total Item Quantity Sold',
    column2='is_plant_based',
    column2_value='Yes',
    title2='Plant-Based Item Quantity',
    normalize=True,
    freq='D',
    exposure=None, 
    truncate=False,
    offset=60,
    max_ylim1=0,
    max_ylim2=0,
    color1='orange',
    color_start1='#ff8500',
    color_end1='#ffb500',
    color2='#1f77b4',
    color_start2='#1f77c4',
    color_end2='#2fb7bf'):

    # Identify starts and ends of contiguous chunks
    resampled_data = resample_time_series(
        df, 
        column=column1,
        freq=freq,
        exposure=exposure,
        truncate=truncate,
        offset=offset)
    
    start_points, end_points = identify_time_series_contiguous(resampled_data)

    # Identify starts and ends of contiguous chunks
    resampled_data_part = resample_time_series(
        df[df[column2] == column2_value], 
        column=column1,
        freq=freq,
        exposure=exposure,
        truncate=truncate,
        offset=offset)

    # Turn into a ratio if toggled
    normalize_str1 = ''
    normalize_str2 = ''
    if normalize:
        resampled_data_part = resampled_data_part / resampled_data
        normalize_str2 = ' Fraction'
        max_ylim2 = 1

    # Filtered part of the data
    start_points_part, end_points_part = identify_time_series_contiguous(resampled_data_part)
    
    # Plotting
    fig, ax_list = plt.subplots(1, 2, figsize=(16, 4))  # Creates a single subplot
    data1, data2 = (resampled_data, start_points, end_points), (resampled_data_part, start_points_part, end_points_part)
    colors1, colors2 = (color1, color_start1, color_end1), (color2, color_start2, color_end2)
    plot_list = zip(ax_list, 
                    [data1, data2], 
                    [title1, title2], 
                    [colors1, colors2],
                    [max_ylim1, max_ylim2],
                    [normalize_str1, normalize_str2])
    for ax, data, title, colors, max_ylim, normalize_str in plot_list:
        resampled_data, start_points, end_points = data
        color, color_start, color_end = colors

        # Main plot
        y_label = column1.replace('_', ' ').title() + normalize_str
        ax.plot(resampled_data.index, 
                resampled_data.values, 
                linewidth=2, color=color, marker='o', markersize=1, label=y_label)
        ax.axvline(x=exposure, color='red', linestyle='--', label='Promo Date') if exposure else None # conditional

        # Adding dots for the start and end of each contiguous chunk
        ax.plot(start_points.index, 
                start_points.values, 
                linewidth=0, color=color_start, markersize=5, marker='o', label='Start Extant Data')
        ax.plot(end_points.index, 
                end_points.values, 
                linewidth=0, color=color_end, markersize=5, marker='o', label='End Extant Data')

        # Ticks and limits
        ax.set_xlim(resampled_data.index.min(), resampled_data.index.max()) if truncate else None # conditional
        ax.set_ylim(0, max(max_ylim, resampled_data[column1].max()))

        # Axis and title
        loc_id = df['location_id'].iloc[0] if 'location_id' in df.columns else ''
        ax.set_title(title + normalize_str + f' for {loc_id}')
        ax.set_ylabel(y_label)
        ax.set_xlabel('Date')
        ax.legend()

    return fig


def identify_time_gaps(df, 
                       column='item_quantity', 
                       index_name='created_at'):

    time_differences_details = {}
    time_differences = {}

    # Group by transactions (at the same time)
    transactions = df.groupby(index_name)[column].sum()

    # Group by individuals days and days of the week
    transaction_by_dayofweek = transactions.groupby([transactions.index.dayofweek, transactions.index.date])

    # Take the index at every group and find the difference between time points (dropping the NaT edges) and convert to hours
    time_diffs_on_dayofweek = transaction_by_dayofweek.apply(lambda s: s.index.to_series().diff().dropna().dt.seconds//3600)

    existing_combinations = time_diffs_on_dayofweek.index.drop_duplicates()

    # Create a new MultiIndex from all days and existing (date, datetime) combinations
    all_days = np.arange(7) 
    new_indices = [(day, date, datetime) for day in all_days for _, date, datetime in existing_combinations]
    time_diffs_on_dayofweek = time_diffs_on_dayofweek.reindex(new_indices)

    # Rename
    time_differences_details = time_diffs_on_dayofweek

    time_diff_frequencies_list = []
    for dayofweek in range(7):

        # Subset to given day of the week and calculate the frequencies
        if dayofweek in time_diffs_on_dayofweek.index.get_level_values(0):
            time_diff_frequencies_specific_day = time_diffs_on_dayofweek[dayofweek].value_counts()
            time_diff_frequencies_specific_day.index.name = "time_diffs"
            time_diff_frequencies_specific_day.name = dayofweek
            time_diff_frequencies_list.append(pd.DataFrame(time_diff_frequencies_specific_day))

    time_diff_frequencies = time_diff_frequencies_list[0].join(time_diff_frequencies_list[1:], how='outer').sort_index()
    time_diff_frequencies = time_diff_frequencies.rename(columns={0:'Monday', 1:'Tuesday', 2:'Wednesday', 3:'Thursday', 4:'Friday', 5:'Saturday', 6:'Sunday'})

    # Rename
    time_differences = time_diff_frequencies
    
    return time_differences, time_differences_details

    return time_diff_summary, time_diff_details

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


def coverage_calculator(loc_id, 
                        df, 
                        promos,
                        timezones, 
                        freqs=['W-MON','D','12H','6H'], 
                        periods=['all','4mo','bef','b2m','aft','a2m'], 
                        include_weekends=True):

    # Remove duplicates orders to count distinct number of orders
    df = df.drop_duplicates('order_id')

    # Identify necessary dates
    first_date = df.index[0]
    last_date = df.index[-1]
    promo_datetime = promos.loc[loc_id, 'cross_over_date'].tz_convert(timezones[loc_id]) # Identify introduction date
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
            # If we're not including weekends and frequency is daily or sub-daily, remove weekend bins
            if freq in ['D','12H','6H'] and not include_weekends:
                resampled_data = resampled_data[(resampled_data.index.weekday != 5) & (resampled_data.index.weekday != 6)]
            active_total_at_freq = (0 < resampled_data).sum()

            if 'W' in freq:
                end = end + pd.DateOffset(weeks=1)

            # Possible periods
            possible = pd.date_range(beginning, end, freq=freq, ambiguous=True, inclusive='left')
            # Remove weekend bins from the possible range if applicable
            if freq in ['D','12H','6H'] and not include_weekends:
                possible = possible[(possible.weekday != 5) & (possible.weekday != 6)]
            possible_total = possible.shape[0]
            if 'H' in freq and beginning.utcoffset() > end.utcoffset():
                possible_total -= 1
            
            # Calculate data coverage (when the restaurant is active) as a fraction of the total possible days
            coverage_ratio = active_total_at_freq / possible_total
            rounded_coverage_ratio = float(int(round(100*coverage_ratio)))/100

            # Other simple stats
            #rounded_mean = round(np.mean(resampled_data))
            #rounded_sd = round(np.std(resampled_data))

            # Store
            # row[f'{qualifier}_{freq}'] = active_total_at_freq
            row[f'{qualifier}_{freq[:3]}_cover'] = rounded_coverage_ratio
            # row[f'{qualifier}_{freq}_mean'] = rounded_mean 
            # row[f'{qualifier}_{freq}_sd'] = rounded_sd

    return row