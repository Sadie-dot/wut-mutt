# The bundled photo set. Ordered by how likely a scan is to name them.
#
# Sources, in priority order:
#   1. AKC registration popularity — the best available proxy for what people
#      own and therefore point a camera at.
#   2. Types Claude actually returns that AKC does not recognise. It is given a
#      free-text field, not a list, so doodles and the pit-bull cluster show up
#      regardless of what any kennel club says.
#   3. Breeds already observed in this app's own logs / test reveals.
#
# `search` is what goes to Commons when the display name is ambiguous there
# ("Bulldog" alone pulls up mascots and pub signs).
BREEDS = [
    # --- AKC popularity ---
    ("French Bulldog",            None),
    ("Labrador Retriever",        None),
    ("Golden Retriever",          None),
    ("German Shepherd",           "German Shepherd Dog"),
    ("Poodle",                    "Standard Poodle"),
    ("Dachshund",                 None),
    ("Bulldog",                   "English Bulldog dog breed"),
    # Bare "Beagle" resolves to Category:Beagle conflict — the 1982 Argentina
    # –Chile territorial dispute — and returns armoured vehicles.
    ("Beagle",                    "Beagle dog"),
    ("Rottweiler",                None),
    ("German Shorthaired Pointer", None),
    ("Yorkshire Terrier",         None),
    ("Boxer",                     "Boxer dog"),
    ("Cavalier King Charles Spaniel", None),
    ("Doberman Pinscher",         "Dobermann"),
    ("Australian Shepherd",       None),
    ("Great Dane",                None),
    ("Miniature Schnauzer",       None),
    ("Siberian Husky",            None),
    ("Bernese Mountain Dog",      None),
    ("Cane Corso",                None),
    ("Shih Tzu",                  None),
    ("Boston Terrier",            None),
    ("Pomeranian",                "Pomeranian dog"),
    ("Havanese",                  None),
    ("English Springer Spaniel",  None),
    ("Shetland Sheepdog",         None),
    ("Cocker Spaniel",            None),
    ("Border Collie",             None),
    ("Chihuahua",                 "Chihuahua dog"),
    ("Basset Hound",              None),
    ("Pembroke Welsh Corgi",      None),
    ("Vizsla",                    None),
    ("Pug",                       "Pug dog"),
    ("Australian Cattle Dog",     None),
    ("Maltese",                   "Maltese dog"),
    ("Weimaraner",                None),
    ("Collie",                    "Rough Collie"),
    ("Newfoundland",              "Newfoundland dog"),
    ("Rhodesian Ridgeback",       None),
    ("Great Pyrenees",            "Pyrenean Mountain Dog"),
    ("Mastiff",                   "English Mastiff"),
    ("Akita",                     "Akita dog"),
    # Bare "Saint Bernard" returns the town in Ain, France — a mairie, a
    # church and a gilded statue, no dogs at all.
    ("Saint Bernard",             "Saint Bernard dog breed"),
    ("Bloodhound",                None),
    ("Jack Russell Terrier",      None),
    ("Shiba Inu",                 None),

    # --- Not AKC-recognised, but Claude says them anyway ---
    ("Pit Bull",                  "American Pit Bull Terrier"),
    ("American Staffordshire Terrier", None),
    ("Staffordshire Bull Terrier", None),
    ("Goldendoodle",              None),
    ("Labradoodle",               None),
    # Billed on a real user's dog 2026-08-04, so it has appeared in the wild.
    ("Bernedoodle",               "Bernedoodle dog"),

    # --- Seen in this app's own reveals ---
    ("Plott Hound",               "Plott Hound dog"),
    ("Catahoula Leopard Dog",     "Louisiana Catahoula Leopard Dog"),
    # Bare "Mountain Cur" returns Madeira's mountains — Curral das Freiras.
    # Qualified, Commons has exactly two Mountain Curs and both are CC BY-SA,
    # so this breed cannot be served under the permissive-only rule and falls
    # through to the trait grid. Left here to document that it was looked for.
    ("Mountain Cur",              "Mountain Cur dog breed"),
    ("Chinese Crested",           "Chinese Crested Dog"),
]
