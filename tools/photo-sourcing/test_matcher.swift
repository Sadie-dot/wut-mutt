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
    ("Mountain Cur",                    "Mountain Cur"),
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
    ("Rough Collie",                    "Collie"),
    ("Border Collie",                   "Border Collie"),
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
    // Must NOT match anything:
    ("A Special Guest",                 nil),
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
