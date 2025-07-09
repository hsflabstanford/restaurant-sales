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
    resampled_data_full = resample_time_series(
        df, 
        column=column1,
        freq=freq,
        exposure=exposure,
        truncate=truncate,
        offset=offset)
    
    start_points, end_points = identify_time_series_contiguous(resampled_data_full)

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
        resampled_data_part = resampled_data_part / resampled_data_full
        normalize_str2 = ' Fraction'
        max_ylim2 = 1

    # Filtered part of the data
    start_points_part, end_points_part = identify_time_series_contiguous(resampled_data_part)
    
    # Plotting
    fig, ax_list = plt.subplots(1, 2, figsize=(16, 4))  # Creates a single subplot
    data1, data2 = (resampled_data_full, start_points, end_points), (resampled_data_part, start_points_part, end_points_part)
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


# def identify_time_gaps(df, 
#                        column='item_quantity'):

#     # Group by transactions (at the same time)
#     time_diffs = (df
#                   .groupby(df.index) # make it unique by the time index
#                     [column]
#                     .sum()
#                     .assign(dayofweek=lambda x: x.index.dayofweek, date=lambda x: x.index.date)
#                     .groupby(['dayofweek', 'date'])
#                     # Take the index at every group and find the difference between time points (dropping the NaT edges) and convert to hours
#                     .apply(lambda s: (s
#                                       .index
#                                       .to_series()
#                                       .diff()
#                                       .dropna()
#                                       .dt.seconds
#                                       //3600)))

#     existing_combinations = time_diffs_on_dayofweek.index.drop_duplicates()

#     # Create a new MultiIndex from all days and existing (date, datetime) combinations
#     all_days = range(7)
#     new_indices = [(day, date, datetime) for day in all_days for _, date, datetime in existing_combinations]
#     time_diffs_on_dayofweek = time_diffs_on_dayofweek.reindex(new_indices)

#     time_diff_frequencies_list = []
#     for dayofweek in all_days:

#         present_days_of_week = time_diffs_on_dayofweek.index.get_level_values(0)
#         if dayofweek in present_days_of_week:
#             time_diff_frequencies_list.append(time_diffs_on_dayofweek
#                                               [dayofweek] # subset to given day of the week and calculate the frequencies
#                                               .value_counts()
#                                               .to_frame(dayofweek)
#                                               .rename_axis('time_diffs'))
            

#     time_differences = (time_diff_frequencies_list[0]
#                        .join(time_diff_frequencies_list[1:], how='outer')
#                        .sort_index()
#                        .rename(columns={0:'Monday', 
#                                         1:'Tuesday', 
#                                         2:'Wednesday', 
#                                         3:'Thursday', 
#                                         4:'Friday', 
#                                         5:'Saturday', 
#                                         6:'Sunday'}))

#     return time_differences, time_diffs_on_dayofweek


def identify_time_gaps(df, column='item_quantity'):

    day_mapping = {
        0: 'Monday',
        1: 'Tuesday',  
        2: 'Wednesday',
        3: 'Thursday',
        4: 'Friday',
        5: 'Saturday',
        6: 'Sunday'}

    time_diffs = (
        df
        .groupby(df.index)
        [[column]]
        .sum()
        .assign(
            time_diff = lambda df: df.index.to_series().diff(),
            is_same_day = lambda df: df.index.to_series().dt.date == df.index.to_series().shift(1).dt.date)
        .query('is_same_day')
        .assign(
            diff_hours = lambda d: d.time_diff.dt.total_seconds() // 3600,
            dayofweek = lambda d: d.index.dayofweek))
    
    time_diff_summary = (
        time_diffs
        .pivot_table(
            index='diff_hours',
            columns='dayofweek',
            aggfunc='size')
        .reindex(columns=range(7))
        .rename(columns=day_mapping))
    
    loc_id = df['location_id'].iloc[0]
    time_diff_summary.columns.name = loc_id
    time_diff_details = time_diffs['diff_hours'].copy().rename(loc_id) # make sure its not a view
    time_diff_details.index = pd.MultiIndex.from_arrays(
        [time_diffs['dayofweek'], time_diffs.index.date, time_diffs.index],
        names=['dayofweek', 'date', 'datetime'])

    return time_diff_summary, time_diff_details

def plot_gaps_heatmap(time_diff_summary, 
                      colorbar_max_adj=1e3):

    HOURS_IN_DAY = 24

    data = (
        time_diff_summary
        .T
        .drop(columns=[0]) # exclude gaps of less than an hour
        .reindex(columns=range(HOURS_IN_DAY)))
    
    fig, ax = plt.subplots(figsize=(10, 5))
    colorbar_max = time_diff_summary.sum().sum() / colorbar_max_adj
    norm = plt.Normalize(vmin=0, vmax=colorbar_max)
    cax = ax.imshow(data, cmap='viridis', norm=norm)  # display the data as an image
    fig.colorbar(cax, ax=ax)

    # Add text to each cell
    num_rows, num_cols = data.shape
    for i in range(num_rows):
        for j in range(num_cols):
            if not np.isnan(data.iloc[i, j]):
                ax.text(j, i, str(int(data.iloc[i, j])), ha='center', va='center', color='w', fontsize=8)

    # Ticks and limits
    ax.set_yticks(np.arange(num_rows))
    ax.set_yticklabels(time_diff_summary.columns)
    ax.set_xticks(np.arange(1, HOURS_IN_DAY))
    ax.set_xticklabels(np.arange(1, HOURS_IN_DAY))
    ax.set_xlim(.5, HOURS_IN_DAY-0.5) # center the squares, to make it like a heatmap

    # Labels
    loc_id = time_diff_summary.columns.name
    ax.set_title(f'Number of Gaps in the Data of a Given Duration for {loc_id}')
    ax.set_xlabel('Gap Duration in Hours')
    ax.set_ylabel('Day of the Week')

    plt.show()


def coverage_calculator(
    loc_id, 
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