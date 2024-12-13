# Public packages
import numpy as np
import pandas as pd
import time

# Custom packages
from tools.filter import FilterDF as fdf

class ParetoAnalysis:  
    """
    A class for creating percentiles and from that determining the number of top items required to account for a large percentage of a metric
    Ex. The top ten items ordered by quantity account for 90% of sales
    """  

    @staticmethod
    def create_percentiles(df, to_groupby='item_name', to_aggregate='item_quantity', metric='sales'):
        """
        Calculate percentiles by grouping items by name, and sorting them as a percentage of a metric
        Possible metrics: entries (aka times sold), quantity (aka quantity sold), or sales 
    
        Parameters:
        df (DataFrame): Data (probably containing restaurant sales)
        to_groupby (string): The variable by which we'll group things (probably item/dish name)
        to_aggregate (string): The variable we'll aggregate
        metric (string): The metric that determines how to aggregate the to_aggregate variable, and will be one of: 'entries', 'quantity', or 'sales'

        Returns:
        Series: A list of sorted fractions that can be interpreted as percentiles of the metric
        """
            
        # Prevent overwriting
        df = df.copy()

        # Counts the times an item sold
        if metric == 'entries':
            sorted_quantities = df.groupby(to_groupby)[to_aggregate].count().sort_values(ascending=False)
        # Sums up the quantity sold of the item
        elif metric == 'quantity':
            sorted_quantities = df.groupby(to_groupby)[to_aggregate].sum().sort_values(ascending=False)
        # Defaults to aggregating sales if no other/incorrect input, with 'item_price' already representing the sale for an entry (not actually an individual item/dish)
        else:
            sorted_quantities = df.groupby(to_groupby)['item_price'].sum().sort_values(ascending=False)
        
        # Turn into percentiles of the metric
        total_quantity = sorted_quantities.sum()
        percentiles = sorted_quantities.cumsum() / total_quantity
        
        return percentiles


    @staticmethod
    def approximate_binary_search(sorted_fractions, goal=0.9, tolerance=0.01):
        """
        Perform an approximate binary search to locate a goal fraction from a monotonically increasing list of fractions within a tolerance
        
        Parameters:
        sorted_fractions (Series): The sorted input list, as a Pandas Series
        goal (float): The goal fraction we are trying to locate
        tolerance (float): The precision tolerance
        
        Returns:
        int: The index at which the first number to a certain precision of the goal is
        """

        # Start a binary search on the sorted fractions
        low, high = 0, sorted_fractions.shape[0] - 1
        # Initialize with None to indicate no index has been found yet
        closest_index = None  
        # Initialize with infinity as the distance to beat
        closest_distance = float('inf')  

        # Have the loop terminate regardless, and just print out a message if we didn't reach 'goal' within 'tolerance'
        while low <= high:
            mid = (low + high) // 2
            mid_val = sorted_fractions.iloc[mid]
            distance = abs(mid_val - goal)

            # Update the closest index if this value is closer to the goal than any previously found
            if distance < closest_distance:
                closest_index = mid
                closest_distance = distance

            # Adjust search range based on comparison with the goal
            if mid_val < goal:
                low = mid + 1
            else:
                high = mid - 1

        # After exiting the loop, check if the closest distance found meets the tolerance criteria
        if closest_distance > tolerance:
            print(f"The closest value found is not within the specified tolerance of {tolerance}. Closest value: {sorted_fractions.iloc[closest_index]}, Index: {closest_index}")

        return closest_index
    

    @staticmethod
    def num_items_to_cover_certain_percentage(df, to_groupby='item_name', to_aggregate='item_quantity', metric='sales', percentile=0.9, tolerance=0.01):
        """
        Parameters:
        percentile: The desired percentile of the metric for which we want to account for
        tolerance: In approximate binary search, how close do we need to be this is desired percentile
        
        Returns:
        int: The number of items required to account for the desired percentage of the metric
        """

        # Create the percentiles
        percentiles = ParetoAnalysis.create_percentiles(df, to_groupby, to_aggregate, metric)

        # Binary search on the percentiles
        num_required_to_cover = ParetoAnalysis.approximate_binary_search(percentiles, goal=percentile, tolerance=tolerance)

        return num_required_to_cover
 

    if __name__ == "__main__":
        pass


# Fixed global seed
global_seed = 57575757

class AccuracyCalculation:

    @staticmethod
    def calculate_accuracy(top_items, menu, n_sample=10):
        """
        Parameters:
        items (Series): The top items by metric (e.g., times ordered, quantity ordered, sales) to sample from
        """
        
        np.random.seed(seed=global_seed)

        # Prevent overwriting
        menu = menu.copy()
        
        # Sample the indices of the items
        sample_items = np.random.choice(top_items.index, n_sample)

        # Filter the menu to the sampled items
        sample_menu_rows = fdf(menu).filter('item_name', sample_items.tolist())

        # For debugging
        # print(sample_items)

        return sample_menu_rows

    if __name__ == "__main__":
        pass