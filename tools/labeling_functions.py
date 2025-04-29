# Public packages
import numpy as np
import pandas as pd
import os
from pathlib import Path
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
import matplotlib.cm as cm


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
                                  unknown=None):

    df = (df
          .pipe(lambda df: df.loc[~df['item_name'].isin(remove)] if remove is not None else df) 
          .pipe(lambda df: rename_items(df, name_changes) if name_changes is not None else df)
          .pipe(lambda df: rename_items_by_modifications(df, modification_name_changes) if modification_name_changes is not None else df)
          .pipe(lambda df: relabel_items(df, vegan_list, vegetarian_list, meat_list, drinks_list, alcohol_list, half_vegan_list) if any(l is None for l in [vegan_list, vegetarian_list, meat_list, drinks_list, alcohol_list, half_vegan_list]) else df)
          .pipe(lambda df: recategorize_items(df, drinks_list, alcohol_list, unknown, merch, rare) if any(l is None for l in [drinks_list, alcohol_list, unknown, merch, rare]) else df)
         )
    return df


def plot_dish_time_series(df, loc_id, before_after_details_true, scale=50):

    introduction_fig, ax = plt.subplots(figsize=(14, 8))

    promo_datetime = before_after_details_true.loc[loc_id,'cross_over_date'].tz_convert('UTC')

    top_n = 60

    unique_dishes = (df
                    ['item_name']
                    .value_counts()
                    .to_frame(name='c')
                    [:top_n]
                    .index[::-1]
                    )

    legend_handles = []

    for dish in unique_dishes:
        
        dish_df = df.loc[df['item_name'] == dish]
        
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