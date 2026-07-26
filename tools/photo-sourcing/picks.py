# Which candidate won, per breed, chosen by looking at the contact sheets.
#
# The criteria, in order:
#   1. Is it head-forward? The polaroid is ~218x200pt and the photo is anchored
#      top, so a dog facing the camera survives the crop and a dog facing away
#      becomes a shoulder.
#   2. Is it recognisably the breed to someone who owns one?
#   3. Is the frame clean? Handlers' legs, ring numbers, sponsor boards and
#      watermarks all read as clutter at this size.
#   4. Is the short side at least ~620px, the crop's width at 3x?
#
# Index into the candidates list in candidates/index.json.
PICKS = {
    "French Bulldog": 3,
    "Labrador Retriever": 3,
    "Golden Retriever": 1,
    "German Shepherd": 2,
    "Poodle": 3,
    "Dachshund": 3,
    "Bulldog": 2,
    "Beagle": 1,
    "Rottweiler": 3,                    # [1] has a person behind the dog
    "German Shorthaired Pointer": 2,   # [3] is watermarked equishot.be
    "Yorkshire Terrier": 3,
    "Boxer": 2,                         # [1] clips the head at the frame edge
    "Cavalier King Charles Spaniel": 3,
    "Doberman Pinscher": 0,
    "Australian Shepherd": 1,
    "Great Dane": 3,                    # [0] is mostly brick wall at this crop
    "Miniature Schnauzer": 0,
    "Siberian Husky": 2,               # [1] is an eye close-up, not a breed shot
    "Bernese Mountain Dog": 1,
    "Cane Corso": 0,
    "Shih Tzu": 2,
    "Boston Terrier": 0,
    "Pomeranian": 1,
    "Havanese": 3,
    "English Springer Spaniel": 3,      # [1] has a handler standing behind the dog
    "Shetland Sheepdog": 1,
    "Cocker Spaniel": 0,
    "Border Collie": 1,
    "Chihuahua": 1,
    "Basset Hound": 1,                  # no people in frame; [0] has walkers in the field
    "Pembroke Welsh Corgi": 2,
    "Vizsla": 2,
    "Pug": 0,                           # [1] is cradled in someone's hand
    "Australian Cattle Dog": 2,
    "Maltese": 1,
    "Weimaraner": 2,
    "Collie": 0,
    "Newfoundland": 1,
    "Rhodesian Ridgeback": 1,
    "Great Pyrenees": 2,
    "Mastiff": 1,
    "Akita": 2,
    "Saint Bernard": 1,                 # [0] has a handler's legs at the edge
    "Bloodhound": 0,                   # [3] is a surface-to-air missile
    "Jack Russell Terrier": 2,
    "Shiba Inu": 1,
    "Pit Bull": 0,
    "American Staffordshire Terrier": 1,  # [3] has sponsor boards behind it
    "Staffordshire Bull Terrier": 1,
    "Goldendoodle": 1,                  # [0] puts the dog too far off to read
    "Labradoodle": 1,
    "Plott Hound": 3,                   # [1] has a handler's arm across the corner
    "Catahoula Leopard Dog": 2,
    "Mountain Cur": 0,                 # only Commons image actually named as one
    "Chinese Crested": 2,
}
