import pandas as pd
import ipytest


def rolling_window_sum(
    df: pd.DataFrame, 
    label_col: str, 
    qty_col: str, 
    name: str,
    lookback_period: int, 
    lookback_unit: str
) -> pd.Series:
    """
    Time-based rolling sum over [t - lookback, t): multiply label*qty, aggregate duplicates per second,
    exclude the current timestamp, include exactly one lookback ago, return a Series named `name`.
    
    Args:
        df : input DataFrame indexed and sorted by timestamp
        name : name to assign to the returned Series.
        lookback_period : length of the lookback window (e.g., 5 if the window is 5 minutes).
        lookback_unit : unit of the lookback window (e.g., 's' for seconds, 'min' for minutes, 'h' for hours, 'd' for days).
    """
    res = (
        df
        .assign(qty_of_label=lambda df: df[label_col] * df[qty_col])
        ['qty_of_label']
        .groupby(level=0) # group by unique timestamps
        .sum()
        .sort_index()
        .rolling(f'{lookback_period}{lookback_unit}', closed='both') # 
        .sum()
        .sub( # remove the current time step's quantity by doing the same but without rolling
            df
            .assign(qty_of_label=lambda df: df[label_col] * df[qty_col])
            ['qty_of_label']
            .groupby(level=0).sum()
            .sort_index())      
        .ffill() # ffill prevents data leakage by taking the last valid observation forward
        .fillna(0.0) # fill first spot if necessary since nothing before it
        .rename(name))
    return res


def rolling_window_avg(
    df: pd.DataFrame,
    label_col: str, 
    interest_col: str,
    qty_col: str,
    lookback_period: int, 
    lookback_unit: str
) -> pd.DataFrame:
    """
    Compute a time-based rolling average over the window [t - lookback, t) for rows where `label_col` is 1.
    Steps:
      • Use `rolling_window_sum` twice to get:
          - sum of `interest_col` over [t-lookback, t)
          - sum of `qty_col`      over [t-lookback, t)
      • Join both sums back to `df` by index and produce:
          - `{label_col}_window_avg_{interest_col}` = sum(interest) / sum(qty), forward-filled then filled with 0.0.
          
    Args:
        label_col: The column to use as the label (e.g., 'vegan').
        interest_col: The column to use as the interest (e.g., 'item_price').
        qty_col: The column to use as the quantity (e.g., 'item_quantity').
    """
    res = (
        df
        .join(
            [rolling_window_sum(df, label_col, interest_col, f'{label_col}_window_sum_{interest_col}', lookback_period, lookback_unit),
             rolling_window_sum(df, label_col, qty_col, f'{label_col}_window_sum_{qty_col}', lookback_period, lookback_unit)],
            how='left')
        .assign(**{
            f'{label_col}_window_avg_{interest_col}': lambda df: ( # ex. output name: 'meat_window_avg_item_price'
                df[f'{label_col}_window_sum_{interest_col}'] # start with the rolling sum of the col of interest
                .div(df[f'{label_col}_window_sum_{qty_col}']) # div is the same as /
                .ffill() # prevent data leakage by propagating past values forward
                .fillna(0.0))}))
    return res


def unroll(df):
    res = (
        df
        .reset_index()
        .loc[lambda df: df.index.repeat(df['item_quantity'])]
        .assign(item_quantity = 1)
        .set_index('created_at'))
    return res


def add_intraday_variables(df):
    hour_mapping = {
        22: -1, 
        23: -1, 
        1: -1, 
        6: -1, 
        7: -1}
    res = (
        df
        .assign(
            hour_of_day = lambda df: df.index.to_series().dt.hour.replace(hour_mapping),
            day_of_week = lambda df: df.index.to_series().dt.dayofweek,
            weekend = lambda df: pd.Series(df.index.dayofweek.isin([5, 6]).astype(int), index=df.index),
            meal_period = lambda df: pd.cut(
                df.index.to_series().dt.hour.astype("category"), 
                bins=[0, 5, 11, 16, 22, 24], 
                labels=['Late', 'Breakfast', 'Lunch', 'Dinner', 'Late'], 
                right=False,
                ordered=False).astype(str).replace({'Late': 'Dinner'}))
        .astype({
            'hour_of_day':'category',
            'day_of_week':'category',
            'weekend':'category',
            'meal_period':'category'}))
    return res


def season_from_month(month: int) -> str:
    """
    Map a month (1-12) to its corresponding season.
    """
    res = {
        12: 'winter', 1: 'winter', 2: 'winter',
        3: 'spring', 4: 'spring', 5: 'spring',
        6: 'summer', 7: 'summer', 8: 'summer',
        9: 'fall', 10: 'fall', 11: 'fall'}
    return res.get(month, 'unknown')


def add_interday_variables(df):
    res = (
        df    
        .assign(
            day_of_month = lambda df: df.index.day.astype("int16"),
            month = lambda df: df.index.month.astype("int16"),
            season = lambda df: df.index.month.map(season_from_month),
            year = lambda df: df.index.year.astype("int16"),
            date = lambda df: df.index.date)
        .astype({
            "day_of_month": "category",
            "month": "category",
            "season": "category",
            "year": "category",
            "date": "category"})
        .assign(
            month_code = lambda df: df["month"].cat.codes,
            year_code = lambda df: df["year"].cat.codes,
            date_code = lambda df: df["date"].cat.codes))
    return res


if __name__ == "__main__":
    ipytest.clean()
    ipytest.run('-q', '--tb=short', 'src/foodcast/tools/tests/test_rolling.py')