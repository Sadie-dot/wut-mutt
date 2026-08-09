import Foundation

// Names Claude has actually produced, plus the shapes task #4 called out.
// Run with ./test_matcher.sh — the app has no test target, so this compiles
// BreedPhotos.swift on its own against a UIImage stub.
let cases: [(String, String?)] = [
    ("Golden Retriever",                "Golden Retriever"),
    ("Retriever (Golden)",              "Golden Retriever"),
    ("Labrador Retriever",              "Labrador Retriever"),
    ("Lab mix",                         "Labrador Retriever"),
    ("German Shepherd Dog",             "German Shepherd"),
    ("German Shepherd",                 "German Shepherd"),
    ("Chinese Crested (Powderpuff)",    "Chinese Crested"),
    ("Chinese Crested",                 "Chinese Crested"),
    ("Plott Hound",                     "Plott Hound"),
    ("Catahoula Leopard Dog",           "Catahoula Leopard Dog"),
    ("Louisiana Catahoula Leopard Dog", "Catahoula Leopard Dog"),
    // Mountain Cur has no bundled photo — Commons has nothing permissive for
    // it — so it must miss cleanly rather than land on a neighbouring cur.
    ("Mountain Cur",                    nil),
    ("Boxer",                           "Boxer"),
    ("American Pit Bull Terrier",       "Pit Bull"),
    ("Pit Bull",                        "Pit Bull"),
    ("Pit Bull mix",                    "Pit Bull"),
    ("Staffordshire Bull Terrier",      "Staffordshire Bull Terrier"),
    ("American Staffordshire Terrier",  "American Staffordshire Terrier"),
    ("Boston Terrier",                  "Boston Terrier"),
    ("Yorkshire Terrier",               "Yorkshire Terrier"),
    ("Jack Russell Terrier",            "Jack Russell Terrier"),
    ("Australian Shepherd",             "Australian Shepherd"),
    ("Australian Cattle Dog",           "Australian Cattle Dog"),
    ("Bernese Mountain Dog",            "Bernese Mountain Dog"),
    ("Great Pyrenees",                  "Great Pyrenees"),
    ("Great Dane",                      "Great Dane"),
    ("Pembroke Welsh Corgi",            "Pembroke Welsh Corgi"),
    ("Corgi",                           "Pembroke Welsh Corgi"),
    ("Standard Poodle",                 "Poodle"),
    ("Miniature Poodle",                "Poodle"),
    ("Poodle cross",                    "Poodle"),
    ("Goldendoodle",                    "Goldendoodle"),
    ("Labradoodle",                     "Labradoodle"),
    ("Bernedoodle",                     "Bernedoodle"),
    // One token, so it must not lean on the Bernese Mountain Dog's words
    // in either direction.
    ("Bernedoodle mix",                 "Bernedoodle"),
    ("Shih Tzu",                        "Shih Tzu"),
    ("Cavalier King Charles Spaniel",   "Cavalier King Charles Spaniel"),
    ("Cocker Spaniel",                  "Cocker Spaniel"),
    ("English Springer Spaniel",        "English Springer Spaniel"),
    ("Basset Hound",                    "Basset Hound"),
    ("Bloodhound",                      "Bloodhound"),
    ("Doberman Pinscher",               "Doberman Pinscher"),
    ("Dobermann",                       "Doberman Pinscher"),
    ("Saint Bernard",                   "Saint Bernard"),
    ("St. Bernard",                     "Saint Bernard"),
    ("Shiba Inu",                       "Shiba Inu"),
    ("Siberian Husky",                  "Siberian Husky"),
    // Nicknames and rival spellings:
    ("Frenchie",                        "French Bulldog"),
    ("Yorkie",                          "Yorkshire Terrier"),
    ("Sheltie",                         "Shetland Sheepdog"),
    ("Aussie",                          "Australian Shepherd"),
    ("Alsatian",                        "German Shepherd"),
    ("Blue Heeler",                     "Australian Cattle Dog"),
    ("Staffy",                          "Staffordshire Bull Terrier"),
    ("Wiener Dog",                      "Dachshund"),
    ("Berner",                          "Bernese Mountain Dog"),
    // Real breeds that once claimed the wrong dog's portrait through shared
    // stock words — the same bug Lemon Pig had when "mangosteen" opened
    // Mango. As of 2026-08-04 they carry their own photos, so each must match
    // itself and nothing else. Bull Terrier is the one still refused: Commons
    // has no permissive photo of an actual Bull Terrier, and the wrong answer
    // here is the Staffordshire's portrait.
    ("Bull Terrier",                    nil),   // took Staffordshire Bull Terrier
    ("Miniature Pinscher",              "Miniature Pinscher"),
    ("Tibetan Mastiff",                 "Tibetan Mastiff"),
    ("American Bulldog",                "American Bulldog"),
    ("Bearded Collie",                  "Bearded Collie"),
    ("Anatolian Shepherd",              "Anatolian Shepherd"),
    ("Anatolian Shepherd Dog",          "Anatolian Shepherd"),
    ("Entlebucher Mountain Dog",        "Entlebucher Mountain Dog"),
    ("Black Mouth Cur",                 "Black Mouth Cur"),
    ("Field Spaniel",                   "Field Spaniel"),
    ("Cairn Terrier",                   nil),

    // …while the same-breed variants must still land:
    ("English Bulldog",                 "Bulldog"),
    ("British Bulldog",                 "Bulldog"),
    ("English Mastiff",                 "Mastiff"),
    ("Rough Collie",                    "Collie"),
    ("Smooth Collie",                   "Collie"),
    ("Toy Poodle",                      "Poodle"),
    ("Border Collie",                   "Border Collie"),   // not plain Collie
    ("Bulldog",                         "Bulldog"),
    ("Collie",                          "Collie"),
    ("Mastiff",                         "Mastiff"),

    // The wildcard has its own cast photo as of 2026-08-08 (the Carcavelos
    // silhouette) — it self-matches like any billed name now.
    ("Guest Star",                      "Guest Star"),

    // Must NOT match anything:
    ("Mixed Breed",                     nil),
    ("Xoloitzcuintli",                  nil),
    ("Norwegian Lundehund",             nil),
    ("Dog",                             nil),
]

var pass = 0, fail = 0
for (query, expected) in cases {
    let got = BreedPhotos.credit(for: query)?.breed
    if got == expected { pass += 1 }
    else {
        fail += 1
        let padded = query.padding(toLength: 34, withPad: " ", startingAt: 0)
        print("  FAIL  \(padded) expected \(expected ?? "nil") — got \(got ?? "nil")")
    }
}
print("\n\(pass) passed, \(fail) failed, of \(cases.count)")
if fail > 0 { exit(1) }
