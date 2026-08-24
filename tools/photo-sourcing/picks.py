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
    "Poodle": 3,                        # [0]'s show portrait has ring-side
                                        # people blurred in the background —
                                        # a user caught them on the dossier.
                                        # [3] is the black standard in grass,
                                        # camera-forward, nobody in frame.
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
    "Pembroke Welsh Corgi": (0, 1.0),       # [1] and [3] are a dog in a wheelchair cart.
                                            # Right-facing profile with the face at the
                                            # right edge — centred, the crop cut the head
                                            # off (caught on a live dossier 2026-08-27).
    "Vizsla": 5,
    "Pug": 1,
    "Australian Cattle Dog": 4,
    "Maltese": 5,                           # [2] and [3] are sculptures, not dogs
    "Weimaraner": 1,
    "Collie": 4,
    "Newfoundland": 1,
    "Rhodesian Ridgeback": (2, 0.0),    # left-facing profile, nose tip touching
                                        # the left edge when centred (2026-08-28
                                        # edge audit)
    "Great Pyrenees": 6,
    "Mastiff": 1,
    "Akita": 2,
    "Saint Bernard": 3,                     # [4] and [5] are Victorian rescue illustrations
    "Bloodhound": 3,
    "Jack Russell Terrier": 4,
    "Shiba Inu": 3,                         # the breed category is one photographer's dog-park series
    "Pit Bull": 2,
    "American Staffordshire Terrier": 0,
    "Staffordshire Bull Terrier": 6,    # recast 2026-08-28, the user's pick
                                        # after a live dossier: [1]'s red dog
                                        # clipped its nose (fifth profile-crop
                                        # catch) and reads leggier than the
                                        # breed; [6] is the PD show-stance
                                        # classic, hand-appended from a
                                        # re-worded search.
    "Goldendoodle": 2,                      # [0] is an annotated breed diagram with text labels
    "Labradoodle": 5,
    "Plott Hound": (0, 1.0),            # sitting at the right edge; centred, it loses its nose
    "Catahoula Leopard Dog": (0, 0.2),  # [1] shows none of the leopard coat.
                                        # 0.2: centred, the muzzle exits the
                                        # left edge; hard left promotes the
                                        # ringside person from speck to blur.
                                        # This keeps the nose and demotes the
                                        # person (2026-08-28 audit).
                                        # Kept through the 2026-08-15 humans
                                        # audit, the user's call: the far
                                        # tent-line specks are illegible at
                                        # dossier size (the Guest Star
                                        # precedent), and every alternative
                                        # trades worse — [2][3][5] have real
                                        # people in frame, [4] is people-free
                                        # but lacks the merle that makes the
                                        # breed recognisable.
    "Chinese Crested": 5,
    "Lhasa Apso": 1,                    # full parted coat, face-on; [4] is the
                                        # show topknot but [1] reads more like
                                        # the dogs that get billed; user's pick

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

    # Refused from 2026-08-04 to 2026-08-20 — the first search found nothing
    # that was actually a Bull Terrier. [6] arrived from a re-worded search
    # after Bull-and-Terrier joined the catalog: a modern public-domain
    # portrait, unmistakably the egg-headed breed. The full frame can't work
    # in the polaroid (ears at 35%, toes at 94% — the display's top-88% window
    # cannot hold both), so the band zooms to a head-and-chest portrait that
    # ends on clean body rather than half a paw.
    "Bull Terrier": (6, 0.55, 0.31, 0.88),

    # Mountain Cur is deliberately absent. Commons holds exactly two photos of
    # the breed and both are CC BY-SA; Openverse's only permissive hit is a
    # branded infographic, not a photograph. It falls through to the trait grid.

    # The wildcard, user-cast 2026-08-08. Deliberately breaks criteria 2 and 3:
    # the dog faces away in full silhouette and no breed is readable — that is
    # the role. A Guest Star with a recognisable face would contradict every
    # dossier line it appears beside ("Refuses to be categorized"). Tiny
    # walkers on the far shoreline pass criterion 1 at polaroid size.
    "Guest Star": 0,

    # The ancestor, user-cast 2026-08-16. An 1863 albumen print breaks the
    # criteria knowingly: the grain and sepia ARE the point — the billing is
    # an extinct type, and the photograph says so at a glance. The chain and
    # studded collar are the dog's own gear. Landscape plate with the head at
    # the left edge — centred, the muzzle is cut off (the Plott Hound's
    # problem, mirrored).
    "Bull-and-Terrier": (0, 0.15),
}
