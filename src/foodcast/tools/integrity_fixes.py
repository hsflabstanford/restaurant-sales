import pandas as pd
import numpy as np
import os

class DataFixer:

    def __init__(self, df, location_id=''):
        """
        Initialize with a DataFrame.
        """
        self.df = df.copy()
        #self.primary_key = primary_key
        self.location_id = location_id

    def find_nans(self):
        
        nans = self.df[(self.df['item_name'] == 'nan') or self.df['item_name'].isna()]
        
        return nans

    def find_exact_duplicates(self, primary_key):
        """
        Identifies sales rows that are exact duplicates in a restaurant sales dataframe.

        Args:
        df_ (DataFrame): Input DataFrame containing sales data.
        location_id: Identifier for the location.

        Returns:
        Tuple[DataFrame, list]: A tuple containing a DataFrame of near duplicates and a list of summaries.
        """

        # Exact duplicates and duplicates by id

        # Keep as DataFrame, not Series
        ids = self.df[primary_key]

        # Mark the first instance of an item with duplicates as true, even though it technically isn't a duplicate
        # This will ensure we keep at least one copy when we drop duplicates to determine the unique list of items that have duplicates
        exact_duplicates_mask = self.df.duplicated(keep=False) 
        id_duplicates_mask = ids.duplicated(keep=False)
        
        # Filter to the duplicated rows (or ids), keeping each instance of the duplicates
        exact_duplicates = self.df[exact_duplicates_mask] 
        id_duplicates = ids[id_duplicates_mask]

        # Now drop the duplicates, except for the first instance (the keep argument defaults to True)
        exact_duplicates_unique = exact_duplicates.drop_duplicates()
        id_duplicates_unique = id_duplicates.drop_duplicates()

        # How many rows (or ids) have duplicates?
        exact_duplicate_count = exact_duplicates_unique.shape[0] 
        id_duplicate_count = id_duplicates_unique.shape[0]
        
        # Separately as a summary statistic, how many exact (or id) duplicates are there?
        exact_duplicate_total = self.df.duplicated().sum()
        id_duplicate_total = ids.duplicated().sum()

        # Are there non exact duplicates? Note, the number of id duplicates will always be more than the number of perfect duplicates (perfect duplicates are a subset of id duplicates)
        non_exact_id_duplicates_exist = (exact_duplicate_count != id_duplicate_count and 
                                         exact_duplicate_total != id_duplicate_total)

        non_exact_id_duplicates = []
        if non_exact_id_duplicates_exist:

            exact_duplicate_rows = set(exact_duplicates.index.tolist())
            id_duplicate_rows = set(id_duplicates.index.tolist())
            non_exact_id_duplicates = list(id_duplicate_rows.difference(exact_duplicate_rows))

        # Label
        exact_duplicates.columns.name = self.location_id
        id_duplicates.columns.name = self.location_id

        # Prepare a row of summary values
        summary = {
            'location_id': self.location_id,
            'exact_duplicate_count': exact_duplicate_count,
            'exact_duplicate_total': exact_duplicate_total,
            'non_exact_id_duplicates_count': id_duplicate_count - exact_duplicate_count,
            'non_exact_id_duplicates_total': id_duplicate_total - exact_duplicate_total,
            'rows_delivered': self.df.shape[0],
            'unique_rows_received': self.df.shape[0] - exact_duplicate_total
        }
        
        return exact_duplicates_unique, id_duplicates_unique, non_exact_id_duplicates, summary
    

    def find_pricing_discrepancies(self, threshold = 2):
        """
        Identifies items with distinct unit prices in a restaurant sales dataframe.

        Args:
        df_ (DataFrame): Input DataFrame containing sales data.
        location_id: Identifier for the location.

        Returns:
        Tuple[DataFrame, list]: A tuple containing a DataFrame of items with distinct unit prices and a list of summaries.
        """
        
        # Define the threshold for considering prices as distinct (in this case, 2 cents)
        # Find duplicate unit prices and near-duplicate unit prices and remove

        # Backup the dataframe since we don't want the instance variable sorted
        df = self.df.copy()

        # Filter to items with distinct unit prices        
        distinct_unit_price_counts = df.groupby('item_name')['unit_price'].nunique()
        items_with_distinct_unit_prices = distinct_unit_price_counts[distinct_unit_price_counts > 1].index.tolist()
        df = df[df['item_name'].isin(items_with_distinct_unit_prices)]

        # Sort so that we can compare the prices within a single item that are closest
        sorted_df = df.sort_values(['item_name', 'unit_price'])

        # Within each item, take the sequential difference and then make each positive
        sorted_df['price_diff'] = sorted_df.groupby('item_name')['unit_price'].diff().abs()

        # Filter to items above the threshold (and filter items of the same name that have roughly the same price, i.e., within 2 cents)
        # The first item in a sequential difference will always be NA so include it by including NA
        distinct_unit_prices_data = sorted_df[(sorted_df['price_diff'].isna() | (sorted_df['price_diff'] >= threshold))]
        
        # Label
        distinct_unit_prices_data.columns.name = self.location_id
        
        # Determine which items have multiple prices (with price differences greater than 2 cents) and filter to only those
        same_items_different_prices_count = distinct_unit_prices_data['item_name'].nunique()
        same_items_different_prices_total = distinct_unit_prices_data.shape[0] -  same_items_different_prices_count

        # Prepare a row of summary values
        summary = {
            'location_id' : self.location_id, 
            'distinct_unit_prices_count' : same_items_different_prices_count, 
            'distinct_unit_prices_total' : same_items_different_prices_total
        }    
        
        return distinct_unit_prices_data, items_with_distinct_unit_prices, summary
    

    def find_capitalization_duplicates(self):

        # Determine how many unique items there are if you force a certain capitalization
        summary = {
            'location_id' : self.location_id,
            'num_of_items_case_sens' : self.df['item_name'].unique().size,
            'num_of_items_not_case_sens' : self.df['item_name'].str.lower().unique().size,
            'difference' : self.df['item_name'].unique().size - self.df['item_name'].str.lower().unique().size
        }

        return summary


    def find_fractional_quantities(self):

        frac = self.df[~self.df['item_quantity'].astype(str).str.contains(".0")]

        return frac


    def remove_nans(self, col='item_name'):

        # Filter out rows where col is a string nan
        self.df = self.df[~(self.df[col] == 'nan')]

        # Filter out rows where col is nan
        self.df.dropna(subset=[col], inplace=True)


    def remove_exact_duplicates(self):
        self.df.drop_duplicates(inplace=True)


    def remove_capitalization_duplicates(self, primary_key):
        for col in primary_key:
            self.df[col] = self.df[col].str.title()
        self.df.drop_duplicates(subset=primary_key, inplace=True)


    def get_df(self):
        return self.df


class DataExporter:

    @staticmethod
    def export_csv(df, path):
        if not os.path.exists(path):
            df.to_csv(path)

    @staticmethod
    def export_excel(df, path, sheet_name='summary'):
        if not os.path.exists(path):
            with pd.ExcelWriter(path) as writer:
                df.to_excel(writer, sheet_name=sheet_name)

    @staticmethod
    def export_list(df_dict, path):
        if not os.path.exists(path):
            with pd.ExcelWriter(path) as writer:
                for loc_id, df in df_dict:
                    df.index = df.index.astype(str)
                    df.to_excel(writer, sheet_name=loc_id)