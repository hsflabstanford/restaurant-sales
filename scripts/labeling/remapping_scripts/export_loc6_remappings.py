#!/usr/bin/env python3
"""
Export script to generate loc6_remappings.yaml programmatically
This script contains all the hardcoded data and exports it to YAML format
Following the same pattern as loc1, loc2, and loc5
"""

import yaml
from pathlib import Path

def generate_loc6_remappings():
    """Generate the remappings dictionary programmatically"""
    
    # No item name consolidation needed for loc6 based on the notebook
    name_changes = {}

    # Extract modification name changes from the notebook data
    # Original format: (('item_name','modification','new_name'),('category'))
    modification_name_changes = [
        ('Avocado Toast','Egg','Egg Avocado Toast'),
        ('Pb & J','Collagen','Collagen Pb & J'),
        ('Collagen Pb & J','Collagen, Vegan','Pb & J'),
        ('Morning Mocha','Collagen|Whipped Cream','Whipped Cream Collagen Morning Mocha'),
        ('Whipped Cream Collagen Morning Mocha','Collagen, Vegan|Whipped Cream, Non-Dairy','Morning Mocha'),
        ('Acai','Collagen','Collagen Acai'),
        ('Pb & J Bowl','Collagen','Collagen Pb & J Bowl'),
        ('Collagen Pb & J Bowl','Collagen, Vegan','Pb & J Bowl'),
        ('Vegan Breakfast Sandwich','Egg|Regular Egg|Regular Cheese|Reg Egg|Real Scrambled Egg|Real Egg|Egg White','Veg Breakfast Sandwich'),
        ('Acai Smoothie Bowl','Collagen, Regular','Collagen Acai Smoothie Bowl'),
        ('Blueberry Thrill','Collagen, Regular','Collagen Blueberry Thrill'),
        ('Avocado Toast','Egg|Sunny','Egg Avocado Toast'),
        ('Buddha Bowl','Chicken','Chicken Buddha Bowl'),
        ('Buddha Bowl','Egg','Egg Buddha Bowl'),
        ('Beyond Burger','Regular Cheese|Reg Cheese','Cheese Beyond Burger'),
        ('Avocado Toast - Gf Available','Egg','Egg Avocado Toast'),
        ('Salads','Chicken','Chicken Salads'),
        ('Great Pumpkin Bowl','Dairy-Regular','Great Pumpkin Bowl (Dairy)'),
        ('Kale!  Ceasar Salad','Regular','Regular Kale! Cesar Salad'),
        ('Veggie Melt & Tomato Soup','Vegan','Vegan Veggie Melt & Tomato Soup'),
        ('Veggie Melt & Tomato Basil Soup','Vegan','Vegan Veggie Melt & Tomato Basil Soup'),
        ('Goddess Salad','Chicke','Chicken Goddess Salad'),
        ('Goddess Salad','Egg','Egg Goddess Salad'),
        ('Sw Burrito Wrap','Chicken|Egg','Chicken Sw Burrito Wrap'),
        ('Reuben-Vegan Or Regular','Turkey','Turkey Reuben-Vegan Or Regular'),
        ('Spinach Salad','Organic Chicken|Feta Cheese','Chicken Spinach Salad'),
        ('Apple Walnut Salad','Chicken|Egg','Chicken Apple Walnut Salad'),
        ('Green Goddess Salad Bowl','Chicken|Egg','Chicken Green Goddess Salad Bowl'),
        ('Reuben-Vegan(Tofu) Or Rachel(Turkey)','Turkey|Cheese','Turkey Reuben-Vegan(Tofu) Or Rachel(Turkey)'),
        ('Breakfast Bowl','Egg|Regular Cheddar|Regular Cheese|Mayo','Cheesy Breakfast Bowl W Egg '),
        ('Breakfast Bowl','Vegan','Vegan Breakfast Bowl'),
        ('Breakfast Wrap','Egg|Regular Cheese|Mayo','Eggy & Cheezy Breakfast Wrap'),
        ('Eggy & Cheezy Breakfast Wrap','No Egg','Breakfast Wrap'),
        ('Breakfast Wrap','Vegan','Vegan Breakfast Wrap'),
        ('Toasted Quesadilla','Organic Chicken|Regular Sour Cream|Regular  Vegan Cheddar Cheese','Chicken/Sour Cream Toasted Quesadilla'),
        ('Toasted Quesadilla','Vegan Cheddar Cheese|Vegan Sour Cream','Vegan Toasted Quesadilla'),
        ('Sofritas Quesadilla','Vegan Cheddar','Vegan Cheddar Sofritas Quesadilla'),
        ('Quesadilla','Vegan','Vegan Quesadilla'),
        ('Grilled Cheese & Tomato Soup','Vegan','Vegan Grilled Cheese & Tomato Soup'),
        ('Hot Soup(V/Gf) With Grilled Turkey And Cheese (Vegan, Gf Option By Request)','No Turkey','Vegan Hot Soup'),
        ('Cheese Melt & Soup','Vegan','Vegan Cheese Melt & Soup'),
        ('Soup & Grilled Cheese','Vegan Cheddar|Vegan Prov','Soup & Grilled Vegan Cheese'),
        ('Egg Bakes','Chicken','Chicken Egg Bakes'),
        ('Autumn Salad Bowl','Chicken','Chicken Autumn Salad Bowl'),
        ('Cauliflower Flatbread Pizza','Chicken','Chicken Cauliflower Flatbread Pizza'),
        ('Cauliflower Flatbread Pizza','Vegan','Vegan Cheese Cauliflower Flatbread Pizza'),
        ('Chicken Salad Over Greens','Chickpea','Chickpea Salad Over Greens'),
        ("Farmer'S Market Salad","Chicken","Chicken Farmer'S Market Salad"),
        ("Farmer'S Market Salad","Vegan","Vegan Farmer'S Market Salad"),
        ("Wraps","Vegan Chicken","Vegan Chicken Wrap"),
        ("Wraps","Chicken","Cranberry Chicken Wrap"),
        ("Cranberry Chicken Salad Wrap-Organic, Hormone And Antibiotic Free Chicken. Gf Wrap On Request", "", "Cranberry Chicken Wrap"),
        ("Cranberry Chicken Salad Wrap", "", "Cranberry Chicken Wrap"),
        ("Wraps", "Chickpea", "V - Smash Wrap")
    ]

    # Vegan items
    vegan_list = [
        'Avocado Toast',
        'Vegan Breakfast Wrap',
        'Raspbalance',
        'Vegan Breakfast Bowl',
        'V - Cookie Bar',
        'V - Fudge Brownie',
        'Vegan Toasted Quesadilla',
        'Honey Pops',
        'V - Ginger Molasses Cookies',
        'V - Raspberry Lemon No Bake',
        'Chocolate Covered Oreos',
        'V - "Cheese"Cake',
        'Vegan Grilled Cheese & Tomato Soup',
        'Vegan Hot Soup',
        'Coffee Beans (12Oz Bag)',
        'Honey Lip Balm',
        'Hippea, 4Oz Puffs Siracha',
        'Vegan Cheese Melt & Soup',
        'Bath Fizzy Balls, Hawthorne 1204 Apothecary',
        '"Twix" Bar  V/Gf',
        'Hippea Cheddar Puff, 4Oz',
        'Soup & Grilled Vegan Cheese',
        '24 Carrot',
        'Smash Burger + Chips',
        'Mint To Be',
        'Side Of Fries',
        'Serenity Now',
        'Peppermint Mocha Bowl',
        'Hippea, 10 Oz Cheddarpuffs',
        'Vegan Cheese Cauliflower Flatbread Pizza',
        'Microgreens, Clamshell',
        'V - Ginger Molasses Cookies (1)',
        'Beesknees, Cinnamon Maple Syrup',
        'Cbd Full Spectrum - 1000 Mg',
        'Maple Syrup',
        'Sprout Living, 5Lb Bag, Protein Powder',
        'Sprout Living Protein Powder, 5Lb Bag',
        '5Lb. Bag Epic Protein',
        'Protein Powder, 5Lb Bag-- Sprout Living',
        'Gingersnap Cheesecake V/Gf',
        'Mints, Simply Mints',
        'Real Sport, Epic Protein Powder 1.1Lb',
        'Ginger',
        'Maple Brandy Syrup',
        'Caramel "Cheese"Cake',
        'Chickpea Salad Over Greens',
        "Vegan Farmer'S Market Salad"
    ]

    # Vegetarian items
    vegetarian_list = [
        'Veg Breakfast Sandwich',
        'Egg Avocado Toast',
        'Egg Buddha Bowl',
        'Cheese Beyond Burger',
        'Great Pumpkin Bowl (Dairy)',
        'Regular Kale! Cesar Salad',
        'Veggie Melt & Tomato Soup',
        'Veggie Melt & Tomato Basil Soup',
        'Cilantro Lime Coleslaw',
        'Egg Goddess Salad',
        'Winter Protein Salad',
        'Kid‚Äôs Organic Chocolate Milk',
        'Carrot Cake Cupcake',
        'Peanut Butter Scotchy Bar',
        'Carrot Cake Cupcake - Gf',
        'Greek Yogurt, Fruit + Granola',
        'Chips-Good Health 1Oz',
        'Peanut Butter Meltaway',
        'Frittata',
        'Peppermint Brownie',
        'Feta Toast',
        'Pretzel Bark',
        'Hard Boiled Eggs, 2, Packaged',
        'Ginger Chocolate Bar',
        'Egg Bakes',
        'Autumn Salad Bowl',
        'Solid Chocolate Bar',
        'Cake Pop (1)-Gf',
        'Creamy Tomato Soup',
        'Kettle Chips, Good Health',
        'White Cheddar Puffs',
        'Whipped Feta Toast',
        'Cauliflower Flatbread Pizza',
        'Dated Cinnamon Rolls',
        'Chocolate Peanut Butter Meltaway',
        'Potato Chips, Dirty Potato Company',
        'Quiche (Artichoke + Red Pepper) W/ Side Salad',
        'Chocolate Cake With Ganache And Raspberries, Gf',
        'Carrot Cake, Slice',
        'Caprese Focaccia Sandwich',
        'Carmel Cheesecake With Slated Caramel Sauce',
        'Majestic Pretzels',
        'Lemon Drop Cookie, Gf',
        'Chocolate Pretzel Bark',
        'Strawberry, Feta + Toasted Almond Salad',
        'Chocolate Bars: Solid, Pretzel &  Ginger',
        'Pretzel Thins',
        'Taffy',
        'Cheddar Broccoli Quiche & Side Salad  (Gf)',
        'Vanilla Layer With Cranberry Filling And Buttercream Frosting',
        'Frittata And Side Salad',
        'Cake Bites',
        'Oui Yogurt',
        'Chocolate Covered Strawberries',
        'Foiled Chocolate Carrots',
        'Sw Quesadilla',
        'Beet Feta Salad',
        'Maple Candy',
        'Frittata & Side Salad',
        'Creamy Tomato ',
        'Carrot Cake With Buttercream Frosting- V&Gt Whole Cake',
        'Carrot Cake Cupcake - Gluten Free'
    ]

    # Meat items
    meat_list = [
        'Cranberry Chicken Salad Wrap-Organic, Hormone And Antibiotic Free Chicken. Gf Wrap On Request',
        'Collagen Pb & J',
        'Whipped Cream Collagen Morning Mocha',
        'Collagen Acai',
        'Collagen Pb & J Bowl',
        'Collagen Acai Smoothie Bowl',
        'Collagen Blueberry Thrill',
        'Chicken Buddha Bowl',
        'Chicken Salads',
        'Chicken Goddess Salad',
        'Chicken Sw Burrito Wrap',
        'Sushi Bowl',
        'Turkey Reuben-Vegan Or Regular',
        'Chicken Spinach Salad',
        'Banh Mi-Special For May !',
        'Chicken Apple Walnut Salad',
        'Chicken Green Goddess Salad Bowl',
        'Turkey Reuben-Vegan(Tofu) Or Rachel(Turkey)',
        'Lemon Bars',
        "Chicken Farmer'S Market Salad",
        "Shepard'S Pie & Side Salad"
    ]

    # Alcoholic drinks
    alcoholic_drinks = ['Bundaberg Ginger Beer']

    # Non-alcoholic drinks
    non_alcoholic_drinks = [
        'Main Squeeze', 'Calm (Formally, Main Squeeze)', 'Calm (Main Squeeze)',
        'Orange Glow', 'Glow (Orange Glow)', 'Glow (Formally Named, Orange Glow)',
        'Tart Smart',
        'Bitter End',
        'Vitali-D',
        'Karma Water', 'Aqua Selzer','Aria Water','Bottled Water','Flow Water, Small','Alo Water','Voss Water','Smart Water','Alkaline Water, Large', 'C2O Water, Can', 'Aspire Water', 'Celsius Water, Can', 'Bai Water', 'Flow Water', 'Flow Water, Large',
        'Custom Juice',
        'Rehab',
        'Pb Scotchy, V/Gf',
        'S Pellegrino', 'San Pellegrino, Can','Pellegrino Water, Green Bottle','Pellegrino, Can', 'Pelligrino, Glass, Large',
        'Ginger Shot',
        'Super Green',
        'Immunity Booster', 'Immunity Booster - New!', 'Protect (Immunity Boost)',
        'Aphrodite',
        'Wheatgrass',
        'High Voltage',
        'Renew (Good Juju)', 'Renew (Formally Named Good Juju)',
        'Triple C Zinger',
        'Nourish (Salaminjaro)',
        'Juice Box',
        'Cold Brew Coffee', 'Ginger Tea (Shredded Ginger Root + Honey)','Chai - Housemade (No Sugar Or Dairy)','Iced Cold Brew','Spark Cold Nitro Coffee', 'Loose Leaf, Cup Of Tea','Hot Tea Bag','Dark Heart Tea','Zevia Iced Tea','Iced Chai','Wants + Needs Tea','Matcha Green Tea','Espresso','Chai: Add Sugar!','Peace Tea','Coffee, Hot Or Iced','Iced Tea','Iced Chai - Housemade (No Sugar Or Dairy)','Staff Coffee','Coffee','Chai-Free Of Sugar & Dairy','Frozen Matcha Latte', 'Iced Coffee', 'Coffee, Hot', 'Cup Of Life‚Ñ¢ Hot Tea', 'Happy Mug‚Ñ¢ Coffee', 'Iced Tea, Herbal Or Black', 'Chai', 'Chai- Dairy And Sugar Free', 'Happy Mug‚Ñ¢ Loose Leaf Tea',
        'Celery',
        'Glow~ Orange Glow',
        'C2O Coconut Water', 'Organic Cocnunt Water, Can 11Oz','Vitacoco, Lg. Coconut Water (33.8Oz)','Coconut Water', 'Vita Coconut Water','Organic Coconut Water, Can 11Oz','Pressed Coconut Water, 1 Liter','Vita Coconut Water, 11.1 Oz','Coconut Water, Fruit Flavored','Coconut Water, 11.1 Oz', 'Coconut Water, 33.8 Oz.',
        'Healing Lemonade',
        'Buchi Kombucha', 'Kombucha,"Magic Hour" Orange Blossom','Aquavita Kombucha','"Hidden Worlds" Ginger Lemongrass Kombucha','"Magic Hour" Orange Blossom Kombucha','"Midnight Garden" Blueberry Lavender Kombucha', 'Kombucha, "Midnight Garden" Blueberry Lavender',
        'Tea Bag, Prepackaged Variety',
        'Datorade',
        'Revive (Formally, Chlorohyllmeup)', 'Revive (Chlorohyllmeup)',
        'Boost (Metabolic Mojito)', 'Boost (Formally, Metabolic Mojito)',
        'Zevia Soda', 'Bubbly, Can', 'Cawston Press Soda', 'Cawston Press Rhubarb Soda',
        'Four Sigmatic‚Ñ¢ Mushroom Cacao With Reishi',
        'Restore (Hangover Cure)', 'Restore (Formally Named Hangover Cure)',
        'Happy Mug Tea', 'Tea Pot And Tea',
        '1/2 Gallon Juice, Cold Pressed',
        'Arnold Palmer 1/2 Lemonade 1/2 Tea',
        'Honey Tonic',
        'Zevia Ginger Root Beer',
        'Recover (Formally, The Roots)',
        'Aloe Shot',
        'Celery Juice',
        'One Gallon Cold Pressed Juice',
        'Grab And Go Juice',
        '24 Carrot',
        'Mint To Be',
        "Dragon'S Breath"
    ]

    # Merchandise list
    merch_list = [
        'Maple Syrup, Maple Brandy','Chai Meal Replacement Packet','Full Spectrum, Citrus - 1000 Mg','Extra Virgin Grapeseed Oil, Kosher','Tea Tins, Harney+Son','Vit. D3, High Potency, Capsules','Biotin Capsules, 1000Mcg','Full Spectrum - 1000 Mg','Biotin Capsules 10,000 Mcg','Elderberry Syrup 8Oz','Cbd Full Spectrum - 1000 Mg','Spicy Honey, Beesknees','Triple Magnesium Complex','Collagen Packet', 'Gum, Simply Gum', 'Coffee Beans (12Oz Bag)', 'Sprout Living Protein Packet',
        'Honey By John','Happy Mug Coffee 12Oz Bag','Spirulina Powder, Yourlixir','Elderberry Syrup, 8Oz', 'Cbd Oil', 'Cbd Full Spectrum - 500 Mg','Elderberry Drops 2Oz - Sugar-Free', 'Vitamin D, Liquid', '60 Billion Probiotic With Prebiotic',
        'Hot Cocoa Packet, Elements 4Oz', 'Simply Mints - Awaken (Caffeine)',
        'Cbd Isolate - 500 Mg',
        'Ashwagandha Ksm-66', 'Isolate - 1000 Mg', 'Full Spectrum - 500 Mg',
        'Honey-Quart & Bear (Mv Power)',
        'Towels','T Shirt - Black (Short Sleeve)','Sweatshirt','Tshirt-Light Green & Peach', 'T-Shirt- Long Sleeve, Ash White',
        'Viridi Surface Wipes','Daily Lotion - 500 Mg',
        'Yoga Mat Or Bug Spray ', 'Pet Wipes',
        'Water, Regular Bottled',
        'Flu Shot', 'Knitted Head Wraps',
        'Drink Jar Lid, Regular',
        'Grapeseed Oil',
        'Hoodie, Juice Jar','Honey Stirrers (6 Pack)','Wooden Bamboo Spoon','Spoon, Wooden','Bath Bombs, Cupcake','Face Mask, Elestic Band', 'Lotion Bar', 'Shampoo Bar', 'Candle, Soy/Natural Andromeda',
        'Honey-Large Mason Quart Jar (Mv Power)','Bath Fizzy Balls, Hawthorne 1204 Apothecary', 'Honey Lip Balm',
        'Scent Candles', 'Shampoo/Cond. Bar', 'Bath Soak','Candle, Coconut Bowl',
        'Fruit Infusion Lid','Metal Straw','Straws And Straw Cleaning','Etched Bottle','Teapot Set','Bamboo Straw', 'Honey Bear Jar', 'Reuseable Straw', 'Drink Jar Set-Wide Mouth (Lid, Jar, Straw)','Drink Lid, Regular','Jj Nalgene  Bottle','Carafe And Tea Gift Set','Bamboo Cup And Straw Set','Drink Jar Lid, Wide Mouth','Drink Jar Set-Regular (Lid, Jar, Straw)','Four Sigmatic Golden Latte With Turkey Tail','Iron, Dbl Strength, Vegan, Now Foods','Nova Syrup - Pint','Nova Maple Syrup','Elderberry Syrup','Harmony Green Tea Packet','Sprout Living Protein Powder_Small', 'Happy Mug Coffee Beans (12Oz Bag)',
        'Gift Certificate','Gift Card', 'Cookbook, Simple Swaps','Vegan Cookbook', 'Egift Card', '10$ Gift Certificate',
        'Bunny Butts-Gf', 'Candle,  Andromeda',
        'Dog Treats',
        'Handwoven Produce Bags','Cooler Bag', 'Cooler Bags', 'Tote Bag',
        'Magic Mud',
        'Vapor Rub', 'Hand Cleaner, 2Oz., Natural, Alcohol-Free',
        'Merchandise', 'Clock',
        'Candles, Glass Jar, Big Moods'
    ]

    # Rare items (empty - calculated dynamically)
    rare_list = []

    # Unknown items
    unknown_list = ['','Enchant Mint','Honey Comb In Honey','Cure-All','Honey-Raintree Farms','Happy Gut', 'Rick Ross:  A Fall Favorite!!  (1 Sept - 15 Nov)']

    # Create the remappings dictionary
    remappings = {
        "name_changes": name_changes,
        "modification_name_changes": modification_name_changes,
        "vegan_list": vegan_list,
        "vegetarian_list": vegetarian_list,
        "meat_list": meat_list,
        "alcoholic_drinks": alcoholic_drinks,
        "non_alcoholic_drinks": non_alcoholic_drinks,
        "merch_list": merch_list,
        "rare_list": rare_list,
        "unknown_list": unknown_list
    }

    return remappings

def export_yaml():
    """Export the remappings to YAML file"""
    # Generate remappings
    remappings = generate_loc6_remappings()
    
    # Create output directory if it doesn't exist
    output_dir = Path('scripts') / 'labeling' / 'remapping'
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Write to YAML file
    output_file = output_dir / 'loc6_remappings.yaml'
    with open(output_file, 'w', encoding='utf-8') as f:
        yaml.dump(remappings, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
        
    print(f"   - Name changes: {len(remappings['name_changes'])}")
    print(f"   - Modification rules: {len(remappings['modification_name_changes'])}")
    print(f"   - Vegan items: {len(remappings['vegan_list'])}")
    print(f"   - Vegetarian items: {len(remappings['vegetarian_list'])}")
    print(f"   - Meat items: {len(remappings['meat_list'])}")
    print(f"   - Non-alcoholic drinks: {len(remappings['non_alcoholic_drinks'])}")
    print(f"   - Alcoholic drinks: {len(remappings['alcoholic_drinks'])}")
    print(f"   - Merchandise: {len(remappings['merch_list'])}")
    print(f"   - Unknown items: {len(remappings['unknown_list'])}")

if __name__ == "__main__":
    export_yaml()