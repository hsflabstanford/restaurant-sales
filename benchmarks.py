def num_dishes_for_percentile_of_order_quanity(df, percentile=0.9, tolerance=0.01):

    # Prevent overwriting
    df = df.copy()

    # Get a list of sorted quantities, grouped by item name
    sorted_quantities = df.groupby('item_name')['item_quantity'].sum().sort_values(ascending=False)
    total_quantity_ordered = sorted_quantities.sum()
    sorted_fractions = sorted_quantities.cumsum() / total_quantity_ordered

    # Start a binary search on the sorted cumulative fraction of quantity ordered
    num_rows = sorted_fractions.shape[0]
    i = delta = num_rows // 4
    fraction_of_orders = 0

    # Record the start time as a fail safe
    start_time = time.time()
    max_duration = 3
    
    # Have the terminate condition be when we have reached the correct percentile of orders (since this is not an exact binary search)
    while abs(fraction_of_orders - percentile) > tolerance:

        # print(i)
        # print(fraction_of_orders)
        # print(abs(fraction_of_orders - percentile))
        # print("\n")
        
        # Track the previous index for breaking the loop if necessary
        prev_i = i

        # Update delta only if we can make it smaller, otherwise keep searching by keeping delta = 1
        if 1 < delta:
            delta //= 2
            
        # Adjust the binary search depending on if we undershot or overshot
        if fraction_of_orders < percentile:
            i += delta
        else:
            i -= delta

        # Exit the loop if we can get no closer to the given percentile
        if i == prev_i:
            break
        
        # Check the time elapsed
        current_time = time.time()
        if current_time - start_time > max_duration:
            print("Loop has run too long, exiting.")
            break

        # Retrieve the current fraction at the index
        fraction_of_orders = sorted_fractions.iloc[i]
    
    return i, num_rows

if __name__ == "__main__":
    
    list_of_num_dishes = []

    # Determine the number of menu items for all 30 restaurants
    for loc_id in location_ids:
        menu_items = items_tagged_fdf.filter('location_id', loc_id).drop_duplicates('id')
        sales_no_alcohol = FilterDF(merged_sales_and_menu[loc_id]).filter('dish_category', 'Alcohol', exclude=True)
        list_of_num_dishes.append(num_dishes_for_percentile_of_order_quanity(sales_no_alcohol, percentile=0.9, tolerance=0.01))

    num_dishes_required_90 = pd.DataFrame(list_of_num_dishes)
    print(num_dishes_required_90[0].sum())
    print(num_dishes_required_90[0].mean())
    num_dishes_required_90