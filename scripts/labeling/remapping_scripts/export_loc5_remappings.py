#!/usr/bin/env python3
"""
Export script to generate loc5_remappings.yaml programmatically
This script contains all the hardcoded data and exports it to YAML format
"""

import yaml
from pathlib import Path

def generate_loc5_remappings():
    """Generate the remappings dictionary programmatically"""
    
    # Item name consolidation
    name_changes = {
        "Griffith Street": ["Gs", "Gs Meat"],
        "Awkward Aardvark": ["Aa/No Meat"],
        "Egg & Cheddar": ["Ec", "Ec Tomato", "Egg Cheddar", "Egg Cheese"],
        "Egg Hummus Pesto": ["Ehp", "Ehp Tomato", "Ehp Meat", "Egg Hummus-Pesto"],
        "Egg Meat Cheese": ["Ec Meat", "3. Egg Meat Cheese"],
        "Egg Meat": ["Egg & Bacon"],
        "Egg": ["Scrambled Eggs"],
        "Loose-Leaf Tea": ["Loose-Leaf", "Loose Leaf"],
        "Veggie Sandwich": ["Veggie Sandwich", "Veggie Sandwich With Side Salad"],
    }

    # Define base dishes, their final default state, and if step 2 has an explicit 'Vegan' mod rule
    dish_config = [
        {"dish": "Veggie Sandwich", "default_state": "Vegetarian", "has_explicit_vegan_rule": True},
        {"dish": "Toby Toast", "default_state": "Vegan", "has_explicit_vegan_rule": False},
        {"dish": "Careless Whisper", "default_state": "Vegan", "has_explicit_vegan_rule": False},
        {"dish": "Garden Home", "default_state": "Vegan", "has_explicit_vegan_rule": False},
        {"dish": "Avocado Toast", "default_state": "Vegan", "has_explicit_vegan_rule": False},
        {"dish": "Griffith Street", "default_state": "Vegetarian", "has_explicit_vegan_rule": True},
        {"dish": "Awkward Aardvark", "default_state": "Meat", "has_explicit_vegan_rule": True},
        {"dish": "Egg & Cheddar", "default_state": "Vegetarian", "has_explicit_vegan_rule": True},
        {"dish": "Build Your Own", "default_state": "Meat", "has_explicit_vegan_rule": True},
        {"dish": "Yeti Sandwich", "default_state": "Meat", "has_explicit_vegan_rule": True},
        {"dish": "Hashy", "default_state": "Meat", "has_explicit_vegan_rule": True},
        {"dish": "The Craven", "default_state": "Meat", "has_explicit_vegan_rule": True},
        {"dish": "Yeli Sandwich", "default_state": "Meat", "has_explicit_vegan_rule": True},
        {"dish": "One Punch", "default_state": "Vegetarian", "has_explicit_vegan_rule": True},
        {"dish": "The Dook", "default_state": "Vegetarian", "has_explicit_vegan_rule": True},
        {"dish": "Egg Meat Cheese", "default_state": "Meat", "has_explicit_vegan_rule": True},
        {"dish": "The Paul", "default_state": "Meat", "has_explicit_vegan_rule": True},
        {"dish": "Fullmetal Alchemist", "default_state": "Meat", "has_explicit_vegan_rule": True},
    ]

    # Generate vegan list programmatically
    vegan_list = [f'Vegan {dish["dish"]}' for dish in dish_config]

    # Generate vegetarian list programmatically  
    vegetarian_list = [f'Vegetarian {dish["dish"]}' for dish in dish_config] + [
        'Pumpkin Bread', 'Pandan Cookie', 'Bread | Carrot Zucchini',
        'Loaf | Carrot Zucchini', 'Cookie', 'Bagel'
    ]

    # Generate meat list programmatically
    meat_list = [f'Meat {dish["dish"]}' for dish in dish_config]

    # Alcoholic drinks
    alcoholic_drinks = []

    # Non-alcoholic drinks
    non_alcoholic_drinks = ["Matcha", "Loose-Leaf Tea", "Signature", "Flavor"]

    # Merchandise list (comprehensive hardcoded list)
    merch_list = [
        "Whole Beans", "Signature", "Gift Card", "Sticker", "Card", "Easy Sunday Club", "Earrings",
        "Mask - Kelly", "Seewhyzhang", "Little Gold Fox Design", "Pin", "Ezen Design", "Cathy Zhang",
        "Poppy", "Christa Pierce", "Stubby", "Sloane Darling Art", "Hazelhoff", "Enamel Co", "Bottom",
        "Top", "Sasquatch", "Noteworthy", "Mike York", "Masks", "David Hazelhoff", "Destination Oregon",
        "Hank Knit - Mask $10", "Nickel Art Studio", "Wooden Greeting Card", "Squishable", "Fun Club",
        "Graphic Heart", "Joco", "Sticker - Name, Waves", "Corgi Mouse Pad", "Urban Retrospective", "Middle",
        "The Bower Studio", "Corgi Socks", "Basket", "Imagination Spot", "Spoon/Spatula", "Hoodie",
        "John Skewes", "Sticker - Tanuki, Black", "Sticker - Bear Hug", "Oregon Puzzle 4-Pc. Coaster Set With Case",
        "Candle", "Sticker - Logo, Black", "Peter Pauper Press", "Susie Chriswisser", "Chemex - Filters",
        "Sticker - Tanuki, Rona", "Sticker Bundle", "Print - Large", "Tea Towel", "Sticker - Logo, Red",
        "Caitlin Keegan", "Notebook", "Things Are What You Make Of Them", "Happiness", "Adam J. Kurtz",
        "Dishcloth", "Illuminated Tarot", "Enamel Pin", "Baltique", "Create Your Own Calm", "Tattoo Tarot",
        "Earthwell", "A Life Of Gratitude", "Ginger Anne", "Salt Vial Set", "Tomoko Alfonso", "Start Where You Are",
        "Chemex", "Page At A Time", "Forlife", "Good Luck Cat (Cutout) Holographic Eyes Sticker", "Mixed Feelings",
        "Basic Witches", "Sticker - Vote", "Blanket", "Growth", "Choose Hope, Take Action", "Work/Life Balance",
        "To-Go Box", "Jennifer Joy", "Sticker - Daruma", "The Girls - Enamel Pin", "Card - Happy Mothers Day Ducks",
        "Card - Fuck Yeah Fox", "Leathers", "Sticker - Tanuki, Red", "Bill Perkins", "Sticker - Bee",
        "Sticker - My Heart Oregon", "Single Greeting Card Elephant Yellow (W)", "Earrings - Butterfly Wings",
        "Susie", "Card - Hello From Portland", "Postcard Set - Portland Bridges", "Hand Knit - Coffee Cuffs",
        "Larry Gets Lost In Portland", "Ellen Injerd", "Katie Stanley", "Tattoo Tarot Journal", "Hand Kint",
        "Abigail Terry", "Good Luck Black Cat Enamel Pin", "My Neighbor Totoro Die Cut Lunch Bag - Gray",
        "Illuminated Playing Cards", "Card - Go Shorty", "Portland Small Tray", "Tote", "X16 - Portland Bridges",
        "Card - Thank You", "‰∫Îâπ¥ Zip Hoodie - Mustard", "Am I Overthinking This", "Sticker - Name, Black",
        "Undercover Corgi In Avocado (7\")", "Good Luck Cat Journal", "Made Out Of Stars", "Card - Sending Good Vibes",
        "Salt Tin", "Nowhere Land", "Mala Bracelets By Abby", "Tea Towel - Oregon", "Crowned Rabbit",
        "Card - I Miss Your Face", "The Tattoo Coloring Book", "Sticker - Oregon", "Oregon Board",
        "Counting With Barefoot Critters", "Scales Ki-Shirt", "Emily Windfield Martin", "Larry Loves Portland",
        "Mala By Abby", "Portland Abc", "Card - Happy Bday", "I: The Girls Notebook", "Sticker - Life Is An Adventure",
        "Tomorrow I‚Äôll Be Kind", "Lori Roberts", "Pin - Fuck Yeah Fox", "Clever", "Robyn Nicole",
        "Embroidered Rose Sweater", "Card - Rad Woman With Plants", "Sticker - Van", "Pin - Bee", "Backroom Reservation",
        "Leather", "Mug - Ceramic", "Card - Giraffe Family", "Reading Fox", "Ki-Hoodie (Black Camo)",
        "Large Notebook Elephants Light Green (W)", "Ki-Shirt (Black)", "Bear Hug Sticker", "Card - Daddy Shark",
        "Card - Muttflix", "Card - You Are Magic", "X", "Oregon State Stamp Series Salt Box", "Book - Day Dreamers",
        "Hope Angel Fine Art", "Sticker - Whale", "Peter + June", "Tomorrow I‚Äôll Be Brave", "Postcard - Oregon Coast",
        "Ashley Cuddeford", "Pin - Rainbow Sheep, Warrior", "Wander Enamel Pin", "Gleeful Peacock", "The Crowned Rabbit",
        "Hand Knit - Mask $", "Tarot For All Ages", "Undercover Corgi In Octopus", "Jessica Hische",
        "Single Greeting Card Elephants Pink (W)", "Card - I Ducking Love You", "Coaster Set", "Card - Congrats - Elephants",
        "Blanket - Numbers", "Voodoo Bath Bomb", "Mermaid Sticker", "Ring - Gem", "Cat Wilson", "Abcs Of Life",
        "Wander Hourglass Holographic Sticker", "Bracelet Mala - Earthmagick", "Mug -Portland Or Map Icons", "Ring - Flower",
        "Owls", "Note Box Elephants Dark Green (W)", "Hiroshige Blossom Fans - Giclee Print",
        "Clever Idiots Cat Paw Chair Socks - Tabby Cat Grey", "Corgi With Little Bouquet Vinyl Sticker", "Mushroom House",
        "Ki-Shirt (White)", "My Neighbor Totoro Bento Lunch Box (21.98Oz, 650Ml)", "Bookmark - Poppy Spider",
        "Postcard Set - Portland Icon", "Undercover Corgi", "X10", "Undercover Panda In Red Panda", "Chris Castor",
        "Don‚Äôt Be A Shit", "Card - Bitches Unite", "Notepad - Honey Do List", "Blanket - Alphabet", "Beaverton Mug",
        "Card - Your Face", "Fancy As Fuck", "Derek", "Mystic Mondays Tarot", "Good Luck Sock",
        "My Neighbor Totoro Chopstick And Spoon With Case - Foraging", "Ginkgo Leaf Vinyl Sticker", "Patch - Van",
        "Sarah Beth Greene", "Ok Tarot: The Simple Deck For Everyone", "Postcard - Dog Lit Up On Shrooms", "Ki Shirt",
        "Sarah Jacoby", "Pin - Tanuki", "Large Notebook Elephant On Toilet (W)", "Postcard - Pdx Rainbow Bridge",
        "Astro Cat Enamel Pin (Orange)", "Serena Gingold Allen", "One Lane Road", "Love And Meanness", "Mala By Valita",
        "Rc", "Pin - Corgi", "Earrings - Antlers", "The Mushroom Tarot", "Sparkle Farm", "Scales Sticker",
        "Space Corgi Enamel Pin", "Leafs", "Sticker - Snowy Owl", "My Friend Fear", "Postcard - Mt Hood",
        "Little Sage Tarot", "Planner - Bon Appetit", "Filters", "Michelle Rial", "Hidden Forest", "X10 - Beluga Whales",
        "Card - Fox Family", "Print - Extra Large", "Card - Rad Woman With Skates", "There Is Poetry In Me",
        "Bookmark - Luna Bouquet", "Small - Adventures With Barefoot Critters", "Card - Anatomy Of A Rad Woman Yoga + Plants",
        "Deb", "Corgi Purse", "Sticker Pack", "Love Nikki", "The Unipiper Cycles Through Portland", "Card - You Are Brave",
        "Notepad", "Wooden Greeting Card - Great Horned Owl", "Spa Day", "Pin - Penguin", "Catching Stars", "Box Set",
        "Pin - Zen Cow", "Corgi & Puppies Vinyl Sticker", "J.P. Sullivan", "X10 Print", "Ok Tarot", "#Rona 2020 Sticker",
        "Tea Towel - Bees", "Patch - To The Trees", "My Neighbor Totoro Bamboo Chopstick - Leaves", "Meera Lee Patel",
        "Postcard - Portland Bridge", "Boob Ring - Rose Gold", "Cranes", "Iii: Arrows Notebook", "Postcard- Mount Rainier",
        "Take Miaaaaway", "Boob Ring", "Tea Towel - Portland", "Zipper Hood", "Notebook - 100 Dot Grid Pages", "Yogi",
        "Michele Maule", "Illuminated Journal", "Card - Honey Bees", "X10 - Oregon Coast", "Pin - Van",
        "Gudetama Utensil Set (Sunny-Side Up)", "The Cocktail Box Co", "Bracelet", "Written In The Stars Enamel Pin",
        "Wooden Greeting Card - Lovers", "Cambro", "The Imagination Spot", "Multifolia", "Rockpool",
        "Wooden Greeting Card - Luna Bouquet", "Logo Sticker", "Written In The Stars Holographic Sticker",
        "Love Is Love - Set Of Pencils", "Stitch And Stone", "Card - Anatomy Of A Rad Woman Derby", "Bookmark - Heart Tree",
        "X10 - Giraffe Family", "Card - Plenty Of Fish", "Christina Pierce", "Sticker - Sea Turtle", "If You Come To Earth",
        "Fabulous Unicorn Holographic Sticker", "Picnic On The Mushroom", "Card - Rad Woman With Baby", "Terry Cuddeford",
        "Adventures With Barefoot Critters", "Card - Hello From The Otter Side", "Card - Hot Air Balloon",
        "Le Chat Noir Earings", "Book - Dream Animals", "Postcard - Mount Hood", "Card - Shooting Star",
        "Book - The Wonderful Things You Will Be", "Card - Congrats - Bears", "Card - You Are Strong", "Conch Shell Earrings",
        "Things Are Shockingly Possible", "X14 - Spiritual Unity", "The Tarot Coloring Book", "Tarot De Marseille",
        "Ariel Kusby", "Pin - Logo", "Sticker - Red Mermaid", "Jewelery", "Postcard - Happy Holidays Hot Chocolate House",
        "Postcard - Portland Unicorns", "Pink Himalayan Grinder", "Portland Round Tray", "Time To Wander Journal",
        "Portland 1 To 10", "Pin - Black Sheep, Warrior", "Mug - Great Women Of Science", "Insects",
        "Spirited Away Bamboo Chopstick - No-Face", "The Paws", "Cocktail Box Co", "Becky Vasquez", "Pen", "Spring Break",
        "Written In The Stars Journal", "Notebook - Hedgehogs", "Babies", "Planner - Skys The Limit", "Katrina Liu",
        "Harvest Moon (Hoodie)", "Le Tarot Astrologique", "Tea Towel - Camping", "Sleeping Squirrel",
        "Kimono Fans - Giclee Print", "Skc (Susie Chriswisser)", "Atom Earrings",
        "Ginkgo Leaf - Light And Dark Green Enamel Earrings", "Card - You Slay", "Deborah Underwood",
        "Wooden Greeting Card - Birthday Wishes", "Kiki'S Delivery Service Die Cut Lunch Bag - Jiji", "Postcard - Pdx Stag",
        "A Cats Guide To Money", "Nickle Art Studio", "Sylvia Draws", "Who Hoo Are You?", "Boob Necklace",
        "Revitalizing Oil - 8 Oz", "Bracelet Mala - Valita", "Space Corgi Holographic Sticker", "Merry Christmas",
        "Card - Hey Boo", "Musical Notes Earings", "Ellen Jackson", "Bookmark - Cornucopia", "Bamboo Wood Sticker",
        "Card - Keep Portland Weird - Straight Brunette", "Bookmark - Stag Beetle", "The Tall Trees Of Portland",
        "Portland Denim Tote", "Swedish Dishcloth - Fox", "Swedish Dishcloth - Portland Biker Guy", "Card - Girl Gang",
        "Adventure Awaits", "Read Em And Weep Tote", "Calligraphy Flower Stretched Earrings", "Undercover Panda",
        "Kiki'S Delivery Service Round Bento Lunch Box 16.91Oz,", "Postcard - Cascadia", "Card - Outdoor Bath",
        "Single Itty Bitty Studs", "X10 - Giraffe Couple", "Card - Two Men Bath", "X14 - Many Crossings In Bridge Town",
        "Card - Made For Each Other", "Card - Man And Woman In Bath", "Too Magical", "Raindrop Circle Earrings",
        "Card - Keep Portland Weird - Fair, Blonde", "Paper Cup", "Planet Bunnie", "The Triangular",
        "Kanji Symbol (Love) Earrings", "Kawaii Rainbow Enamel Pin - Glitter Edition", "Family Conversation Cards",
        "Samiramay Tarot", "Round Sustainable Fairtrade Handmade Fruit Basket Bowl", "Bubble Earrings",
        "Sunrise Blossoms Earrings", "Paper Greeting Card", "Dream World Matching Game", "Julie", "Undercover Kitty",
        "My Neighbor Totoro Die Cut Lunch Bag - Blue", "Tits - Sticker", "Corgi White Eco-Friendly Tote Bag",
        "Little Little Art Co", "Honey Bee Tote Bag", "Pencil Case", "Illuminated",
        "My Neighbor Totoro Die Cut Lunch Bag - White", "Greek Bamboo Earrings", "Kami Mcbride", "Rebecca Green",
        "Swirl Earrings", "Fountain Pyramid Earrings", "Circle Array Earrings", "Shattered Triangle Earrings",
        "Orchid Earrings", "Large Flower Earrings", "Long Flower Earrings", "No Mans Land", "Embraced Bamboo Earrings",
        "Jessica E. Pierce", "Extra Cup", "Bill Alsup", "Jon Klassen", "X10 - Rad Woman With Plants",
        "Emily Winfield Martin", "Card - Santa Ho Ho Ho", "Portland Farmers Market Cookbook", "X10 - Silk Moth",
        "Papa Bear", "Card Bundle", "Dance In The Forest", "Postcard - Pdx Unicorn", "Ki Tote",
        "Card - Keep Portland Weird - Curly Brunette", "X10 - Snowy Owl", "Beehouse Dripper", "Penguins",
        "X10 - Poppies And Butterflies", "Finding Grace", "Kitty In Boat", "Card - Women In Bath",
        "Wooden Greeting Card - Stag Beetle", "Sticker - Pastel Mermaid", "Card - Drunk Penguin Happy Holidays",
        "Masks $10", "Notepad - Van", "Card - He Was A Prick", "X10 - Wolf", "Dancing Fox", "Greetings From Portland",
        "Brew-In-Mug Infuser", "Necklace Mala - Earthmagick", "X10 - Giraffe Mother And Baby", "X10 - Fuck Yeah Fox",
        "Tea Towel - Floral", "Bracelets", "Card - Capybara Holiday", "Bookmark - Flora & Fauna", "Sticker - Blue Mermaid",
        "Box Set - Reindeer", "Card - Be Lazy", "Card - Keep Portland Weird - Dark, Brunette", "Sticker - Take Me To The Trees",
        "Ring", "Mug - Portland Biker Guy", "Wooden Greeting Card - Cascadian Bouquet", "Hair Ties", "Pin - Elephant",
        "Troy", "Julie Thomas", "Bookmark - Rampant Unicorn", "Post Cards: Old Beaverton",
        "Stone Lantern #3 - Crystal Bead Earrings", "Keychain", "Noteworthy P&P", "Card - Miss Your Face Wreath",
        "Cubist Profile - Sapphire Bead - Giclee Print - Domed", "Hour", "Patch - Compass", "Bodle Frog", "Shine",
        "X10 - Whale", "Creature Cups", "The Plant Room", "Boob Ring - Silver", "Notecard Set", "Elyse Breanne Design",
        "Hans Ramos", "Mistletoe", "Notebook - Fox And Squirrels", "Bracelet Mala", "Plantsnsht", "Prints 11X", "Ray",
        "X10 - Pnw Vibes", "Paper Greeting Card - Good Luck", "Bruce", "Postcard - Burnside Bridge", "Box", "Tea Hot Pot",
        "Wooden Greeting Card - Birds", "You Are Your Best Friend", "Washi Tape", "Sophia Blackall", "Tanuki Sticker",
        "Eliot", "Box Set - Owl", "Victoria'S Art", "Folding Handle Infuser", "Seek & Swoon", "Tote Bag - Honey Bee",
        "Big Castle Cross", "Hidden Cafe", "Booking - Hourly", "Delivery Charge", "Bar", "What Is A Woman", "Valita",
        "Coaster", "Scoop", "Card Processing", "Tea Canisters", "Bruce Rash", "House", "Grey Fiction", "X10 - Alpaca",
        "Whale Greeting Card", "Filter", "Fans", "Vegan Leather Tote", "Wild", "Fairy Houses", "Notebooks",
        "Portland Single Wine Tote", "Ray Wargo", "Corinna Luyken", "Pin - Narwhal", "Little Little Shirt",
        "Fairy Meditation", "Card - Two Lady Bath", "Boho Gal Jewelry", "Card - Multnomah Falls", "Bookmark - Roots",
        "Paper Greeting Card - Follow Your Bliss", "No Love Like It", "X10 - Party Of 9 Dogs", "Mama Bear",
        "X12 - Poppies And Butterflies", "Koinobori - Children Of The Family Bookmark", "Space Corgi Pin",
        "Pointed Drop Bamboo Earrings", "Card - Keep Portland Weird - Straight Pink", "Cubist Guitar - Slate Blue Bead",
        "Blanket - New Alphabet", "Sticker Pack - Cows", "Mothers Day - Ducks", "Black Towel", "Coral Earrings",
        "Card - He Was A Prick Anyway", "Loving Embrace Earrings", "Circle Bamboo Earrings", "X10 - Diversity Children Print",
        "Postcard - Pdx Rose", "Card - Happy Holidays Rabbit", "Card - Portland", "Aphantasia Sticker",
        "X10 - Bear & Hedgehog", "X10 - Pufferfish", "Town Square", "X11 - Spiritual Unity", "Daruma Thank You Greeting Card",
        "Sibley Backyard Birding Flashcards", "Hey Boo - Letterpress Card", "Cool Story Pencils",
        "Split Leaf Philodendron Leaf Blossoms Earrings", "Byzantine Road", "Peace Out Card", "Swaddle",
        "Tribal Sun Bamboo Necklace", "Hello Gorgeous Pencil Set", "The Great Wave Bookmark", "This Bag Holds My Shit Together",
        "Leo Vs. Draco", "Pride Earrings", "Nine Lives Bookmark", "Mug - Stay Wild Mountains & Flowers",
        "X10 - Double Waterfall Landscape", "X10 - Group Shot", "Japanese Flag Bracelet", "Vertical Blossoms Earrings",
        "I Am Holding You In My Heart Card", "Corgi Express Train Enamel Pin", "Pin - Dolphin",
        "Clean The Dishes Sea Dragon Swedish Dishcloth", "Smells Of Fall", "Plant Lover Sticker",
        "Wooden Greeting Card - Woodland Heart", "Earrings - Butterflies", "Daily Plan Notepad", "Whale Enamel Pin",
        "Teapot", "Pride Bracelet", "Wooden Greeting Card - Christmas Tree", "Musubi Made For Each Other Greeting Card",
        "Alexander Hamilton Bookmark", "Paper Greeting Card - Reindeer", "Kiss Me Under The Mistletoe", "Corgi Swaddle",
        "Card - Happy Holidays Bear", "Set Of", "Box Set - Bunnies", "Postcard - City Of Roses", "Drunken Tanuki",
        "Denim Portland Wine Tote", "Layered Teardrop Earrings", "X10 - Cat And Hummingbird", "Card - Happy Rain Cloud",
        "X10 - Polar Bears", "Pin - Yoga Sheep, Tree Pose", "Card - Keep Portland Weird - Med, Brunette", "Ring | Green",
        "Tanuki Pin", "Rorschach Ink Design Earrings", "On Top Of The Island", "X14 - World Unity",
        "Card - Laughing Reindeer", "Modern Floral Daily Plan Notepad", "Swedish Dishcloth - Sea Dragon", "X10 - Koala And Cub",
        "Black Classic Blanket", "Winter Break", "Calendar - 20", "Birthday Party", "Card - This Too Shall Pass",
        "Box Set - Winter Hare", "Soapstone Cat And Mouse Set Natural White (W)", "Postcard - Seattle Emerald City",
        "Bookmark - Beetle", "Sakura Ornaments Greeting Card", "Muusse Design", "Interlocked Triangle",
        "Raindrop Splashes Earrings", "Ohm Earrings", "Tote Bag", "Card - Congrats - Dogs", "Aegean Village",
        "Marble Archway", "Portland Animal Icon Towel", "Postcard - Happy Holidays"
    ]

    # Food list (comprehensive hardcoded list)
    food_list = [
        "Loose-Leaf Tea", "Flavor", "Hot Cocoa", "Egg & Cheddar", "Scone", "Lemonade", "Red Bull", "Griffith Street",
        "Iced Tea", "Flavored Iced Tea", "Egg Meat Cheese", "Little Little Loaf", "Build Your Own", "Kombucha", "Tap",
        "Special-Tea", "Day Old", "Matcha Latte", "Egg Hummus Pesto", "Tea Toddy", "Bag O' Beans", "Tap - Kombucha",
        "Brew Dr", "Awkward Aardvark", "Arnold Palmer", "Kind", "Golden Fire", "Earl Grey", "Ex. Flavor", "Domo Froppo",
        "Goblin King", "Jasmine Pearls", "Special Tea", "Kyushu Sencha", "Fruit", "Honey Lemon Ginger", "Tom Swanson",
        "Esp Float", "Cranberry Sencha", "Cold-Pressed Lemonade", "Pure", "Big Train Chai", "African Grey", "Caveman",
        "House Iced Tea", "Chaga", "Vegan Griffith Street", "Hot Chocolate", "Welchs", "Shake", "Egusto", "Carton",
        "Green Jade", "Drip", "Bee Local Honey", "Vegan Awkward Aardvark", "Hojicha", "Genmaicha", "Egusto Swanson",
        "Scone - Blueberry", "Annie'S", "The Dook", "Vive", "Sweet Iced Tea", "Tea", "Donut", "Puerh", "Tlc", "Gum",
        "Zone Perfect", "Jacobsen", "London Fog", "Egusto Mato", "Mint/Gum", "Mint", "Jacobsen Salt Co", "Apple",
        "Sweet Tea", "Milk Tea", "Redbull", "Golden Yogi", "Black Butte", "Kure Bar", "Pumpkin Pie", "Hibiscus",
        "Weekly Special", "English Breakfast - Black Tea", "Oatly", "Chamomile", "Kyushu", "Nonmeat Garden Home",
        "Fresh Lemonade", "Jasmine Pearl", "Rockstar", "Redbush Chai", "Black Garlic Salt", "Day Olds", "White Peony",
        "Ninkasi", "Orange", "Nonmeat Careless Whisper", "Rooibos", "Smith Tea", "Lavender", "Concord", "Co2 Brew",
        "Inji", "Feel Better", "Rosemary Salt", "Lavander Rose - White Tea Blend", "Raw Bee Pollen",
        "Bachan‚Äôs Japanese Barbecue Sauce", "Made Good", "Feel Better - Herbal Tea", "Super Joy - Uganda", "Booberry",
        "Lemon Zest Salt", "Black Lava Salt", "Almonds", "Yogurt", "Galway Girl", "Steven Smith", "Meat Garden Home",
        "Haiku Peach - White Tea Blend", "Burn Brew", "Proud Source", "Jasmine Pearl - Green Tea", "Meat Careless Whisper",
        "Puerh Queen", "Karo", "Finca Kilamanjaro - El Salvador", "Chocolate", "Cheesecake", "Clif", "Earl Grey - Black Tea",
        "Honey Cup - Herbal Tea", "Catering", "Red Alaea Salt", "Honest Tea", "Naked", "Hot Pot", "Ice Cream", "Cafe",
        "Altoide", "Honey Cup", "Green Jade - Oolong", "Widmer", "Buoy", "Injy", "Guatemala El Injerto", "Super Joy - China",
        "Super Joy - Ethiopia", "Fruit Platter", "Ginger", "Double", "Espresso Embassy", "Super Joy - Yunnan",
        "Loose Leaf Tea", "Ruby Nectar - Herbal Tea", "Hakutsuru - Nigori", "Kikusui Shuzo",
        "Hakutsuru - Nigori - Rich & Sweet", "Vegan Dining Month", "Golden Fire - Herbal Tea", "Peru Monteverde"
    ]

    # Modification patterns
    modification_patterns = {
        "MODS_VEGAN_MEAT": "Vegan Bacon|Thrilling Foods|No Bacon|Vegan Sausage|Veggie Sausage|No Sausage|Field Roast|No Meat",
        "MODS_MEAT": "Bacon|Sausage|Turkey|Meat",
        "MODS_VEGAN_DAIRY_EGG": "Good Planet|Just Egg|Vegan Cream|Vegan Egg",
        "MODS_DAIRY_EGG": "Cheddar|Cheese|Egg|Havarti",
        "MODS_EXPLICIT_VEGAN": "Vegan",
        "MODS_NONE": ""
    }

    # Drink categories to remove
    drink_categories = [
        "Coffee & Tea", "Dairy Drink", "Alcohol", "Soda", "Water", "Juice", "Sports & Health Drink"
    ]

    # Build the complete remapping structure (matching loc1/loc2 format)
    remapping = {
        "name_changes": name_changes,
        "modification_name_changes": [],  # This will be populated programmatically by the notebook
        "vegan_list": vegan_list,
        "vegetarian_list": vegetarian_list,
        "meat_list": meat_list,
        "alcoholic_drinks": alcoholic_drinks,
        "non_alcoholic_drinks": non_alcoholic_drinks,
        "rare_list": [],
        "unknown_list": [],
        "merch_list": merch_list,
        # Extra fields specific to loc5 automation
        "food_list": food_list,
        "dish_config": dish_config,
        "modification_patterns": modification_patterns,
        "drink_categories": drink_categories
    }

    return remapping

def export_yaml():
    """Export the remappings to YAML file"""
    
    # Generate the remappings
    remapping = generate_loc5_remappings()
    
    # Define output path
    output_path = Path('scripts/labeling/remapping/loc5_remappings.yaml')
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Write to YAML file
    with open(output_path, 'w', encoding='utf-8') as f:
        yaml.dump(remapping, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
    
    print(f"Successfully exported remappings to {output_path}")

if __name__ == "__main__":
    export_yaml()