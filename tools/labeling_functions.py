# Public packages
import numpy as np
import pandas as pd
import os
from pathlib import Path
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
import matplotlib.cm as cm
from matplotlib.ticker import FuncFormatter


def find_project_root(start: Path = Path().absolute()) -> Path:
    for parent in start.parents:
        if (parent / "requirements.txt").exists(): 
            return parent
    return start

try:
    PROJECT_ROOT = find_project_root()
    os.chdir(PROJECT_ROOT)
    print(f"Changed working directory to: {PROJECT_ROOT}")
except Exception as e:
    print(f"Could not set project root: {e}")


def remove_numbers(df, col_name):
    
    df[col_name] = df[col_name].str.strip('123456789./\\ ')


def rename_items(df, name_changes):
    
    name_changes_flipped = {variant: canonical for canonical, variants in name_changes.items() for variant in variants}
    df = df.assign(item_name = lambda df: df['item_name'].replace(name_changes_flipped))
    return df


def rename_items_by_modifications(df, modification_name_changes):

    modification_name_changes_df = pd.DataFrame(data = modification_name_changes, columns = ['name', 'modification', 'new_name'])  
    df = df.assign(item_name = lambda df: 
        np.select(condlist = [df['item_name'].eq(name) & df['item_modifications'].str.contains(modification) for name, modification, _ in modification_name_changes],
                  choicelist = modification_name_changes_df['new_name'].tolist(),
                  default = df['item_name']))
    return df


def relabel_items(df, vegan_list=None, vegetarian_list=None, meat_list=None, drinks_list=None, alcohol_list=None, half_vegan_list=None):
    
    if vegan_list is None:
        vegan_list = []
    if vegetarian_list is None:
        vegetarian_list = []
    if meat_list is None:
        meat_list = []
    if drinks_list is None:
        drinks_list = []
    if alcohol_list is None:
        alcohol_list = []
    if half_vegan_list is None:
        half_vegan_list = []
    
    vegetarian_food_and_drink = vegetarian_list + vegan_list + drinks_list + alcohol_list
    vegan_food_and_drink = vegan_list + drinks_list + alcohol_list
    df = df.assign(meat = lambda df: (df['is_plant_based']
                                      .eq('No')
                                      .mask(df['item_name'].isin(vegetarian_food_and_drink), False)
                                      .mask(df['item_name'].isin(meat_list), True)),
                   vegetarian = lambda df: (df['is_plant_based']
                                           .eq('Yes')
                                           .mask(df['item_name'].isin(vegetarian_food_and_drink), True)
                                           .mask(df['item_name'].isin(meat_list), False)),
                  vegan = lambda df: (df['is_plant_based']
                                      .eq('Yes')
                                      .mask(df['item_name'].isin(vegan_food_and_drink), True)
                                      .mask(df['item_name'].isin(vegetarian_list) & ~df['item_name'].isin(vegan_list), False)
                                      .mask(df['item_name'].isin(meat_list), False)
                                      .mask(df['item_name'].isin(half_vegan_list), np.random.rand(len(df)) < 0.5)))
    return df


def recategorize_items(df, drinks_list, alcohol_list, unknown_list, merch_list, rare_list):
    
    if drinks_list is None:
        drinks_list = []
    if alcohol_list is None:
        alcohol_list = []
    if unknown_list is None:    
        unknown_list = []
    if merch_list is None:
        merch_list = []
    if rare_list is None:
        rare_list = []
    
    df = df.assign(dish_category = lambda df: (df['dish_category']
                                               .mask(df['item_name'].isin(drinks_list), 'Drink')
                                               .mask(df['item_name'].isin(unknown_list), 'Unknown')
                                               .mask(df['item_name'].isin(merch_list), 'Merch')
                                               .mask(df['item_name'].isin(rare_list), 'Rare')
                                               .mask(df['item_name'].isin(alcohol_list), 'Alcohol')))
    return df


def fully_relabel_and_consolidate(df,
                                  remove=None,
                                  name_changes=None,
                                  modification_name_changes=None,
                                  vegan_list=None,
                                  vegetarian_list=None,
                                  meat_list=None,
                                  drinks_list=None,
                                  alcohol_list=None,
                                  half_vegan_list=None,
                                  merch=None,
                                  rare=None,
                                  unknown=None,
                                  remove_categories=None):

    res = (df
          .pipe(lambda df_: df_.query('~item_name.isin(@remove)') if remove is not None else df_) 
          .pipe(lambda df_: rename_items(df_, name_changes) if name_changes is not None else df_)
          .pipe(lambda df_: rename_items_by_modifications(df_, modification_name_changes) if modification_name_changes is not None else df_)
          .pipe(lambda df_: relabel_items(df_, vegan_list, vegetarian_list, meat_list, drinks_list, alcohol_list, half_vegan_list) if not all(l is None for l in [vegan_list, vegetarian_list, meat_list, drinks_list, alcohol_list, half_vegan_list]) else df_)
          .pipe(lambda df_: recategorize_items(df_, drinks_list, alcohol_list, unknown, merch, rare) if not all(l is None for l in [drinks_list, alcohol_list, unknown, merch, rare]) else df_)
          .pipe(lambda df_: df_.query('~dish_category.isin(@remove_categories)') if remove_categories is not None else df_)
         )
    return res


def plot_dish_time_series(df, loc_id, before_after_details_true, top_n=60, scale=50, legend=False, legend_label="", legend_min=0, legend_max=10, shift_adjustment=0):

    introduction_fig, ax = plt.subplots(figsize=(14, 8))

    promo_datetime = before_after_details_true.loc[loc_id,'cross_over_date'].tz_convert('UTC')

    unique_dishes = (df
                    ['item_name']
                    .value_counts()
                    .to_frame(name='c')
                    [:top_n]
                    .index[::-1]
                    )

    legend_handles = []

    for dish in unique_dishes:
        
        dish_df = df.query('item_name == @dish')
        
        vmin = dish_df['unit_price'].min()
        vmax = dish_df['unit_price'].max()
        norm = mcolors.Normalize(vmin=vmin, vmax=vmax)
        cmap = cm.ScalarMappable(norm=norm, cmap='magma')
        
        weekly_quantities = (dish_df
                            .resample('W')
                            .agg({'item_quantity': 'sum', 'unit_price': 'mean'})
                            .query('0 < item_quantity')
                            .assign(week = lambda df: df.index.tz_localize(None).to_period('W'))
                            .set_index('week')
                            )
        
        # For every active week
        for week, row  in weekly_quantities.iterrows():
            weekly_quantity = row['item_quantity']
            dot_size = weekly_quantity/scale + 2.5
            weekly_price = row['unit_price']
            color = cmap.to_rgba(weekly_price)

            # Place a blue dot
            ax.hlines(y=dish, xmin=week.start_time, xmax=week.end_time, colors=color, lw=dot_size, label=loc_id)
            
        ax.text(x=df.index[-1] + pd.DateOffset(100), y=dish, s=f'${vmin/100:.2f}-${vmax/100:.2f}', verticalalignment='center', horizontalalignment='left', fontsize='x-small', color='gray')

    # Place a red vertical line for the promotional item
    ax.axvline(promo_datetime, color='red', linestyle='--', alpha=0.5)

    if legend:
        # Legend colorbar

        norm_global = mcolors.Normalize(vmin=legend_min, vmax=legend_max)
        sm = cm.ScalarMappable(norm=norm_global, cmap='magma')
        sm.set_array([])

        base_pos = [0.88, 0.1, 0.02, 0.3]

        # Calculate the normalized shift for a desired shift in inches.
        # Figure width in inches:
        fig_width = introduction_fig.get_size_inches()[0]
        shift_inches = 2.5  # change this value for a different shift
        normalized_shift = shift_inches / fig_width

        # Shift the colorbar to the left by subtracting the normalized shift from the x coordinate.
        adjusted_pos = [base_pos[0] - normalized_shift, base_pos[1] + normalized_shift*shift_adjustment, base_pos[2], base_pos[3]]

        # Create the colorbar axis at the adjusted position.
        cbar_ax = introduction_fig.add_axes(adjusted_pos)
        cbar = plt.colorbar(sm, cax=cbar_ax, orientation='vertical')

        # Set a custom tick formatter to show ticks divided by 100 (as dollars)
        def dollar_formatter(x, pos):
            return f'${x:.2f}'

        cbar.ax.yaxis.set_major_formatter(FuncFormatter(dollar_formatter))
        # Set the colorbar "title"
        cbar.set_label(legend_label)

    # Plot
    ax.set_title(f'Weekly Sales of Top {top_n} Dishes for {loc_id}')
    ax.set_xlabel('Date')
    ax.set_ylabel('Dish')
    #ax.legend(handles=legend_handles, title="Price Range per Dish", fontsize='small', loc='upper left', bbox_to_anchor=(1, 1))

    # Figure
    introduction_fig.tight_layout(rect=[0, 0, 0.85, 1])

    plt.show()
    

def dish_time_series(df, top_n=60):

    # Ensure necessary columns exist
    required_cols = ['item_name', 'item_quantity']
    if not all(col in df.columns for col in required_cols):
        raise ValueError(f"Input DataFrame must contain columns: {required_cols}")

    # Ensure we have a DatetimeIndex
    if not isinstance(df.index, pd.DatetimeIndex):
        raise TypeError("Input DataFrame must have a DatetimeIndex or a recognizable date column.")

    # Identify and filter for Top N Dishes, then Group, Aggregate, and Reshape
    top_dishes = df['item_name'].value_counts().head(top_n).index.tolist()
    weekly_sales = (df
                   .query('item_name.isin(@top_dishes)')
                   .groupby([pd.Grouper(freq='W'), 'item_name'])
                   ['item_quantity']
                   .sum() 
                   .unstack(level='item_name')
                   .rename_axis('Week', axis='index')
                   .reindex(columns=top_dishes)
                   #.fillna(0)
                   )

    return weekly_sales