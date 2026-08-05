# Which candidate won, per breed, chosen by looking at the contact sheets.
#
# The criteria, in order:
#   1. No people. Not a hand steadying a chin, not a handler's legs at the
#      edge, not walkers in the far background. The dog is the character; a
#      stranger's arm in the polaroid makes it someone's snapshot instead.
#      Leads and collars are fine — they're the dog's.
#   2. Is it head-forward? The polaroid is ~218x200pt and the photo is anchored
#      top, so a dog facing the camera survives the crop and a dog facing away
#      becomes a shoulder.
#   3. Is it recognisably the breed to someone who owns one?
#   4. Is the frame clean? Ring numbers, sponsor boards and watermarks all
#      read as clutter at this size.
#   5. Is the short side at least ~620px, the crop's width at 3x?
#
# Judge these on the square crop, not the whole photograph — several picks
# that looked fine as candidates lost the dog's head once cropped.
#
# Index into the candidates list in candidates/index.json.
PICKS = {
    "French Bulldog": 0,                # [3] crops the ears off the top
    "Labrador Retriever": 2,
    "Golden Retriever": 0,
    "German Shepherd": 0,
    "Poodle": (0, 1.0),                 # head at the right of the frame
    "Dachshund": (1, 1.0),              # long dog, head at the right end
    "Bulldog": 1,
    "Beagle": 2,
    "Rottweiler": 2,
    "German Shorthaired Pointer": 7,        # the CC0 set all carry a burnt-in date stamp
    "Yorkshire Terrier": 2,
    "Boxer": 1,
    "Cavalier King Charles Spaniel": 0,
    "Doberman Pinscher": 0,
    "Australian Shepherd": 3,
    "Great Dane": 4,                    # [1] crops the ears off the top
    "Miniature Schnauzer": 2,
    "Siberian Husky": 2,
    "Bernese Mountain Dog": 1,
    "Cane Corso": 0,
    "Shih Tzu": 2,
    "Boston Terrier": 1,
    "Pomeranian": 0,
    "Havanese": 4,                      # [5] puts the dog in the bottom corner
    "English Springer Spaniel": 0,      # [5] is too tight — loses the crown of the head
    "Shetland Sheepdog": (2, 1.0),      # head at the right of the frame
    "Cocker Spaniel": 2,
    "Border Collie": 2,
    "Chihuahua": 3,                     # [1] has a sunbather on the beach behind
    "Basset Hound": 4,
    "Pembroke Welsh Corgi": 0,              # [1] and [3] are a dog in a wheelchair cart
    "Vizsla": 5,
    "Pug": 1,
    "Australian Cattle Dog": 4,
    "Maltese": 5,                           # [2] and [3] are sculptures, not dogs
    "Weimaraner": 1,
    "Collie": 4,
    "Newfoundland": 1,
    "Rhodesian Ridgeback": 2,
    "Great Pyrenees": 6,
    "Mastiff": 1,
    "Akita": 2,
    "Saint Bernard": 3,                     # [4] and [5] are Victorian rescue illustrations
    "Bloodhound": 3,
    "Jack Russell Terrier": 4,
    "Shiba Inu": 3,                         # the breed category is one photographer's dog-park series
    "Pit Bull": 2,
    "American Staffordshire Terrier": 0,
    "Staffordshire Bull Terrier": 1,
    "Goldendoodle": 2,                      # [0] is an annotated breed diagram with text labels
    "Labradoodle": 5,
    "Plott Hound": (0, 1.0),            # sitting at the right edge; centred, it loses its nose
    "Catahoula Leopard Dog": 0,         # [1] shows none of the leopard coat
    "Chinese Crested": 5,
    # Commons holds exactly two permissive Bernedoodles. [1] has a person's
    # leg and hand in the frame and is 640px wide — under the crop, so it
    # would upscale. [0] is head-forward at 3024x4032, native 3:4.
    "Bernedoodle": 0,

    # The 2026-08-04 batch: the false-match breeds, given their own photos.
    "Miniature Pinscher": 2,            # [0] is a tight face crop; [4] a painting
    "Tibetan Mastiff": 0,               # the only candidate without a handler in frame
    "American Bulldog": 4,              # walking at the camera; [1] is sepia, [2] eyes only
    "Bearded Collie": 0,                # [1] and [4] are the same painting twice
    "Anatolian Shepherd": 4,            # head-forward; [0] is bigger but side-on
    "Entlebucher Mountain Dog": 2,      # head-forward; studio-green backdrop, judged acceptable
    "Black Mouth Cur": 0,               # the cousin Mountain Cur never got: CC BY, sitting portrait
    "Field Spaniel": 1,                 # fills the frame; [3] and [4] carry people

    # Bull Terrier is deliberately absent: its permissive candidates are three
    # pit-bull-types that are not Bull Terriers, two paintings, and one
    # antique photograph. It keeps the trait grid and its refusal tests.

    # Mountain Cur is deliberately absent. Commons holds exactly two photos of
    # the breed and both are CC BY-SA; Openverse's only permissive hit is a
    # branded infographic, not a photograph. It falls through to the trait grid.
}
