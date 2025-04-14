# Public packages
import numpy as np
import pandas as pd
from tqdm import tqdm
import itertools
import math
import os
import re
from pathlib import Path
import tabulate
from IPython.display import display, Markdown
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
import matplotlib.cm as cm
import matplotlib.patches as mpatches
import seaborn as sns

# Set directory to project root
def find_project_root(start: Path = Path().absolute()) -> Path:
    for parent in start.parents:
        if (parent / "requirements.txt").exists(): return parent
    return start 
os.chdir(find_project_root())

#before_after_details_true = pd.read_csv('data/before_after_details_true.csv').set_index('location_id')

def clean_and_relabel_restaurant(df, 
                                 modification_name_changes,
                                 vegan_list,
                                 vegetarian_list,
                                 meat_list,
                                 half_vegan_list,
                                 alcoholic_drinks,
                                 non_alcoholic_drinks,
                                 merch_list, 
                                 rare_list,
                                 unknown_list, 
                                 remove_list,
                                 name_changes=None):

    if name_changes is not None:
        name_changes_dict = {variant: canonical for canonical, variants in name_changes.items() for variant in variants}
    else:
        name_changes_dict = {}
    
    modification_name_changes_df = pd.DataFrame(data = modification_name_changes, 
                                                columns = ['name', 'modification', 'new_name'])

    df = (df
          .assign(item_name = lambda df: df['item_name']
                  .str.strip('123456789./\\ ')  # Clean up item names
                  .replace(name_changes_dict)
                  )
          .assign(item_name = lambda df: np.select(condlist = [df['item_name'].eq(name) &  
                                                               df['item_modifications'].str.contains(modification) for name, modification, _ in modification_name_changes],
                                                   choicelist = modification_name_changes_df['new_name'].tolist(),
                                                   default = df['item_name']),
                  dish_category = lambda df: (df['dish_category']
                                              .mask(df['item_name'].isin(non_alcoholic_drinks), 'Drink')
                                              .mask(df['item_name'].isin(unknown_list), 'Unknown')
                                              .mask(df['item_name'].isin(merch_list), 'Merch')
                                              .mask(df['item_name'].isin(rare_list), 'Rare')
                                              .mask(df['item_name'].isin(alcoholic_drinks), 'Alcohol')),
                  vegetarian = lambda df: (df['is_plant_based']
                                           .eq('Yes')
                                           .mask(df['item_name'].isin(vegetarian_list + vegan_list + non_alcoholic_drinks), True)
                                           .mask(df['item_name'].isin(meat_list), False)),
                  vegan = lambda df: (df['is_plant_based']
                                      .eq('Yes')
                                      .mask(df['item_name'].isin(vegan_list + non_alcoholic_drinks), True)
                                      .mask(df['item_name'].isin(vegetarian_list) & ~df['item_name'].isin(vegan_list), False)
                                      .mask(df['item_name'].isin(meat_list), False)
                                      .mask(df['item_name'].isin(half_vegan_list), np.random.rand(len(df)) < 0.5)))
          .query('~item_name.isin(@remove_list)') # Important: do we actually want to remove unknowns
          #.query('~dish_category.isin(["Merch"])')
                #.drop('unique_id', axis=1)
                )
    
    #food_df = df.query('~dish_category.isin(["Alcohol", "Drink", "Merch", "Rare"])')
    
    return df

def plot_dish_time_series(food_df, loc_id, before_after_details_true):

    # Visualizing with gaps for inactive weeks
    introduction_fig, ax = plt.subplots(figsize=(14, 8))

    # Index into the promotional items for this restaurant
    promo_datetime = before_after_details_true.loc[loc_id,'cross_over_date'].tz_convert('UTC')

    top_n = 60

    unique_dishes = (food_df
                    ['item_name']
                    .value_counts()
                    .to_frame(name='c')
                    [:top_n]
                    .index[::-1]
                    )

    legend_handles = []

    for dish in unique_dishes:
        
        dish_df = food_df.query('item_name == @dish')
        
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
            dot_size = weekly_quantity/50 + 2.5
            weekly_price = row['unit_price']
            color = cmap.to_rgba(weekly_price)

            # Place a blue dot
            ax.hlines(y=dish, xmin=week.start_time, xmax=week.end_time, colors=color, lw=dot_size, label=loc_id)
            
        ax.text(x=food_df.index[-1] + pd.DateOffset(100), y=dish, s=f'${vmin/100:.2f}-${vmax/100:.2f}', verticalalignment='center', horizontalalignment='left', fontsize='x-small', color='gray')
        
        # Create a custom legend entry for this dish
        #color_patch_min = mpatches.Patch(color=cmap.to_rgba(vmin), label=f'{dish} Min: ${vmin/100:.2f}')
        #color_patch_max = mpatches.Patch(color=cmap.to_rgba(vmax), label=f'{dish} Max: ${vmax/100:.2f}')
        #legend_handles.extend([color_patch_min, color_patch_max])

    # Place a red vertical line for the promotional item
    ax.axvline(promo_datetime, color='red', linestyle='--', alpha=0.5)

    # Plot
    ax.set_title(f'Weekly Sales of Top {top_n} Dishes for {loc_id}')
    ax.set_xlabel('Date')
    ax.set_ylabel('Dish')
    #ax.legend(handles=legend_handles, title="Price Range per Dish", fontsize='small', loc='upper left', bbox_to_anchor=(1, 1))

    # Figure
    introduction_fig.tight_layout(rect=[0, 0, 0.85, 1])

    plt.show()