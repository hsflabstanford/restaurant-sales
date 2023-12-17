import pandas as pd

class FilterDF:
    """
    A class for filtering Pandas DataFrames.
    """

    def __init__(self, dataframe):
        """
        Initialize with a DataFrame.
        """
        self.df = dataframe

    def filter(self, column, multikey, exclude=False):
        """
        Apply a filter to a DataFrame based on a single column and a multikey.
        Handles both single keys and lists of keys.
    
        Parameters:
        column: The column name/number to apply the filter on. Must be a valid column in the DataFrame.
        multikey: A single key, or a list of keys to filter by. If the column is a string type, comparisons are case-insensitive.
        exclude: Boolean flag to determine if the keys should be excluded instead of included.
    
        Returns:
        DataFrame: The filtered DataFrame.
    
        Raises:
        ValueError: If the column is not in the DataFrame or if the multikey type is not supported.
        """
    
        # Input validation
        if column not in self.df.columns:
            raise ValueError(f"Column '{column}' not found in DataFrame.")
        if not isinstance(multikey, (list, str, int, float)):
            raise ValueError("Multikey must be a list, string, integer, or float.")
    
        # Copy df to prevent unintended modifications
        df = self.df.copy()
    
        # Determine if the column is of string type for case-insensitive comparison
        is_string_column = pd.api.types.is_string_dtype(df[column])
    
        # Adjust multikey based on column data type
        if is_string_column:
            if isinstance(multikey, list):
                multikey = [str(key).lower() for key in multikey]
            else:
                multikey = str(multikey).lower()
    
        # Build the condition
        if isinstance(multikey, list):
            condition = df[column].str.lower().isin(multikey) if is_string_column else df[column].isin(multikey)
        else:
            condition = df[column].str.lower() == multikey if is_string_column else df[column] == multikey
    
        # Apply the condition, considering exclusion
        df = df[~condition] if exclude else df[condition]
    
        return df

    def exclude(self, column, multikey):
        """
        Apply a filter to a DataFrame based on a single column and a multikey, exclude rows in the dataframe where the column equals the given key.
        Handles both single keys and lists of keys.
    
        Parameters:
        column: The column name/number to apply the filter on. Must be a valid column in the DataFrame.
        multikey: A single key, or a list of keys to filter by. If the column is a string type, comparisons are case-insensitive.
    
        Returns:
        DataFrame: The filtered DataFrame.
    
        Raises:
        ValueError: If the column is not in the DataFrame or if the multikey type is not supported.
        """
    
        # Input validation
        if column not in self.df.columns:
            raise ValueError(f"Column '{column}' not found in DataFrame.")
        if not isinstance(multikey, (list, str, int, float)):
            raise ValueError("Multikey must be a list, string, integer, or float.")
    
        # Copy df to prevent unintended modifications
        df = self.df.copy()
    
        # Determine if the column is of string type for case-insensitive comparison
        is_string_column = pd.api.types.is_string_dtype(df[column])
    
        # Adjust multikey based on column data type
        if is_string_column:
            if isinstance(multikey, list):
                multikey = [str(key).lower() for key in multikey]
            else:
                multikey = str(multikey).lower()
    
        # Build the condition
        if isinstance(multikey, list):
            condition = df[column].str.lower().isin(multikey) if is_string_column else df[column].isin(multikey)
        else:
            condition = df[column].str.lower() == multikey if is_string_column else df[column] == multikey
    
        # Apply the condition, considering exclusion
        df = df[~condition]
    
        return df
    
    def multi_filter(self, column_multikey_pairs, exclude=False):
        """
        Apply filters to a DataFrame based on columns and multikeys. Handles a mix of single keys and lists of keys.

        Parameters:
        column_multikey_pairs: A list of tuples, where each tuple contains a column name/number and a multikey.
                               A multikey can be a single key or a list of keys.
        exclude: Boolean flag to determine if the keys should be excluded instead of included.

        Returns:
        DataFrame: The filtered DataFrame.

        Raises:
        ValueError: If a column is not in the DataFrame or if the multikey type is not supported.
        """

        # Copy df to prevent unintended modifications
        df = self.df.copy()

        for column, multikey in column_multikey_pairs:
            # Input validation
            if column not in df.columns:
                raise ValueError(f"Column '{column}' not found in DataFrame.")
            if not isinstance(multikey, (list, str, int, float)):
                raise ValueError("Multikey must be a list, string, integer, or float.")

            # Determine if the column is of string type for case-insensitive comparison
            is_string_column = pd.api.types.is_string_dtype(df[column])

            # Adjust multikey based on column data type
            if is_string_column:
                if isinstance(multikey, list):
                    multikey = [str(key).lower() for key in multikey]
                else:
                    multikey = str(multikey).lower()

            # Build the condition
            if isinstance(multikey, list):
                condition = df[column].str.lower().isin(multikey) if is_string_column else df[column].isin(multikey)
            else:
                condition = df[column].str.lower() == multikey if is_string_column else df[column] == multikey

            # Apply the condition, considering exclusion
            df = df[~condition] if exclude else df[condition]

        return df

    def multi_exclude(self, column_multikey_pairs):
        """
        Apply exclusion filters to a DataFrame based on columns and multikeys. Handles a mix of single keys and lists of keys.

        Parameters:
        column_multikey_pairs: A list of tuples, where each tuple contains a column name/number and a multikey.
                               A multikey can be a single key or a list of keys.

        Returns:
        DataFrame: The filtered DataFrame.

        Raises:
        ValueError: If a column is not in the DataFrame or if the multikey type is not supported.
        """

        # Copy df to prevent unintended modifications
        df = self.df.copy()

        for column, multikey in column_multikey_pairs:
            # Input validation
            if column not in df.columns:
                raise ValueError(f"Column '{column}' not found in DataFrame.")
            if not isinstance(multikey, (list, str, int, float)):
                raise ValueError("Multikey must be a list, string, integer, or float.")

            # Determine if the column is of string type for case-insensitive comparison
            is_string_column = pd.api.types.is_string_dtype(df[column])

            # Adjust multikey based on column data type
            if is_string_column:
                if isinstance(multikey, list):
                    multikey = [str(key).lower() for key in multikey]
                else:
                    multikey = str(multikey).lower()

            # Build the condition
            if isinstance(multikey, list):
                condition = df[column].str.lower().isin(multikey) if is_string_column else df[column].isin(multikey)
            else:
                condition = df[column].str.lower() == multikey if is_string_column else df[column] == multikey

            # Apply the exclusion condition
            df = df[~condition]

        return df

    def date_range(self, start, end, column=False):
        """
        Filter by a date range in a column.
        """

        # Copy df to prevent unintended modifications
        df = self.df.copy()

        # Check if we are filtering over a column or an index
        if column:
            df = df[(df[column] >= start) & (df[column] <= end)]
        else:
            df = df[(df.index >= start) & (df.index <= end)]

        return df

    def above(self, column, threshold):
        """
        Filter values above a threshold in a column.
        """
        # Copy df to prevent unintended modifications
        df = self.df.copy()
        return df[df[column] > threshold]

    def below(self, column, threshold):
        """
        Filter values above a threshold in a column.
        """
        # Copy df to prevent unintended modifications
        df = self.df.copy()
        return df[df[column] < threshold]

    def substring(self, column, sub):
        """
        Filter by substring in a column.
        """
        # Copy df to prevent unintended modifications
        df = self.df.copy()
        return df[df[column].str.contains(sub, na=False)]

    def remove_na(self, column):
        """
        Filter out nulls in a column.
        """
        # Copy df to prevent unintended modifications
        df = self.df.copy()
        return df[df[column].notnull()]

    def custom(self, column, func):
        """
        Apply a custom lambda function to a column.
        """
        # Copy df to prevent unintended modifications
        df = self.df.copy()
        return df[df[column].apply(func)]